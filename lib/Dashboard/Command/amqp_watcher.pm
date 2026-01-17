# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Command::amqp_watcher;
use Mojo::Base 'Mojolicious::Command', -signatures;

use Cpanel::JSON::XS 'decode_json';
use Mojo::IOLoop;
use Mojo::Promise;
use Mojo::RabbitMQ::Client;

has description => 'Watch message bus for job results';
has usage       => sub { shift->extract_usage };

sub run ($self, @args) {    # uncoverable statement
  Mojo::IOLoop->singleton->reactor->unsubscribe('error');
  $self->_connect(0);
  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub _connect ($self, $backoff) {
  my $amqp = $self->app->amqp;
  my $log  = $self->app->log;

  my $client = Mojo::RabbitMQ::Client->new(url => $self->app->config->{rabbitmq});
  my $queue_name;

  $client->on(
    close => sub {
      my $next_backoff = $backoff ? $backoff * 2 : 1;
      $next_backoff = 60 if $next_backoff > 60;
      $log->info(
        Mojo::JSON::encode_json(
          {type => 'amqp_reconnect', delay => $next_backoff, message => 'AMQP connection closed'}
        )
      );
      Mojo::IOLoop->timer($next_backoff => sub { $self->_connect($next_backoff) });
    }
  );

  $client->connect_p->then(
    sub ($client) {
      $log->info(Mojo::JSON::encode_json({type => 'amqp_connected', message => 'RabbitMQ watcher connected'}));
      return $client->acquire_channel_p;
    }
  )->then(
    sub ($channel) {
      return $channel->declare_exchange_p(exchange => 'pubsub', type => 'topic', passive => 1, durable => 1);
    }
  )->then(
    sub ($channel, @args) {
      return $channel->declare_queue_p(exclusive => 1);
    }
  )->then(
    sub ($channel, $result) {
      $queue_name = $result->method_frame->{queue};
      return $channel->bind_queue_p(exchange => 'pubsub', queue => $queue_name, routing_key => 'suse.openqa.job.#');
    }
  )->then(
    sub ($channel, @) {
      my $consumer = $channel->consume(queue => $queue_name, no_ack => 1);
      $consumer->on(
        message => sub ($consumer, $frame) {
          my $message = $frame->{body}->to_raw_payload;
          my $key     = $frame->{deliver}{method_frame}{routing_key};
          my $data    = eval { decode_json $message };
          if ($@) {
            $log->error(
              Mojo::JSON::encode_json({type => 'amqp_error', error => $@, message => 'Failed to decode AMQP message'}));
            return;
          }
          $amqp->handle($key, $data);
        }
      );
      $consumer->deliver;
    }
  )->catch(
    sub {
      my $err = shift;
      $log->error(Mojo::JSON::encode_json({type => 'amqp_error', error => "$err", message => 'AMQP connection error'}));
      $client->emit('close');
    }
  );

  # Heartbeats are sent every 60 seconds (this is a fallback in case the disconnect has not been detected)
  $client->on(
    connect => sub ($client, $stream) {
      Mojo::IOLoop->timer(0 => sub { $stream->timeout(120) });
    }
  );
}

1;

=encoding utf8

=head1 NAME

Dashboard::Command::amqp_watcher - command to watch message bus for job results

=head1 SYNOPSIS

  Usage: APPLICATION amqp-watcher

    script/dashboard amqp-watcher

  Options:
    -h, --help   Show this summary of available options

=cut

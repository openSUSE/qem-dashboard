# Copyright SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package Dashboard::Command::amqp_watcher;
use Mojo::Base 'Mojolicious::Command', -signatures;

use Cpanel::JSON::XS 'decode_json';
use Mojo::IOLoop;
use Mojo::Promise;
use Mojo::RabbitMQ::Client;

has description => 'Watch message bus for job results';
has usage       => sub { shift->extract_usage };

sub run ($self, @args) {
  my $amqp = $self->app->amqp;
  Mojo::IOLoop->singleton->reactor->unsubscribe('error');

  my $client = Mojo::RabbitMQ::Client->new(url => $self->app->config->{rabbitmq});
  my $queue_name;
  my $promise = $client->connect_p->then(sub ($client) { $client->acquire_channel_p })->then(
    sub ($channel) {
      $channel->declare_exchange_p(exchange => 'pubsub', type => 'topic', passive => 1, durable => 1);
    }
  )->then(
    sub ($channel, @args) {
      $channel->declare_queue_p(exclusive => 1);
    }
  )->then(
    sub ($channel, $result) {
      $queue_name = $result->method_frame->{queue};
      return $channel->bind_queue_p(exchange => 'pubsub', queue => $queue_name, routing_key => 'suse.openqa.job.#');
    }
  )->then(
    sub ($channel, @) {
      my $promise  = Mojo::Promise->new;
      my $consumer = $channel->consume(queue => $queue_name, no_ack => 1);
      $consumer->on(error => sub { $promise->reject('Consumer error') });
      $consumer->on(
        message => sub ($consumer, $frame) {
          my $message = $frame->{body}->to_raw_payload;
          my $key     = $frame->{deliver}{method_frame}{routing_key};
          my $data    = decode_json $message;
          $amqp->handle($key, $data);
        }
      );
      $consumer->deliver;

      return $promise;
    }
  );

  # Heartbeats are sent every 60 seconds (this is a fallback in case the disconnect has not been detected)
  $client->on(
    connect => sub ($client, $stream) {
      Mojo::IOLoop->timer(0 => sub { $stream->timeout(120) });
    }
  );

  my $log = $self->app->log;
  $log->info('RabbitMQ watcher started');
  $promise->catch(sub { $log->error(@_) })->wait;

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

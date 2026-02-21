# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Test::Stub::RabbitMQ;
use Mojo::Base -strict, -signatures;

use Mojo::Promise;
use Test::Stub::IOLoop;
use Test::MockModule;

sub _stub_common_client_methods ($cls) {
  my $rabbit = Test::MockModule->new('Mojo::RabbitMQ::Client');
  my %event_handlers;

  $rabbit->redefine(new => sub ($cls, %args) { return bless {%args}, $cls });

  $rabbit->redefine(
    on => sub ($self, $event, $cb) {
      $event_handlers{$event} = $cb;
      return $self;
    }
  );

  $rabbit->redefine(
    emit => sub ($self, $event) {
      $event_handlers{$event}->($self) if exists $event_handlers{$event};
    }
  );

  return $rabbit;
}

sub setup_failing_connection ($cls) {
  my $rabbit = $cls->_stub_common_client_methods();

  $rabbit->redefine(
    connect_p => sub ($self) {
      return Mojo::Promise->reject('Connection failed');
    }
  );

  return $rabbit;
}

sub setup_successful_connection ($cls) {
  my $rabbit = $cls->_stub_common_client_methods();

  $rabbit->redefine(connect_p => sub ($self) { return Mojo::Promise->resolve($self) });

  $rabbit->redefine(
    acquire_channel_p => sub ($self) {
      my $mock_channel = bless {}, 'Mojo::RabbitMQ::Client::Channel';
      return Mojo::Promise->resolve($mock_channel);
    }
  );

  my $rabbit_channel = Test::MockModule->new('Mojo::RabbitMQ::Client::Channel');
  $rabbit_channel->redefine(declare_exchange_p => sub ($self, @) { Mojo::Promise->resolve($self) });

  $rabbit_channel->redefine(
    declare_queue_p => sub ($self, @) {
      my $result = bless {_method_frame => {queue => 'test_queue'}}, 'QueueResults';
      return Mojo::Promise->resolve($self, $result);
    }
  );

  $rabbit_channel->redefine(bind_queue_p => sub ($self, @) { Mojo::Promise->resolve($self) });
  $rabbit_channel->redefine(consume      => sub ($self, @) { bless {}, 'Mojo::RabbitMQ::Client::Consumer' });
  my $rabbit_queue_result = Test::MockModule->new('QueueResult', no_auto => 1);
  $rabbit_queue_result->mock(method_frame => sub ($self) { return $self->{_method_frame} });

  my $rabbit_consumer = Test::MockModule->new('Mojo::RabbitMQ::Client::Consumer', no_auto => 1);
  $rabbit_consumer->mock(on      => sub ($self, @) {$self});
  $rabbit_consumer->mock(deliver => sub ($self, @) { });
  return ($rabbit, $rabbit_channel, $rabbit_queue_result, $rabbit_consumer);
}

1;

=encoding utf8

=head1 NAME

Test::Stub::RabbitMQ - stub C<Mojo::RabbitMQ::Client> for testing

=head1 SYNOPSIS

  use Test::Stub::RabbitMQ;

  my $rabbit = Test::Stub::RabbitMQ->setup_failing_connection();
  my ($rabbit, $rabbit_channel, $rabbit_queue_result, $rabbit_consumer) = Test::Stub::RabbitMQ->setup_successful_connection();

=head1 DESCRIPTION

Replaces C<Mojo::RabbitMQ::Client> methods with stubs to allow unit
testing of AMQP independently. Use
C<setup_failing_connection> to simulate a rejected connection and
C<setup_successful_connection> to simulate a fully established channel with
exchange, queue, and consumer ready.

=cut

# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Test::Stub::RabbitMQ;
use Mojo::Base -strict, -signatures;

use Mojo::Promise;
use Test::Stub::IOLoop;

sub _stub_common_client_methods ($cls, $backoff_counter) {
  my $client;
  my %event_handlers;

  no warnings 'redefine', 'once';
  Test::Stub::IOLoop->stub_timer($backoff_counter);

  *Mojo::RabbitMQ::Client::new = sub ($cls, %args) {
    return bless {%args}, $cls;
  };

  *Mojo::RabbitMQ::Client::on = sub ($self, $event, $cb) {
    $event_handlers{$event} = $cb;
    return $self;
  };

  *Mojo::RabbitMQ::Client::emit = sub ($self, $event) {
    $event_handlers{$event}->($self) if exists $event_handlers{$event};
  };

  return ($client, \%event_handlers);
}

sub setup_failing_connection ($cls, $backoff_counter) {
  my ($mock_client, $event_handlers) = $cls->_stub_common_client_methods($backoff_counter);
  no warnings 'redefine', 'once';

  *Mojo::RabbitMQ::Client::connect_p = sub ($self) {
    return Mojo::Promise->reject('Connection failed');
  };

  return $mock_client;
}

sub setup_successful_connection ($cls, $backoff_counter) {
  my ($conn, $success_handlers) = $cls->_stub_common_client_methods($backoff_counter);

  no warnings 'redefine', 'once';
  *Mojo::RabbitMQ::Client::connect_p = sub ($self) {
    return Mojo::Promise->resolve($self);
  };

  *Mojo::RabbitMQ::Client::acquire_channel_p = sub ($self) {
    my $mock_channel = bless {}, 'Mojo::RabbitMQ::Client::Channel';
    return Mojo::Promise->resolve($mock_channel);
  };

  *Mojo::RabbitMQ::Client::Channel::declare_exchange_p = sub ($self) {
    return Mojo::Promise->resolve($self);
  };

  *Mojo::RabbitMQ::Client::Channel::declare_queue_p = sub ($self) {
    my $result = bless {_method_frame => {queue => 'test_queue'}}, 'Mojo::RabbitMQ::Client::QueueResult';
    return Mojo::Promise->resolve($self, $result);
  };

  *Mojo::RabbitMQ::Client::QueueResult::method_frame = sub ($self) {
    return $self->{_method_frame};
  };

  *Mojo::RabbitMQ::Client::Channel::bind_queue_p = sub ($self) {
    return Mojo::Promise->resolve($self);
  };

  *Mojo::RabbitMQ::Client::Channel::consume = sub ($self) {
    return bless {}, 'Mojo::RabbitMQ::Client::Consumer';
  };

  *Mojo::RabbitMQ::Client::Consumer::on      = sub { $_[0] };
  *Mojo::RabbitMQ::Client::Consumer::deliver = sub { };

  return $conn;
}

1;

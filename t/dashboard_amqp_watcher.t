# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Mojo::Base -strict, -signatures;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Test::Mojo;
use Test::Output qw(stderr_like);
use Test::Warnings ':report_warnings';
use Dashboard::Command::amqp_watcher;
use Dashboard::Test;
use Test::Stub::IOLoop;
use Test::Stub::RabbitMQ;

plan skip_all => 'set TEST_ONLINE to enable this test' unless $ENV{TEST_ONLINE};
local $ENV{MOJO_MODE} = 'production';

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'dashboard_test');
my $config         = $dashboard_test->default_config;

subtest 'amqp_watcher command' => sub {
  my $t            = Test::Mojo->new(Dashboard => $config);
  my $amqp_watcher = Dashboard::Command::amqp_watcher->new(app => $t->app);

  subtest 'command smoke test' => sub {
    is $amqp_watcher->description, 'Watch message bus for job results', 'correct description';
    like $amqp_watcher->usage, qr/Usage: APPLICATION amqp-watcher/, 'correct usage';
  };

  subtest 'reconnection backoff logic' => sub {
    my @backoff_counter;
    subtest 'initial connection failure (backoff = 0)' => sub {
      @backoff_counter = ();
      my $rabbit = Test::Stub::RabbitMQ->setup_failing_connection();
      my $ioloop = Test::Stub::IOLoop->stub_timer(\@backoff_counter);

      stderr_like {
        $amqp_watcher->_connect(0);
        Mojo::IOLoop->one_tick;
      }
      qr/amqp_error/, 'logs connection error';
      is scalar(@backoff_counter), 1, 'scheduled one reconnection';
      is $backoff_counter[0],      1, 'initial backoff is 1 second';
    };

    subtest 'connection failure' => sub {
      my %data = (
        1   => [2,  'backoff is 2 seconds on second connection failure'],
        2   => [4,  'backoff is 4 seconds on third connection failure'],
        30  => [60, 'backoff is 60 seconds on forth connectionfailure'],
        60  => [60, 'backoff stays at 60 seconds due to the fallback'],
        100 => [60, 'backoff still at 60 seconds due to the fallback'],
      );
      for my $backoff (keys %data) {
        my ($expected, $comment) = @{$data{$backoff}};
        @backoff_counter = ();
        my $rabbit = Test::Stub::RabbitMQ->setup_failing_connection();
        my $ioloop = Test::Stub::IOLoop->stub_timer(\@backoff_counter);
        $amqp_watcher->_connect($backoff);
        stderr_like { Mojo::IOLoop->one_tick }
        qr/amqp_error/, 'amqp log message';
        is $backoff_counter[0], $expected, $comment;
      }
    };

    subtest 'backoff resets to 0 after successful connection' => sub {
      @backoff_counter = ();
      my ($rabbit, $rabbit_channel, $rabbit_queue_result, $rabbit_consumer)
        = Test::Stub::RabbitMQ->setup_successful_connection();
      my $ioloop = Test::Stub::IOLoop->stub_timer(\@backoff_counter);
      my $new_rabbitmq_client;
      $rabbit->redefine(
        new => sub {
          $new_rabbitmq_client = $rabbit->original('new')->(@_);
          return $new_rabbitmq_client;
        }
      );
      $amqp_watcher->_connect(30);
      stderr_like { Mojo::IOLoop->one_tick }
      qr/amqp_connected/, 'logs successful connection';
      stderr_like { $new_rabbitmq_client->emit('close') }
      qr/amqp_reconnect/, 'logs reconnect on close';
      is $backoff_counter[-1], 1, 'backoff resets to 1 second after successful connection';
    };
  };
};

done_testing();

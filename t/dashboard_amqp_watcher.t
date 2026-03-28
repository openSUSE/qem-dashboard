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

if (!$ENV{TEST_ONLINE}) {    # uncoverable branch true
  plan skip_all => 'set TEST_ONLINE to enable this test';    # uncoverable statement
}
local $ENV{MOJO_MODE} = 'production';

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'dashboard_test');
my $config         = $dashboard_test->default_config;

subtest 'amqp_watcher command' => sub {
  my $t            = Test::Mojo->new(Dashboard => $config);
  my $amqp_watcher = Dashboard::Command::amqp_watcher->new(app => $t->app);
  my $amqp_log     = sub ($regex, $level = 'info') {
    return $regex if $t->app->log->is_level($level);
    return qr/^$/;
  };

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
      $amqp_log->(qr/amqp_error/, 'error'), 'logs connection error';
      isa_ok $amqp_watcher->client, 'Mojo::RabbitMQ::Client', 'new client on connection';
      my $initial_client = $amqp_watcher->client;
      is scalar(@backoff_counter), 1, 'scheduled one reconnection';
      is $backoff_counter[0],      1, 'initial backoff is 1 second';
      stderr_like {
        $amqp_watcher->_connect(0);
        Mojo::IOLoop->one_tick;
      }
      $amqp_log->(qr/amqp_error/, 'error'), 'close is reached once again';
      my $new_client = $amqp_watcher->client;
      isnt $new_client, undef,           'old client is replaced on recconect';
      isnt $new_client, $initial_client, 'client is still alive';
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
        $amqp_log->(qr/amqp_error/, 'error'), 'amqp log message';
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
      $amqp_log->(qr/amqp_connected/, 'info'), 'logs successful connection';

      # Branch coverage: connect event
      my $mock_stream = bless {}, 'MockStream';
      my $timeout_val;
      {
        no strict 'refs';
        *{"MockStream::timeout"} = sub { (my $self, $timeout_val) = @_; };
      }

      # Redefine timer to execute callback immediately for this test
      my $ioloop_mock = Test::MockModule->new('Mojo::IOLoop');
      $ioloop_mock->redefine(
        timer => sub {
          (my $loop, my $delay, my $cb) = @_;
          push @backoff_counter, $delay if defined $delay;    # uncoverable branch false
          $cb->();
        }
      );

      $new_rabbitmq_client->emit('connect', $mock_stream);
      is $timeout_val, 120, 'stream timeout set to 120 on connect';

      $ioloop_mock->unmock('timer');

      # Re-stub timer for the rest of the test
      Test::Stub::IOLoop->stub_timer(\@backoff_counter);

      Mojo::IOLoop->one_tick;

      stderr_like { $new_rabbitmq_client->emit('close') }
      $amqp_log->(qr/amqp_reconnect/, 'info'), 'logs reconnect on close';
      is $backoff_counter[-1], 1, 'backoff resets to 1 second after successful connection';
    };

    subtest 'message handling' => sub {
      my ($rabbit, $rabbit_channel, $rabbit_queue_result, $rabbit_consumer)
        = Test::Stub::RabbitMQ->setup_successful_connection();
      my $msg_cb;
      $rabbit_consumer->mock(on => sub { (my $self, my $event, $msg_cb) = @_; $self });

      $amqp_watcher->_connect(0);

      # The promise chain is asynchronous, ensure it finishes
      for (1 .. 5) { Mojo::IOLoop->one_tick }

      ok $msg_cb, 'consumer message callback registered';

      subtest 'valid message' => sub {
        my $mock_amqp = Test::MockModule->new('Dashboard::Model::AMQP');
        my ($handled_key, $handled_data);
        $mock_amqp->redefine(handle => sub { (my $self, $handled_key, $handled_data) = @_; });

        my $frame = {
          body    => bless({payload => '{"foo":"bar"}'}, 'MockBody'),
          deliver => {method_frame => {routing_key => 'test.key'}}
        };
        {
          no strict 'refs';
          *{"MockBody::to_raw_payload"} = sub { shift->{payload} };
        }
        $msg_cb->(undef, $frame);
        is $handled_key, 'test.key', 'correct routing key handled';
        is_deeply $handled_data, {foo => 'bar'}, 'correct data handled';
      };

      subtest 'invalid JSON' => sub {
        my $frame = {
          body    => bless({payload => 'invalid json'}, 'MockBody2'),
          deliver => {method_frame => {routing_key => 'test.key'}}
        };
        {
          no strict 'refs';
          *{"MockBody2::to_raw_payload"} = sub { shift->{payload} };
        }
        stderr_like { $msg_cb->(undef, $frame) } $amqp_log->(qr/amqp_error/, 'error'), 'logs error on invalid JSON';
      };
    };

    subtest 'connection error catch' => sub {
      my ($rabbit, $rabbit_channel, $rabbit_queue_result, $rabbit_consumer)
        = Test::Stub::RabbitMQ->setup_successful_connection();
      $rabbit_channel->redefine(declare_exchange_p => sub { Mojo::Promise->reject('Exchange error') });

      stderr_like {
        $amqp_watcher->_connect(0);

        # The promise chain is asynchronous, ensure it finishes
        for (1 .. 5) { Mojo::IOLoop->one_tick }
      }
      $amqp_log->(qr/amqp_error/, 'error'), 'catches and logs error in promise chain';
    };
  };

  subtest 'run method' => sub {
    my $mock_ioloop = Test::MockModule->new('Mojo::IOLoop');
    my $started     = 0;
    $mock_ioloop->redefine(start      => sub { $started++ });
    $mock_ioloop->redefine(is_running => sub {0});

    # Mock _connect to avoid actually trying to connect
    my $connected    = 0;
    my $mock_watcher = Test::MockModule->new('Dashboard::Command::amqp_watcher');
    $mock_watcher->redefine(_connect => sub { $connected++ });

    $amqp_watcher->run();
    is $connected, 1, '_connect called';
    is $started,   1, 'IOLoop started';

    # Branch coverage: IOLoop already running
    $connected = 0;
    $started   = 0;
    $mock_ioloop->redefine(is_running => sub {1});
    $amqp_watcher->run();
    is $connected, 1, '_connect called again';
    is $started,   0, 'IOLoop NOT started again';
  };
};

done_testing();

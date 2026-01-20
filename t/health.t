# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Mojo::Base -strict, -signatures;

use lib 't/lib';
use Test::More;
use Test::Mojo;
use Test::Output 'stderr_like';
use Dashboard::Test;
use Mojo::Util qw(monkey_patch);

my $env    = \%ENV;
my $tester = Dashboard::Test->new(online => $env->{TEST_ONLINE}, schema => 'health_test');
my $t      = Test::Mojo->new(Dashboard => $tester->default_config);

stderr_like {
  $t->get_ok('/health')->status_is(200)->json_is('/status' => 'ok');
  $t->get_ok('/ready')->status_is(200)->json_is('/status' => 'ok');

  {
    my $original = Mojo::Pg::Database->can('query');
    monkey_patch 'Mojo::Pg::Database', query => sub { die "DB connection failed" };
    $t->get_ok('/ready')->status_is(500)->json_is('/status' => 'fail')->json_like('/error' => qr/DB connection failed/);
    monkey_patch 'Mojo::Pg::Database', query => $original;
  }

  {
    my $original = Mojo::Message::Request->can('request_id');
    monkey_patch 'Mojo::Message::Request', request_id => sub {undef};
    $t->get_ok('/health');
    ok $t->tx->request_id, 'monkey patched request_id works';
    monkey_patch 'Mojo::Message::Request', request_id => $original;
  }
}
qr/access_log/, 'access log caught';

done_testing();

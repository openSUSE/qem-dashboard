# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Mojo::Base -strict, -signatures;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Test::Mojo;
use Test::Output 'stderr_like';
use Test::Warnings ':report_warnings';
use Dashboard::Test;

if (!$ENV{TEST_ONLINE}) {    # uncoverable branch true
  plan skip_all => 'set TEST_ONLINE to enable this test';    # uncoverable statement
}

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'ui_test');
my $config         = $dashboard_test->default_config;
my $t              = Test::Mojo->new(Dashboard => $config);
$dashboard_test->minimal_fixtures($t->app);
my $access_log = sub { $t->app->log->level eq 'info' ? qr/access_log/ : qr/^$/ };

subtest 'Log level coverage' => sub {
  my $old_level = $t->app->log->level;
  $t->app->log->level('info');
  like 'access_log', $access_log->(), 'access_log info branch';
  $t->app->log->level('warn');
  like '', $access_log->(), 'access_log warn branch';
  $t->app->log->level($old_level);
};

subtest 'Webpack provided under various URLs' => sub {
  stderr_like {
    $t->get_ok('/')
      ->status_is(200)
      ->text_like('#app' => qr/This application requires JavaScript!/, 'JS requirement check on /');
    $t->get_ok('/blocked')
      ->status_is(200)
      ->text_like('#app' => qr/This application requires JavaScript!/, 'JS requirement check on /blocked');
    $t->get_ok('/repos')
      ->status_is(200)
      ->text_like('#app' => qr/This application requires JavaScript!/, 'JS requirement check on /repos');
    $t->get_ok('/incident/16860')
      ->status_is(200)
      ->text_like('#app' => qr/This application requires JavaScript!/, 'JS requirement check on /incident/16860');
  }
  $access_log->(), 'access log caught';
};


done_testing();

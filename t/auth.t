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

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'auth_test');
my $config         = $dashboard_test->default_config;
my $t              = Test::Mojo->new(Dashboard => $config);
my $access_log     = sub { $t->app->log->level eq 'info' ? qr/access_log/ : qr/^$/ };

subtest 'Log level coverage' => sub {
  my $old_level = $t->app->log->level;
  $t->app->log->level('info');
  like 'access_log', $access_log->(), 'access_log info branch';
  $t->app->log->level('warn');
  like '', $access_log->(), 'access_log warn branch';
  $t->app->log->level($old_level);
};

subtest 'No tokens configured' => sub {
  my $no_token_config = {%$config, tokens => []};
  my $t_no            = Test::Mojo->new(Dashboard => $no_token_config);
  stderr_like {
    $t_no->get_ok('/api/incidents')->status_is(200, 'GET should still work');
    $t_no->patch_ok('/api/incidents' => json => [])
      ->status_is(200, 'POST/PATCH/etc should work because no tokens are required');
  }
  $access_log->(), 'access log caught';
};

subtest 'Tokens configured' => sub {
  stderr_like {
    $t->get_ok('/api/incidents')->status_is(200, 'GET bypasses token check');
    $t->patch_ok('/api/incidents' => json => [])
      ->status_is(403, 'missing Authorization header')
      ->json_is({error => 'Permission denied'});
    $t->patch_ok('/api/incidents' => {Authorization => 'Bearer some_token'} => json => [])
      ->status_is(403, 'invalid Authorization header format')
      ->json_is({error => 'Permission denied'});
    $t->patch_ok('/api/incidents' => {Authorization => 'Token wrong_token'} => json => [])
      ->status_is(403, 'incorrect token')
      ->json_is({error => 'Permission denied'});
    $t->patch_ok('/api/incidents' => {Authorization => 'Token test_token'} => json => [])
      ->status_is(200, 'correct token');

    # Extra coverage for Auth::Token branches
    $t->patch_ok('/api/incidents' => {Authorization => 'Token '} => json => [])->status_is(403, 'token is empty');
    $t->patch_ok('/api/incidents' => {Authorization => 'Token'}  => json => [])->status_is(403, 'token prefix only');
  }
  $access_log->(), 'access log caught';
};

done_testing();

# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Mojo::Base -strict, -signatures;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Test::Mojo;
use Test::Warnings ':report_warnings';
use Dashboard::Test;

plan skip_all => 'set TEST_ONLINE to enable this test' unless $ENV{TEST_ONLINE};

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'auth_test');
my $config         = $dashboard_test->default_config;

subtest 'No tokens configured' => sub {
  my $no_token_config = {%$config, tokens => []};
  my $t               = Test::Mojo->new(Dashboard => $no_token_config);
  $t->get_ok('/api/incidents')->status_is(200, 'GET should still work');
  $t->patch_ok('/api/incidents' => json => [])
    ->status_is(200, 'POST/PATCH/etc should work because no tokens are required');
};

subtest 'Tokens configured' => sub {
  my $t = Test::Mojo->new(Dashboard => $config);
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
};

done_testing();

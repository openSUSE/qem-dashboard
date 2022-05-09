# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Mojo::Base -strict, -signatures;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Test::Mojo;
use Dashboard::Test;
use Mojo::JSON qw(false true);

plan skip_all => 'set TEST_ONLINE to enable this test' unless $ENV{TEST_ONLINE};

my $auth_headers = {Authorization => 'Token test_token', Accept => 'application/json'};

subtest 'Clean up old aggregate jobs (during sync)' => sub {
  my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'api_cleanup_test');
  my $config         = $dashboard_test->default_config;
  my $t              = Test::Mojo->new(Dashboard => $config);
  $dashboard_test->cleanup_fixtures($t->app);

  $t->get_ok('/app/api/incident/16861')->status_is(200)->json_is('/details/incident/number', 16861)
    ->json_is('/details/incident/packages', ['perl-Minion', 'perl-Mojo-Pg'])->json_has('/details/jobs/20201107-1')
    ->json_has('/details/jobs/20201107-2')->json_has('/details/jobs/20201108-1')
    ->json_is('/details/incident_summary', {passed => 1});

  $t->patch_ok(
    '/api/incidents' => $auth_headers => json => [
      {
        number      => 16861,
        project     => 'SUSE:Maintenance:16861',
        packages    => ['perl-Minion', 'perl-Mojo-Pg'],
        channels    => ['Test'],
        rr_number   => 230067,
        inReview    => true,
        inReviewQAM => true,
        approved    => false,
        emu         => true,
        isActive    => true
      }
    ]
  )->status_is(200)->json_is({message => 'Ok'});

  $t->get_ok('/app/api/incident/16861')->status_is(200)->json_is('/details/incident/number', 16861)
    ->json_is('/details/incident/packages', ['perl-Minion', 'perl-Mojo-Pg'])->json_has('/details/jobs/20201107-1')
    ->json_hasnt('/details/jobs/20201107-2')->json_hasnt('/details/jobs/20201108-1')
    ->json_is('/details/incident_summary', {passed => 1});
};

subtest 'Clean up jobs after rr_number change (during sync)' => sub {
  my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'api_cleanup_rr_test');
  my $config         = $dashboard_test->default_config;
  my $t              = Test::Mojo->new(Dashboard => $config);
  $dashboard_test->minimal_fixtures($t->app);

  $t->patch_ok(
    '/api/incidents' => $auth_headers => json => [
      {
        number      => 16861,
        project     => 'SUSE:Maintenance:16861',
        packages    => ['perl-Minion', 'perl-Mojo-Pg'],
        channels    => ['Test'],
        rr_number   => 230067,
        inReview    => true,
        inReviewQAM => true,
        approved    => false,
        emu         => true,
        isActive    => true
      }
    ]
  )->status_is(200)->json_is({message => 'Ok'});

  $t->get_ok('/app/api/incident/16860')->status_is(200)->json_is('/details/incident/number', 16860)
    ->json_is('/details/incident/packages', ['perl-Mojolicious'])->json_has('/details/jobs/20201107-1')
    ->json_has('/details/jobs/20201107-2')->json_has('/details/jobs/20201108-1')
    ->json_is('/details/incident_summary', {passed => 1, failed => 1, waiting => 1});
  $t->get_ok('/app/api/incident/16861')->status_is(200)->json_is('/details/incident/number', 16861)
    ->json_is('/details/incident/packages', ['perl-Minion', 'perl-Mojo-Pg'])->json_has('/details/jobs/20201107-1')
    ->json_has('/details/jobs/20201107-2')->json_has('/details/jobs/20201108-1')
    ->json_is('/details/incident_summary', {passed => 1});
  $t->get_ok('/app/api/incident/16862')->status_is(200)->json_is('/details/incident/number', 16862)
    ->json_is('/details/incident/packages', ['curl'])->json_is('/details/incident_summary', {passed => 1});

  $t->patch_ok(
    '/api/incidents' => $auth_headers => json => [
      {
        number      => 16861,
        project     => 'SUSE:Maintenance:16861',
        packages    => ['perl-Minion', 'perl-Mojo-Pg'],
        channels    => ['Test'],
        rr_number   => 230068,
        inReview    => true,
        inReviewQAM => true,
        approved    => false,
        emu         => true,
        isActive    => true
      }
    ]
  )->status_is(200)->json_is({message => 'Ok'});

  $t->get_ok('/app/api/incident/16860')->status_is(200)->json_is('/details/incident/number', 16860)
    ->json_is('/details/incident/packages', ['perl-Mojolicious'])->json_hasnt('/details/jobs/20201107-1')
    ->json_hasnt('/details/jobs/20201107-2')->json_hasnt('/details/jobs/20201108-1')
    ->json_is('/details/incident_summary', {passed => 1, failed => 1, waiting => 1});
  $t->get_ok('/app/api/incident/16861')->status_is(200)->json_is('/details/incident/number', 16861)
    ->json_is('/details/incident/packages', ['perl-Minion', 'perl-Mojo-Pg'])->json_hasnt('/details/jobs/20201107-1')
    ->json_hasnt('/details/jobs/20201107-2')->json_hasnt('/details/jobs/20201108-1')
    ->json_is('/details/incident_summary', {});
  $t->get_ok('/app/api/incident/16862')->status_is(200)->json_is('/details/incident/number', 16862)
    ->json_is('/details/incident/packages', ['curl'])->json_is('/details/incident_summary', {passed => 1});
};

done_testing();

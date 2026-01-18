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

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'models_test');
my $config         = $dashboard_test->default_config;
my $t              = Test::Mojo->new(Dashboard => $config);
$dashboard_test->minimal_fixtures($t->app);

subtest 'Dashboard::Model::Incidents' => sub {
  my $incidents = $t->app->incidents;

  subtest 'id_for_number and number_for_id' => sub {
    is $incidents->id_for_number(16860), 1,     'correct id for 16860';
    is $incidents->number_for_id(1),     16860, 'correct number for id 1';
    is $incidents->id_for_number(99999), undef, 'undef for non-existent number';
    is $incidents->number_for_id(99999), undef, 'undef for non-existent id';
  };

  subtest 'name' => sub {
    my $inc = $incidents->incident_for_number(16860);
    is $incidents->name($inc),              '16860:perl-Mojolicious', 'correct name for 16860';
    is $incidents->name({number => 99999}), '99999:unknown',          'correct name for unknown incident';
  };

  subtest 'job filtering' => sub {
    my $dashboard_test_filter = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'models_filter_test');
    my $app_filter            = Test::Mojo->new(Dashboard => $dashboard_test_filter->default_config)->app;
    $dashboard_test_filter->no_fixtures($app_filter);

    my $incs     = $app_filter->incidents;
    my $settings = $app_filter->settings;
    my $jobs     = $app_filter->jobs;

    $incs->sync(
      [
        {number => 1001, project => 'P1001', packages => ['pkg1'], isActive => 1},
        {number => 1002, project => 'P1002', packages => ['pkg2'], isActive => 1}
      ]
    );

    my $inc1001_id = $incs->id_for_number(1001);
    my $inc1002_id = $incs->id_for_number(1002);

    # Both incidents in the same update
    my $update_settings_id = $settings->add_update_settings(
      [$inc1001_id, $inc1002_id],
      {
        product  => 'Prod',
        arch     => 'x86_64',
        build    => '20260117-1',
        repohash => 'hash1',
        settings => {BUILD => '20260117-1'}
      }
    );

    # Job for 1001
    $jobs->add(
      {
        update_settings => $update_settings_id,
        name            => 'job_for_1001',
        job_group       => 'Group A',
        status          => 'failed',
        job_id          => 100101,
        group_id        => 100,
        distri          => 'd',
        flavor          => 'f',
        version         => 'v',
        arch            => 'x86_64',
        build           => ':1001:some-build'
      }
    );

    # Generic job
    $jobs->add(
      {
        update_settings => $update_settings_id,
        name            => 'generic_job',
        job_group       => 'Group A',
        status          => 'passed',
        job_id          => 100102,
        group_id        => 100,
        distri          => 'd',
        flavor          => 'f',
        version         => 'v',
        arch            => 'x86_64',
        build           => '20260117-1'
      }
    );

    # Obsolete job for 1001
    $jobs->add(
      {
        update_settings => $update_settings_id,
        name            => 'obsolete_job',
        job_group       => 'Group A',
        status          => 'failed',
        job_id          => 100103,
        group_id        => 100,
        distri          => 'd',
        flavor          => 'f',
        version         => 'v',
        arch            => 'x86_64',
        build           => ':1001:obsolete'
      }
    );
    $jobs->modify(100103, {obsolete => 1});

    my $res1001 = $incs->_update_openqa_jobs({id => $inc1001_id, number => 1001});
    is $res1001->{"100 f v"}{failed}, 1, 'Incident 1001 sees its failed job';
    is $res1001->{"100 f v"}{passed}, 1, 'Incident 1001 sees generic job';

    my $res1002 = $incs->_update_openqa_jobs({id => $inc1002_id, number => 1002});
    is $res1002->{"100 f v"}{failed}, undef, 'Incident 1002 does NOT see failed job of 1001';
    is $res1002->{"100 f v"}{passed}, 1,     'Incident 1002 sees generic job';
  };

  subtest 'openqa_summary_only_aggregates branch coverage' => sub {
    my $incs     = $t->app->incidents;
    my $settings = $t->app->settings;
    my $inc      = $incs->incident_for_number(16860);

    # Add another update for 16860 with an existing build number (20201107-1)
    $settings->add_update_settings([$inc->{id}],
      {product => 'ExtraProd', arch => 'x86_64', build => '20201107-1', repohash => 'h2', settings => {}});

    ok $incs->openqa_summary_only_aggregates($inc),
      'works for incident with multiple aggregate jobs sharing same build';
  };

  subtest 'repos branch coverage' => sub {
    my $incs     = $t->app->incidents;
    my $settings = $t->app->settings;

    # Add a repo (update settings) with NO jobs to trigger line 120 branch
    $settings->add_update_settings([1],
      {product => 'NoJobsProduct', arch => 'x86_64', build => '123', repohash => 'h', settings => {}});
    ok $incs->repos, 'repos works even with a repo having no jobs';
  };
};

subtest 'Dashboard::Model::Jobs' => sub {
  my $jobs = $t->app->jobs;

  subtest '_normalize_result' => sub {

    # Internal method, but we can test it via a helper or by making it public/testing through update_result
    is Dashboard::Model::Jobs::_normalize_result('passed'),           'passed';
    is Dashboard::Model::Jobs::_normalize_result('softfailed'),       'passed';
    is Dashboard::Model::Jobs::_normalize_result('none'),             'waiting';
    is Dashboard::Model::Jobs::_normalize_result('failed'),           'failed';
    is Dashboard::Model::Jobs::_normalize_result('timeout_exceeded'), 'stopped';
    is Dashboard::Model::Jobs::_normalize_result('user_cancelled'),   'stopped';
    is Dashboard::Model::Jobs::_normalize_result('something_else'),   'failed';
  };

  subtest 'latest_update with no jobs' => sub {
    my $dashboard_test_empty = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'models_empty_test');
    my $app_empty            = Test::Mojo->new(Dashboard => $dashboard_test_empty->default_config)->app;
    $dashboard_test_empty->no_fixtures($app_empty);
    is $app_empty->jobs->latest_update, undef, 'latest_update is undef when no jobs exist';
  };

  subtest 'update_result with non-existent job' => sub {
    ok !$jobs->update_result(9999999, 'passed'), 'update_result returns false for non-existent job';
  };

  subtest 'keep_schema' => sub {
    my $dashboard_test_keep
      = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'models_keep_test', keep_schema => 1);
    ok $dashboard_test_keep, 'Dashboard::Test->new with keep_schema works';
  };
};

done_testing();

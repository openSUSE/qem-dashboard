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
};

done_testing();

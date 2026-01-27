# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Mojo::Base -strict, -signatures;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Test::Mojo;
use Test::Output qw(stderr_like stdout_like);
use Test::Warnings ':report_warnings';
use Dashboard::Test;
use Time::HiRes ();

plan skip_all => 'set TEST_ONLINE to enable this test' unless $ENV{TEST_ONLINE};

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'dashboard_test');
my $config         = $dashboard_test->default_config;

subtest 'Production mode' => sub {
  local $ENV{MOJO_MODE} = 'production';
  my $t = Test::Mojo->new(Dashboard => $config);
  is $t->app->mode, 'production', 'app is in production mode';
  ok $t->app->log->short, 'short logging is enabled';
  is $t->app->log->level, 'info', 'log level is info';
  stderr_like { $t->get_ok('/')->status_is(200) } qr/access_log/, 'access log caught';
};

subtest 'Zero elapsed time log' => sub {
  local $ENV{MOJO_MODE} = 'production';
  my $t = Test::Mojo->new(Dashboard => $config);
  no warnings 'redefine';
  local *Time::HiRes::tv_interval = sub { return 0 };
  stderr_like { $t->get_ok('/')->status_is(200) } qr/rps":"\?\?"/, 'access log with unknown rps caught';
};

subtest 'Config override' => sub {
  local $ENV{DASHBOARD_CONF_OVERRIDE} = '{"obs":{"url":"https://override.suse.de"}}';
  my $t = Test::Mojo->new(Dashboard => $config);
  is $t->app->config->{obs}{url}, 'https://override.suse.de', 'config overridden via DASHBOARD_CONF_OVERRIDE';
};

subtest 'Custom config file' => sub {
  local $ENV{DASHBOARD_CONF} = 'dashboard.yml';
  my $t = Test::Mojo->new(Dashboard => $config);
  is $t->app->config->{obs}{url}, 'https://build.suse.de', 'config loaded from DASHBOARD_CONF';
};

subtest 'App config endpoint' => sub {
  my $t = Test::Mojo->new(Dashboard => $config);
  stderr_like {
    $t->get_ok('/app-config')
      ->status_is(200)
      ->json_is('/openqaUrl', 'https://openqa.suse.de/tests/overview')
      ->json_is('/obsUrl',    'https://build.suse.de')
      ->json_is('/smeltUrl',  'https://smelt.suse.de');
  }
  qr/access_log/, 'access log caught';
};

subtest 'Migrate command' => sub {
  require Dashboard::Command::migrate;
  my $t = Test::Mojo->new(Dashboard => $config);
  subtest 'when already migrated' => sub {
    my $migrate = Dashboard::Command::migrate->new(app => $t->app);
    is $migrate->description, 'Migrate the database to latest version', 'correct description';
    like $migrate->usage, qr/Usage: APPLICATION migrate/, 'correct usage';
    stdout_like { $migrate->run } qr/Nothing to do/, 'already migrated';
  };

  subtest 'actual migration (dropping schema and running again)' => sub {
    my $dashboard_test_mig = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'migrate_cmd_test');
    my $mig_config         = {%{$dashboard_test_mig->default_config}, auto_migrate => 0};
    my $t_mig              = Test::Mojo->new(Dashboard => $mig_config);
    $t_mig->app->pg->db->query('DROP TABLE IF EXISTS migrations');
    my $migrate_fresh = Dashboard::Command::migrate->new(app => $t_mig->app);
    stdout_like { $migrate_fresh->run } qr/Migrated from 0 to \d+/, 'migrated from fresh';
  };
};

done_testing();

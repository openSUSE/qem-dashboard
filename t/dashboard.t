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
use File::Temp  ();
use Mojo::File;

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

subtest 'Pre-set Request ID' => sub {
  use Mojo::Util qw(monkey_patch);
  my $original = Mojo::Message::Request->can('request_id');
  monkey_patch 'Mojo::Message::Request', request_id => sub {'test-id-123'};
  my $t = Test::Mojo->new(Dashboard => $config);
  stderr_like {
    $t->get_ok('/')->status_is(200);
  }
  qr/request_id":"test-id-123"/, 'custom request id is preserved';
  monkey_patch 'Mojo::Message::Request', request_id => $original;
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

subtest 'Config override' => sub {
  local $ENV{DASHBOARD_CONF_OVERRIDE} = '{"obs":{"url":"https://override.suse.de"}}';
  my $t = Test::Mojo->new(Dashboard => $config);
  is $t->app->config->{obs}{url}, 'https://override.suse.de', 'config overridden via DASHBOARD_CONF_OVERRIDE';
};

subtest 'App config endpoint' => sub {
  my $t = Test::Mojo->new(Dashboard => $config);
  stderr_like {
    $t->get_ok('/app-config')
      ->status_is(200)
      ->json_has('/bootId')
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

subtest 'Vite asset helper' => sub {
  my $minimal_config = {%$config, secrets => ['test']};

  subtest 'development mode, no server, no manifest' => sub {
    local $ENV{MOJO_MODE}       = 'development';
    local $ENV{VITE_DEV_SERVER} = 0;
    my $t = Test::Mojo->new(Dashboard => $minimal_config);
    $t->app->home(Mojo::Home->new(File::Temp::tempdir(CLEANUP => 1)));

    my $output = $t->app->vite_asset('main.js');
    like $output, qr/localhost:5173/, 'fallback to dev server link in dev mode without manifest';
  };

  subtest 'development mode with server' => sub {
    local $ENV{MOJO_MODE}       = 'development';
    local $ENV{VITE_DEV_SERVER} = 1;
    my $t      = Test::Mojo->new(Dashboard => $minimal_config);
    my $output = $t->app->vite_asset('main.js');
    like $output, qr/localhost:5173/, 'dev server link used when VITE_DEV_SERVER is set';
  };

  subtest 'production mode, missing manifest' => sub {
    local $ENV{MOJO_MODE} = 'production';
    my $t = Test::Mojo->new(Dashboard => $minimal_config);
    $t->app->home(Mojo::Home->new(File::Temp::tempdir(CLEANUP => 1)));
    my $output = $t->app->vite_asset('main.js');
    like $output, qr/vite_asset: manifest not found/, 'manifest not found comment in production';
  };

  subtest 'production mode, missing entry' => sub {
    my $dir          = File::Temp::tempdir(CLEANUP => 1);
    my $manifest_dir = Mojo::File->new($dir)->child('public', 'asset', '.vite');
    $manifest_dir->make_path;
    $manifest_dir->child('manifest.json')->spurt('{"main.js": {"file": "main.123.js"}}');

    local $ENV{MOJO_MODE} = 'production';
    my $t = Test::Mojo->new(Dashboard => $minimal_config);
    $t->app->home(Mojo::Home->new($dir));

    my $output = $t->app->vite_asset('missing.js');
    like $output, qr/vite_asset: entry missing.js not found/, 'entry not found comment';

    $output = $t->app->vite_asset('main.js');
    like $output,   qr/main.123.js/,           'correct asset link from manifest';
    unlike $output, qr/link rel="stylesheet"/, 'no CSS link if not present in manifest';
  };

  subtest 'production mode with CSS' => sub {
    my $dir          = File::Temp::tempdir(CLEANUP => 1);
    my $manifest_dir = Mojo::File->new($dir)->child('public', 'asset', '.vite');
    $manifest_dir->make_path;
    $manifest_dir->child('manifest.json')->spurt('{"main.js": {"file": "main.123.js", "css": ["main.456.css"]}}');

    local $ENV{MOJO_MODE} = 'production';
    my $t = Test::Mojo->new(Dashboard => $minimal_config);
    $t->app->home(Mojo::Home->new($dir));

    my $output = $t->app->vite_asset('main.js');
    like $output, qr/main.123.js/,  'correct JS link';
    like $output, qr/main.456.css/, 'correct CSS link';
  };
};

subtest 'Overview API with no jobs' => sub {
  my $dashboard_test_empty = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'dashboard_empty_api_test');
  my $app_empty            = Test::Mojo->new(Dashboard => $dashboard_test_empty->default_config)->app;
  $dashboard_test_empty->no_fixtures($app_empty);
  my $t = Test::Mojo->new($app_empty);

  stderr_like {
    $t->get_ok('/app/api/list')->status_is(200)->json_is('/last_updated', undef, 'last_updated is undef when no jobs');
  }
  qr/access_log/, 'access log caught';
};

done_testing();

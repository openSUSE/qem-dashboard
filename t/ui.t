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

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'ui_test');
my $config         = $dashboard_test->default_config;
my $t              = Test::Mojo->new(Dashboard => $config);
$dashboard_test->minimal_fixtures($t->app);

subtest 'Webpack provided under various URLs' => sub {
  $t->get_ok('/')->status_is(200)->text_like('#app' => qr/This application requires JavaScript!/);
  $t->get_ok('/blocked')->status_is(200)->text_like('#app' => qr/This application requires JavaScript!/);
  $t->get_ok('/repos')->status_is(200)->text_like('#app' => qr/This application requires JavaScript!/);
  $t->get_ok('/incident/16860')->status_is(200)->text_like('#app' => qr/This application requires JavaScript!/);
};

done_testing();

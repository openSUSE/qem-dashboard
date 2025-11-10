# Copyright (C) 2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

use Mojo::Base -strict, -signatures;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Test::Mojo;
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

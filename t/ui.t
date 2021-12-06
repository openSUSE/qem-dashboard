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

$ENV{MOJO_WEBPACK_BUILD} = 1;
my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'ui_test');
my $config         = $dashboard_test->default_config;
my $t              = Test::Mojo->new(Dashboard => $config);
$dashboard_test->minimal_fixtures($t->app);

subtest 'Menu' => sub {
  $t->get_ok('/')->status_is(200)->text_like('nav ul li a', qr/Active/)
    ->text_like('nav ul li:nth-of-type(2) a', qr/Blocked/)->text_like('nav ul li:nth-of-type(3) a', qr/Repos/)
    ->text_like('nav ul:nth-of-type(2) a',    qr/API/);
};

subtest 'Overview' => sub {
  $t->get_ok('/')->status_is(200)->text_like('head title ', qr/Active Incidents/)
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(1) a',    qr/16860:perl-Mojolicious/)
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(2) span', qr/testing/)
    ->text_like('tbody tr:nth-of-type(2) td:nth-of-type(1) a',    qr/16861:perl-Minion/)
    ->text_like('tbody tr:nth-of-type(2) td:nth-of-type(2) span', qr/staged/)
    ->text_like('tbody tr:nth-of-type(3) td:nth-of-type(1) a',    qr/16862:curl/)
    ->text_like('tbody tr:nth-of-type(3) td:nth-of-type(2) span', qr/approved/);
};

subtest 'Blocked by Tests' => sub {
  $t->get_ok('/blocked')->status_is(200)->text_like('head title ', qr/Blocked by Tests/)
    ->element_exists('tbody tr:nth-of-type(1) td:nth-of-type(1) a[name=16860]')
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(1) a.incident-link',           qr/16860:perl-Mojolicious/)
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(2) ul li:nth-of-type(1) a',    qr/SLE 12 SP5/)
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(2) ul li:nth-of-type(1) span', qr!1/1!)
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(2) ul li:nth-of-type(2) a',    qr/SLE 12 SP5 Kernel/)
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(2) ul li:nth-of-type(2) span', qr!1!)
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(2) ul li:nth-of-type(3) a',    qr/SLE 12 SP4/)
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(2) ul li:nth-of-type(3) span', qr!1/1!);
};

subtest 'Test Repos' => sub {
  $t->get_ok('/repos')->status_is(200)->text_like('head title ', qr/Test Repos/)
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(1) div',             qr/Server-DVD-Incidents-12-SP5-x86_64/)
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(1) div button span', qr/2/)
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(1) div button',      qr/Incidents/)
    ->element_exists('tbody tr:nth-of-type(1) td:nth-of-type(2) ul li:nth-of-type(1) a.btn-info')
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(2) ul li:nth-of-type(1) a',      qr/20201108-1/)
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(2) ul li:nth-of-type(1) a span', qr!1/1!)
    ->element_exists('tbody tr:nth-of-type(1) td:nth-of-type(2) ul li:nth-of-type(2) a.btn-danger')
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(2) ul li:nth-of-type(2) a',      qr/20201107-2/)
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(2) ul li:nth-of-type(2) a span', qr!1/2!)
    ->element_exists('tbody tr:nth-of-type(1) td:nth-of-type(2) ul li:nth-of-type(3) a.btn-success')
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(2) ul li:nth-of-type(3) a',      qr/20201107-1/)
    ->text_like('tbody tr:nth-of-type(1) td:nth-of-type(2) ul li:nth-of-type(3) a span', qr/1/)
    ->text_like('tbody tr:nth-of-type(1) div.modal-header h5', qr/Incidents for Server-DVD-Incidents-12-SP5-x86_64/)
    ->text_like('tbody tr:nth-of-type(1) div.modal-body ul li:nth-of-type(1) a', qr/16860:perl-Mojolicious/)
    ->text_like('tbody tr:nth-of-type(1) div.modal-body ul li:nth-of-type(2) a', qr/16861:perl-Minion/);
};

subtest 'Incident Details' => sub {
  $t->get_ok('/incident/16860')->status_is(200)->text_like('head title ', qr/Details for incident 16860/)
    ->text_like('.incident-results', qr/1 passed, 1 failed, 1 waiting/)
    ->text_like('.smelt-link a',     qr/16860:perl-Mojolicious/);
};

done_testing();

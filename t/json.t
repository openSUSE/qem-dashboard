# Copyright (C) SUSE LLC
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

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'json_test');
my $config         = $dashboard_test->default_config;
my $t              = Test::Mojo->new(Dashboard => $config);
$dashboard_test->minimal_fixtures($t->app);

subtest 'List incidents' => sub {

  $t->get_ok('/' => {Accept => 'application/json'})->status_is(200)
    ->json_is('/results' => 3, 'Incidents exist in test database')->json_is(
    '/incidents/approved' => [
      {
        "approved"    => 1,
        "channels"    => ["Test"],
        "emu"         => 1,
        "inReview"    => 1,
        "inReviewQAM" => 1,
        "isActive"    => 1,
        "number"      => 16862,
        "packages"    => ["curl"],
        "project"     => "SUSE:Maintenance:16862",
        "rr_number"   => undef
      }
    ],
    '1 approved Incident for curl'
  )->json_is(
    '/incidents/testing' => [
      {
        "approved"    => 0,
        "channels"    => ["Test"],
        "emu"         => 1,
        "inReview"    => 1,
        "inReviewQAM" => 1,
        "isActive"    => 1,
        "number"      => 16860,
        "packages"    => ["perl-Mojolicious"],
        "project"     => "SUSE:Maintenance:16860",
        "rr_number"   => 230066
      }
    ],
    'perl-Mojolicious is testing'
  )->json_is(
    '/incidents/staged' => [
      {
        "approved"    => 0,
        "channels"    => ["Test"],
        "emu"         => 1,
        "inReview"    => 1,
        "inReviewQAM" => 1,
        "isActive"    => 1,
        "number"      => 16861,
        "packages"    => ["perl-Minion", "perl-Mojo-Pg"],
        "project"     => "SUSE:Maintenance:16861",
        "rr_number"   => undef
      }
    ],
    'perl-Minion is staged'
  );

};

subtest 'Blocked by Tests' => sub {

  $t->get_ok('/blocked' => {Accept => 'application/json'})->status_is(200)->json_is(
    '/blocked' => [
      {
        incident => {
          "active"     => 1,
          "approved"   => 0,
          "emu"        => 1,
          "id"         => 1,
          "number"     => 16860,
          "packages"   => ["perl-Mojolicious"],
          "project"    => "SUSE:Maintenance:16860",
          "review"     => 1,
          "review_qam" => 1,
          "rr_number"  => 230066
        },
        incident_results => {
          "282" => {
            "linkinfo" => {"build" => ":17063:perl-Mojolicious", "distri" => "sle", "groupid" => 282},
            "name"     => "SLE 12 SP5",
            "waiting"  => 1
          },
          "283" => {
            "linkinfo" => {"build" => ":17063:perl-Mojolicious", "distri" => "sle", "groupid" => 283},
            "name"     => "SLE 12 SP5 Kernel",
            "passed"   => 1
          },
          "284" => {
            "failed"   => 1,
            "linkinfo" => {"build" => ":17063:perl-Mojolicious", "distri" => "sle", "groupid" => 284},
            "name"     => "SLE 12 SP4"
          }
        },
        update_results => {
          "54 Server-DVD-Incidents 12-SP5" => {
            "linkinfo" => {
              "build"   => "20201108-1",
              "distri"  => "sle",
              "flavor"  => "Server-DVD-Incidents",
              "groupid" => 54,
              "version" => "12-SP5"
            },
            "name"    => "SLE 12 SP5",
            "waiting" => 1
          }
        }
      }
    ]

  );
};

subtest 'Test Repos' => sub {
  $t->get_ok('/repos' => {Accept => 'application/json'})->status_is(200)
    ->json_is('/titles/Server-DVD-Incidents-12-SP5-x86_64/incidents' =>
      [{"id" => 1, "number" => 16860}, {"id" => 2, "number" => 16861}])->json_is(
    '/titles/Server-DVD-Incidents-12-SP5-x86_64/summaries' => [
      {
        "linkinfo" => {
          "arch"    => "x86_64",
          "build"   => "20201108-1",
          "distri"  => "sle",
          "flavor"  => "Server-DVD-Incidents",
          "groupid" => 54,
          "version" => "12-SP5"
        },
        "name"    => "20201108-1",
        "waiting" => 1
      },
      {
        "failed"   => 1,
        "linkinfo" => {
          "arch"    => "x86_64",
          "build"   => "20201107-2",
          "distri"  => "sle",
          "flavor"  => "Server-DVD-Incidents",
          "groupid" => 54,
          "version" => "12-SP5"
        },
        "name"   => "20201107-2",
        "passed" => 1
      },
      {
        "linkinfo" => {
          "arch"    => "x86_64",
          "build"   => "20201107-1",
          "distri"  => "sle",
          "flavor"  => "Server-DVD-Incidents",
          "groupid" => 54,
          "version" => "12-SP5"
        },
        "name"   => "20201107-1",
        "passed" => 1
      }
    ]
      );
};

subtest 'Incident Details' => sub {
  $t->get_ok('/incident/16860' => {Accept => 'application/json'})->status_is(200)->json_is(
    '/incident' => {
      "active"     => 1,
      "approved"   => 0,
      "emu"        => 1,
      "id"         => 1,
      "number"     => 16860,
      "packages"   => ["perl-Mojolicious"],
      "project"    => "SUSE:Maintenance:16860",
      "review"     => 1,
      "review_qam" => 1,
      "rr_number"  => 230066
    }
  )->json_is(
    '/jobs' => {
      "20201107-1" => [
        {
          "arch"      => "x86_64",
          "build"     => "20201107-1",
          "distri"    => "sle",
          "flavor"    => "Server-DVD-Incidents",
          "group_id"  => 54,
          "job_group" => "Maintenance: SLE 12 SP5 Updates",
          "job_id"    => 4953199,
          "name"      => "mau-webserver\@64bit",
          "status"    => "passed",
          "version"   => "12-SP5"
        }
      ],
      "20201107-2" => [
        {
          "arch"      => "aarch64",
          "build"     => "20201107-2",
          "distri"    => "sle",
          "flavor"    => "Server-DVD-Incidents",
          "group_id"  => 54,
          "job_group" => "Maintenance: SLE 12 SP5 Updates",
          "job_id"    => 4953205,
          "name"      => "mau-webserver\@64bit",
          "status"    => "passed",
          "version"   => "12-SP5"
        },
        {
          "arch"      => "x86_64",
          "build"     => "20201107-2",
          "distri"    => "sle",
          "flavor"    => "Server-DVD-Incidents",
          "group_id"  => 54,
          "job_group" => "Maintenance: SLE 12 SP5 Updates",
          "job_id"    => 4953200,
          "name"      => "mau-webserver\@64bit",
          "status"    => "failed",
          "version"   => "12-SP5"
        }
      ],
      "20201108-1" => [
        {
          "arch"      => "x86_64",
          "build"     => "20201108-1",
          "distri"    => "sle",
          "flavor"    => "Server-DVD-Incidents",
          "group_id"  => 54,
          "job_group" => "Maintenance: SLE 12 SP5 Updates",
          "job_id"    => 4953203,
          "name"      => "mau-webserver\@64bit",
          "status"    => "waiting",
          "version"   => "12-SP5"
        }
      ]
    }
  );

};

done_testing();

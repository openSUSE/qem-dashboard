# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Mojo::Base -strict, -signatures;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Test::Mojo;
use Test::Output 'stderr_like';
use Test::Warnings ':report_warnings';
use Dashboard::Test;

plan skip_all => 'set TEST_ONLINE to enable this test' unless $ENV{TEST_ONLINE};

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'json_test');
my $config         = $dashboard_test->default_config;
my $t              = Test::Mojo->new(Dashboard => $config);
$dashboard_test->minimal_fixtures($t->app);

subtest 'List incidents' => sub {
  stderr_like {
    $t->get_ok('/app/api/list' => {Accept => 'application/json'})->status_is(200)->json_has('/last_updated')->json_is(
      '/incidents' => [
        {
          "approved"    => 0,
          "channels"    => ["Test"],
          "emu"         => 1,
          "embargoed"   => 1,
          "inReview"    => 1,
          "inReviewQAM" => 1,
          "isActive"    => 1,
          "number"      => 16860,
          "packages"    => ["perl-Mojolicious"],
          "priority"    => undef,
          "project"     => "SUSE:Maintenance:16860",
          "rr_number"   => 230066,
          "scminfo"     => "",
          "url"         => "",
          "type"        => "",
        },
        {
          "approved"    => 0,
          "channels"    => ["Test"],
          "emu"         => 1,
          "embargoed"   => 1,
          "inReview"    => 1,
          "inReviewQAM" => 1,
          "isActive"    => 1,
          "number"      => 16861,
          "packages"    => ["perl-Minion", "perl-Mojo-Pg"],
          "priority"    => undef,
          "project"     => "SUSE:Maintenance:16861",
          "rr_number"   => undef,
          "scminfo"     => "",
          "url"         => "",
          "type"        => "",
        },
        {
          "approved"    => 1,
          "channels"    => ["Test"],
          "emu"         => 1,
          "embargoed"   => 1,
          "inReview"    => 1,
          "inReviewQAM" => 1,
          "isActive"    => 1,
          "number"      => 16862,
          "packages"    => ["curl"],
          "priority"    => undef,
          "project"     => "SUSE:Maintenance:16862",
          "rr_number"   => undef,
          "scminfo"     => "",
          "url"         => "",
          "type"        => "",
        },
        {
          "approved" => 0,
          "channels" => [
            "SUSE:Updates:openSUSE-SLE:15.4",
            "SUSE:Updates:SLE-Module-Basesystem:15-SP4:x86_64",
            "SUSE:Updates:SLE-Module-Basesystem:15-SP4:s390x",
            "SUSE:Updates:SLE-Module-Basesystem:15-SP4:aarch64",
            "SUSE:Updates:SLE-Module-Basesystem:15-SP4:ppc64le",
            "SUSE:SLE-15-SP4:Update",
            "SUSE:Updates:SLE-Product-SLES:15-SP4-TERADATA:x86_64",
            "SUSE:Updates:SLE-Micro:5.3:x86_64",
            "SUSE:Updates:SLE-Micro:5.3:aarch64",
            "SUSE:Updates:SLE-Micro:5.3:s390x",
            "SUSE:Updates:openSUSE-Leap-Micro:5.3",
            "SUSE:Updates:SLE-Micro:5.4:x86_64",
            "SUSE:Updates:SLE-Micro:5.4:s390x",
            "SUSE:Updates:SLE-Micro:5.4:aarch64",
            "SUSE:Updates:openSUSE-Leap-Micro:5.4"
          ],
          "embargoed"   => 0,
          "emu"         => 0,
          "inReview"    => 1,
          "inReviewQAM" => 1,
          "isActive"    => 1,
          "number"      => 29722,
          "packages"    => ["multipath-tools"],
          "priority"    => 700,
          "project"     => "SUSE:Maintenance:29722 ",
          "rr_number"   => 302772,
          "scminfo"     => "",
          "url"         => "",
          "type"        => "",
        }
      ]
    )
  }
  qr/access_log/, 'access log caught';
};

subtest 'Blocked by Tests' => sub {
  stderr_like {
    $t->get_ok('/app/api/blocked' => {Accept => 'application/json'})
      ->status_is(200)
      ->json_has('/last_updated')
      ->json_is(
      '/blocked' => [
        {
          "incident" => {
            "active"     => 1,
            "approved"   => 0,
            "embargoed"  => 1,
            "emu"        => 1,
            "id"         => 1,
            "number"     => 16860,
            "packages"   => ["perl-Mojolicious"],
            "priority"   => undef,
            "project"    => "SUSE:Maintenance:16860",
            "review"     => 1,
            "review_qam" => 1,
            "rr_number"  => 230066,
            "scminfo"    => "",
            "url"        => "",
            "type"       => "",
          },
          "incident_results" => {
            "55" => {
              "name"     => 'Server-DVD-Incidents 12-SP6',
              "linkinfo" => {"build" => "20250317-1", "distri" => "sle", "groupid" => 55},
              "passed"   => 2
            },
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
          "update_results" => {
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
            },
            "55 Server-DVD-Incidents 12-SP6" => {
              "linkinfo" => {
                "build"   => "20250317-1",
                "distri"  => "sle",
                "flavor"  => "Server-DVD-Incidents",
                "groupid" => 55,
                "version" => "12-SP6"
              },
              "name"   => "Server-DVD-Incidents 12-SP6",
              "passed" => 2
            }
          }
        },
        {
          "incident" => {
            "active"     => 1,
            "approved"   => 0,
            "embargoed"  => 0,
            "emu"        => 0,
            "id"         => 4,
            "number"     => 29722,
            "packages"   => ["multipath-tools"],
            "priority"   => 700,
            "project"    => "SUSE:Maintenance:29722 ",
            "review"     => 1,
            "review_qam" => 1,
            "rr_number"  => 302772,
            "scminfo"    => "",
            "url"        => "",
            "type"       => "",
          },
          "incident_results" => {},
          "update_results"   => {
            "405 SAP-DVD-Updates 15-SP4" => {
              "failed"   => 1,
              "linkinfo" => {
                "build"   => "20230712-1",
                "distri"  => "sle",
                "flavor"  => "SAP-DVD-Updates",
                "groupid" => 405,
                "version" => "15-SP4"
              },
              "name"   => "SAP/HA Maintenance",
              "passed" => 2
            },
            "405 Server-DVD-HA-Updates 15-SP4" => {
              "linkinfo" => {
                "build"   => "20230709-1",
                "distri"  => "sle",
                "flavor"  => "Server-DVD-HA-Updates",
                "groupid" => 405,
                "version" => "15-SP4"
              },
              "name"   => "SAP/HA Maintenance",
              "passed" => 2
            },
            "55 Server-DVD-Incidents 12-SP6" => {
              "linkinfo" => {
                "build"   => "20250317-1",
                "distri"  => "sle",
                "flavor"  => "Server-DVD-Incidents",
                "groupid" => 55,
                "version" => "12-SP6"
              },
              "name"   => "Server-DVD-Incidents 12-SP6",
              "passed" => 1,
              "failed" => 1
            }
          }
        }
      ]
      )
  }
  qr/access_log/, 'access log caught';
};

subtest 'Test Repos' => sub {
  stderr_like {
    $t->get_ok('/app/api/repos' => {Accept => 'application/json'})->status_is(200)->json_has('/last_updated')->json_is(
      '/repos/Server-DVD-Incidents-12-SP5-x86_64/incidents' => [
        {"id" => 1, "number" => 16860, "packages" => ['perl-Mojolicious']},
        {"id" => 2, "number" => 16861, "packages" => ['perl-Minion', 'perl-Mojo-Pg']}
      ]
    )->json_is(
      '/repos/Server-DVD-Incidents-12-SP5-x86_64/summaries' => [
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
    )
  }
  qr/access_log/, 'access log caught';
};

subtest 'Incident Details' => sub {
  stderr_like {
    $t->get_ok('/app/api/incident/16860' => {Accept => 'application/json'})
      ->status_is(200)
      ->json_has('/last_updated')
      ->status_is(200)
      ->json_is(
      '/details/incident' => {
        "active"     => 1,
        "approved"   => 0,
        "emu"        => 1,
        "embargoed"  => 1,
        "id"         => 1,
        "number"     => 16860,
        "packages"   => ["perl-Mojolicious"],
        "priority"   => undef,
        "project"    => "SUSE:Maintenance:16860",
        "review"     => 1,
        "review_qam" => 1,
        "rr_number"  => 230066,
        "scminfo"    => "",
        "url"        => "",
        "type"       => "",
      }
      )
      ->json_is(
      '/details/jobs' => {
        "20250317-1" => [
          {
            "arch"      => "x86_64",
            "build"     => "20250317-1",
            "distri"    => "sle",
            "flavor"    => "Server-DVD-Incidents",
            "group_id"  => 55,
            "job_group" => "Server-DVD-Incidents 12-SP6",
            "job_id"    => 4953600,
            "name"      => "acceptable_for_16860_despite_failing\@64bit",
            "status"    => "failed",
            "version"   => "12-SP6"
          },
          {
            "arch"      => "x86_64",
            "build"     => "20250317-1",
            "distri"    => "sle",
            "flavor"    => "Server-DVD-Incidents",
            "group_id"  => 55,
            "job_group" => "Server-DVD-Incidents 12-SP6",
            "job_id"    => 4953601,
            "name"      => "acceptable_for_16860_but_passing_anyway\@64bit",
            "status"    => "passed",
            "version"   => "12-SP6"
          }
        ],
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
      )
      ->json_is('/details/incident_summary' => {waiting => 1, failed => 2, passed => 2})
      ->json_is('/details/build_nr'         => '20250317-1')
  }
  qr/access_log/, 'access log caught';
};

subtest 'Plugin::JSON' => sub {
  stderr_like {
    $t->get_ok('/non_existent' => {Accept => 'application/json'})
      ->status_is(404, 'trigger 404 for JSON client')
      ->json_is({error => 'Resource not found'});

    $t->get_ok('/non_existent' => {Accept => 'text/html'})
      ->status_is(404, 'trigger 404 for non-JSON client (should not return JSON error)')
      ->content_unlike(qr/Resource not found/);
    $t->app->routes->get('/die' => sub { die "intentional death" });
    $t->get_ok('/die' => {Accept => 'application/json'})
      ->status_is(500, 'trigger exception (by accessing a route that dies)')
      ->json_is({error => 'Unexpected server error'});
  }
  qr/intentional death.*access_log/s, 'exception and access logs caught';
};


done_testing();

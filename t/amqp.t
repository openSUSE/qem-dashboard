# Copyright (C) 2021 SUSE LLC
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

use Mojolicious::Lite -signatures;
use Test::More;
use Test::Mojo;
use Test::MockModule;
use Dashboard::Test;
use Mojo::JSON qw(false true);

plan skip_all => 'set TEST_ONLINE to enable this test' unless $ENV{TEST_ONLINE};

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'amqp_test');
my $config         = $dashboard_test->default_config;
my $t              = Test::Mojo->new(Dashboard => $config);
$dashboard_test->minimal_fixtures($t->app);
my $db = $t->app->pg->db;

get(
  '/api/v1/jobs/4953204' => sub ($c) {
    $c->render(
      json => {
        job => {
          assets => {
            hdd => [
              "SLES-15-SP3-x86_64-mru-install-minimal-with-addons-Build:21715:virt-manager-Server-DVD-Incidents-64bit.qcow2",
            ],
            iso => ["SLE-15-SP3-Full-x86_64-GM-Media1.iso"],
          },
          blocked_by_id => undef,
          children      => {"Chained" => [], "Directly chained" => [], "Parallel" => []},
          clone_id      => undef,
          group         => "Maintenance: SLE 15 SP3 Incidents",
          group_id      => 367,
          has_parents   => 1,
          id            => 4953204,
          name          =>
            "sle-15-SP3-Server-DVD-Incidents-x86_64-Build:21715:virt-manager-mau-sles-sys-param-check\@64bit-2gbram",
          origin_id       => 7636821,
          parent_group    => "Maintenance: Single Incidents",
          parent_group_id => 8,
          parents         => {"Chained" => [], "Directly chained" => [], "Parallel" => []},
          parents_ok      => "",
          priority        => 50,
          result          => "skipped",
          settings        => {
            ARCH    => "x86_64",
            BACKEND => "qemu",
            BUILD   => ":21715:virt-manager",
            DISTRI  => "sle",
            FLAVOR  => "Server-DVD-Incidents",
            HDD_1   =>
              "SLES-15-SP3-x86_64-mru-install-minimal-with-addons-Build:21715:virt-manager-Server-DVD-Incidents-64bit.qcow2",
            HDDSIZEGB   => 20,
            INCIDENT_ID => 21715,
            ISO         => "SLE-15-SP3-Full-x86_64-GM-Media1.iso",
            MACHINE     => "64bit-2gbram",
            NAME        =>
              "04953204-sle-15-SP3-Server-DVD-Incidents-x86_64-Build:21715:virt-manager-mau-sles-sys-param-check\@64bit-2gbram",
            REPOHASH                   => 1636453551,
            TEST                       => "mau-sles-sys-param-check",
            TEST_SUITE_NAME            => "-",
            VERSION                    => "15-SP3",
            VIRTIO_CONSOLE             => 1,
            WORKER_CLASS               => "qemu_x86_64",
            YAML_SCHEDULE              => "schedule/qam/common/sys_param_check.yaml",
            ZYPPER_ORPHANED_CHECK_ONLY => 1,
          },
          state      => "cancelled",
          t_finished => "2021-12-08T14:18:28",
          t_started  => undef,
          test       => "mau-sles-sys-param-check",
        }
      }
    );
  }
);

get(
  '/api/v1/jobs/4953207' => sub ($c) {
    $c->render(
      json => {
        job => {
          assets => {
            hdd => [
              "SLES-15-SP3-x86_64-mru-install-minimal-with-addons-Build:21715:virt-manager-Server-DVD-Incidents-64bit.qcow2",
            ],
            iso => ["SLE-15-SP3-Full-x86_64-GM-Media1.iso"],
          },
          blocked_by_id => undef,
          children      => {"Chained" => [], "Directly chained" => [], "Parallel" => []},
          clone_id      => undef,
          group         => "Maintenance: SLE 15 SP3 Incidents",
          group_id      => 367,
          has_parents   => 1,
          id            => 4953207,
          name          =>
            "sle-15-SP3-Server-DVD-Incidents-x86_64-Build:21715:virt-manager-mau-sles-sys-param-check\@64bit-2gbram",
          origin_id       => undef,
          parent_group    => "Maintenance: Single Incidents",
          parent_group_id => 8,
          parents         => {"Chained" => [], "Directly chained" => [], "Parallel" => []},
          parents_ok      => "",
          priority        => 50,
          result          => "none",
          settings        => {
            ARCH    => "x86_64",
            BACKEND => "qemu",
            BUILD   => "20201108-1",
            DISTRI  => "sle",
            FLAVOR  => "Server-DVD-Updates",
            HDD_1   =>
              "SLES-15-SP3-x86_64-mru-install-minimal-with-addons-Build:21715:virt-manager-Server-DVD-Incidents-64bit.qcow2",
            HDDSIZEGB   => 20,
            INCIDENT_ID => 21715,
            ISO         => "SLE-12-SP5-Full-x86_64-GM-Media1.iso",
            MACHINE     => "64bit-2gbram",
            NAME        =>
              "04953207-sle-15-SP3-Server-DVD-Incidents-x86_64-Build:21715:virt-manager-mau-sles-sys-param-check\@64bit-2gbram",
            REPOHASH                   => "d5815a9f8aa482ec8288508da27a9d38",
            TEST                       => "mau-sles-sys-param-check",
            TEST_SUITE_NAME            => "-",
            VERSION                    => "12-SP5",
            VIRTIO_CONSOLE             => 1,
            WORKER_CLASS               => "qemu_x86_64",
            YAML_SCHEDULE              => "schedule/qam/common/sys_param_check.yaml",
            ZYPPER_ORPHANED_CHECK_ONLY => 1,
          },
          state      => "scheduled",
          t_finished => "2021-12-08T14:18:28",
          t_started  => undef,
          test       => "mau-sles-sys-param-check",
        }
      }
    );
  }
);

any(
  '/*whatever' => {whatever => ''} => sub ($c) {
    my $whatever = $c->param('whatever');
    $c->render(text => "/$whatever did not match.", status => 404);
  }
);

my $fake_openqa_url = 'http://127.0.0.1:' . $t->app->ua->server->app(app)->url->port;
my $openqa_mock     = Test::MockModule->new('Dashboard::Model::OpenQA');
$openqa_mock->redefine(_openqa_url => sub { return Mojo::URL->new($fake_openqa_url) });

sub _is_field ($field, $expected) {
  is($db->query("select $field from openqa_jobs where id=7")->hash->{$field}, $expected);
}

sub _set_default() {
  $db->query("update openqa_jobs set status='waiting', job_id=4953203 where id=7");
}

subtest 'Handle done job' => sub {
  _set_default();
  $t->app->amqp->process_event(
    'suse.openqa.job.done',
    {
      "ARCH"      => "x86_64",
      "BUILD"     => "721304-Bogdan.Lezhepekov_branch_mr_4",
      "FLAVOR"    => "qemu",
      "HDD_1"     => "carwos-Bogdan.Lezhepekov_branch_mr_4-721304.qcow2",
      "MACHINE"   => "64bit",
      "TEST"      => "carwos-futex-performance",
      "bugref"    => undef,
      "group_id"  => 54,
      "id"        => 4953203,
      "newbuild"  => undef,
      "reason"    => undef,
      "remaining" => 0,
      "result"    => "user_cancelled"
    }
  );
  _is_field('status', 'stopped');
};

subtest 'Handle cancel job' => sub {
  _set_default();
  $t->app->amqp->process_event(
    'suse.openqa.job.cancel',
    {
      "ARCH"      => "x86_64",
      "BUILD"     => "721304-Bogdan.Lezhepekov_branch_mr_4",
      "FLAVOR"    => "qemu",
      "HDD_1"     => "carwos-Bogdan.Lezhepekov_branch_mr_4-721304.qcow2",
      "MACHINE"   => "64bit",
      "TEST"      => "carwos-futex-performance",
      "group_id"  => 328,
      "id"        => 4953203,
      "remaining" => 0
    }
  );
  _is_field('status', 'stopped');
};

subtest 'Handle restart job' => sub {
  _set_default();
  $t->app->amqp->process_event(
    'suse.openqa.job.restart',
    {
      "ARCH"      => "x86_64",
      "BUILD"     => "721304-Bogdan.Lezhepekov_branch_mr_4",
      "FLAVOR"    => "qemu",
      "HDD_1"     => "carwos-Bogdan.Lezhepekov_branch_mr_4-721304.qcow2",
      "MACHINE"   => "64bit",
      "TEST"      => "carwos-futex-performance",
      "auto"      => 0,
      "bugref"    => undef,
      "group_id"  => 328,
      "id"        => 4953203,
      "remaining" => 1,
      "result"    => {"4953203" => 7764022}
    }
  );

  _is_field('status', 'waiting');
  _is_field('job_id', 7764022);
};

subtest 'Handle create job' => sub {
  _set_default();
  my $jobs_count = $db->query("select count(id) from openqa_jobs")->hash->{count};
  $t->app->amqp->process_event(
    'suse.openqa.job.create',
    {
      "ARCH"      => "x86_64",
      "BUILD"     => ":22060:tboot",
      "FLAVOR"    => "Server-DVD-Incidents-Install",
      "HDD_1"     => "SLES-15-SP3-x86_64-Installtest.qcow2",
      "ISO"       => "SLE-15-SP3-Full-x86_64-GM-Media1.iso",
      "MACHINE"   => "64bit",
      "TEST"      => "qam-incidentinstall",
      "group_id"  => 367,
      "id"        => 4953204,
      "remaining" => 34
    }
  );
  my $new_jobs_count = $db->query("select count(id) from openqa_jobs")->hash->{count};
  is($new_jobs_count, $jobs_count, "unrelated jobs are ignored");
  $t->app->amqp->process_event(
    'suse.openqa.job.create',
    {
      "ARCH"      => "x86_64",
      "BUILD"     => ":22060:tboot",
      "FLAVOR"    => "Server-DVD-Incidents-Install",
      "HDD_1"     => "SLES-15-SP3-x86_64-Installtest.qcow2",
      "ISO"       => "SLE-15-SP3-Full-x86_64-GM-Media1.iso",
      "MACHINE"   => "64bit",
      "TEST"      => "qam-incidentinstall",
      "group_id"  => 367,
      "id"        => 4953207,
      "remaining" => 34
    }
  );
  $new_jobs_count = $db->query("select count(id) from openqa_jobs")->hash->{count};
  is($new_jobs_count, $jobs_count + 1, "new job is created");
};

done_testing();

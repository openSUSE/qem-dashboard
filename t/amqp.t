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

use Test::More;
use Test::Mojo;
use Dashboard::Test;
use Mojo::JSON qw(false true);

plan skip_all => 'set TEST_ONLINE to enable this test' unless $ENV{TEST_ONLINE};

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'amqp_test');
my $config         = $dashboard_test->default_config;
my $t              = Test::Mojo->new(Dashboard => $config);
$dashboard_test->minimal_fixtures($t->app);
my $db = $t->app->pg->db;

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

done_testing();

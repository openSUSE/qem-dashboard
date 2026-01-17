# Copyright SUSE LLC
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
use Test::Output 'stderr_like';
use Test::Warnings ':report_warnings';
use Dashboard::Test;
use Mojo::JSON qw(false true);

plan skip_all => 'set TEST_ONLINE to enable this test' unless $ENV{TEST_ONLINE};

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'amqp_test');
my $config         = $dashboard_test->default_config;
my $t              = Test::Mojo->new(Dashboard => $config);
$dashboard_test->minimal_fixtures($t->app);
my $db     = $t->app->pg->db;
my $job_id = 11;

sub _is_field ($field, $expected) {
  is($db->query("SELECT $field FROM openqa_jobs WHERE id = $job_id")->hash->{$field}, $expected);
}

sub _is_count ($expected) {
  is($db->query("SELECT COUNT(*) FROM openqa_jobs WHERE id = $job_id")->hash->{count}, $expected);
}

sub _set_default() {
  $db->query("UPDATE openqa_jobs SET status = 'waiting', job_id = 4953203 WHERE id = $job_id");
}

my $msg = {
  "ARCH"    => "x86_64",
  "BUILD"   => "721304-Bogdan.Lezhepekov_branch_mr_4",
  "FLAVOR"  => "qemu",
  "HDD_1"   => "carwos-Bogdan.Lezhepekov_branch_mr_4-721304.qcow2",
  "MACHINE" => "64bit",
  "TEST"    => "carwos-futex-performance",
  "id"      => 4953203,
};

subtest 'Handle done job' => sub {
  _set_default();
  stderr_like {
    $t->app->amqp->handle(
      'suse.openqa.job.done',
      {
        %$msg,
        "bugref"    => undef,
        "group_id"  => 54,
        "newbuild"  => undef,
        "reason"    => undef,
        "remaining" => 0,
        "result"    => "user_cancelled"
      }
    )
  }
  qr/\[i\].*stopped/, 'amqp log message';
  _is_field('status', 'stopped');
};

subtest 'Handle cancel job' => sub {
  _set_default();
  stderr_like {
    $t->app->amqp->handle('suse.openqa.job.cancel', {%$msg, "group_id" => 328, "remaining" => 0})
  }
  qr/\[i\].*stopped/, 'amqp log message';
  _is_field('status', 'stopped');
};

subtest 'Handle restart job' => sub {
  _set_default();
  stderr_like {
    $t->app->amqp->handle('suse.openqa.job.restart',
      {%$msg, "auto" => 0, "bugref" => undef, "group_id" => 328, "remaining" => 1, "result" => {"4953203" => 7764022}})
  }
  qr/\[i\].*restart/, 'amqp log message';
  _is_field('status', 'waiting');
  _is_field('job_id', 7764022);
};

subtest 'Handle delete job' => sub {
  _set_default();
  _is_count(1);
  stderr_like {
    $t->app->amqp->handle('suse.openqa.job.delete', {%$msg, "group_id" => 328, "remaining" => 1,})
  }
  qr/\[i\].*delete/, 'amqp log message';
  _is_count(0);
};

done_testing();

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
use Mojo::JSON qw(false true);

plan skip_all => 'set TEST_ONLINE to enable this test' unless $ENV{TEST_ONLINE};

local $ENV{MOJO_MODE} = 'production';
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
  my %results = (
    %$msg,
    "bugref"    => undef,
    "group_id"  => 54,
    "newbuild"  => undef,
    "reason"    => undef,
    "remaining" => 0,
    "result"    => "passed"
  );
  my $test = sub ($topic, $regex, $status, $label) {
    stderr_like { $t->app->amqp->handle($topic, \%results) } $regex, $label;
    _is_field('status', $status);
  };

  is $t->app->amqp->handle('suse.openqa.jobs.done', \%results), undef,
    'return early because of wrong object in the topic format';
  subtest 'should return status passed' => sub {
    $test->('suse.openqa.job.done', qr/passed.*job_update/, 'passed', 'return status passed');
    $results{result} = 'softfailed';
    $test->('suse.openqa.job.done', qr/passed.*job_update/, 'passed', 'softfailed return status passed');
  };

  subtest 'should return status waiting' => sub {
    $results{result} = 'none';
    $test->('suse.openqa.job.done', qr/waiting.*job_update/, 'waiting', 'result none return status waiting');
  };

  subtest 'should return status stopped' => sub {
    my @amqp_result
      = qw(timeout_exceeded incomplete obsoleted parallel_failed skipped parallel_restarted user_cancelled user_restarted);
    for my $result (@amqp_result) {
      $results{result} = $result;
      $test->('suse.openqa.job.done', qr/$result.*job_update/, 'stopped', "result $result return status stopped");
    }
  };

  subtest 'should return status failed' => sub {
    $results{result} = 'failed';
    $test->('suse.openqa.job.done', qr/failed.*job_update/, 'failed', "result failed return status failed");
  };
};

subtest 'Handle cancel job' => sub {
  _set_default();
  my %results = (%$msg, "group_id" => 328, "remaining" => 0);
  stderr_like { $t->app->amqp->handle('suse.openqa.job.cancel', \%results) }
  qr/user_cancelled.*job_update/, 'amqp log message';
  _is_field('status', 'stopped');
};

subtest 'Handle restart job' => sub {
  _set_default();
  my %results
    = (%$msg, "auto" => 0, "bugref" => undef, "group_id" => 328, "remaining" => 1, "result" => {"4953203" => 7764022});
  stderr_like { $t->app->amqp->handle('suse.openqa.job.restart', \%results) }
  qr/job_restart/, 'amqp log message';
  _is_field('status', 'waiting');
  _is_field('job_id', 7764022);
};

subtest 'Handle delete job' => sub {
  _set_default();
  _is_count(1);
  my %results = (%$msg, "group_id" => 328, "remaining" => 1);
  stderr_like { $t->app->amqp->handle('suse.openqa.job.delete', \%results) }
  qr/job_delete/, 'amqp log message';
  _is_count(0);
};

subtest 'Handle missing data' => sub {
  is $t->app->amqp->handle('suse.openqa.job.done', {id => 123}), undef, 'returns early with missing arguments';
};

subtest 'Unknown type' => sub {
  $t->app->amqp->handle('suse.openqa.job.unknown', {id => 123});
  ok 1, 'handles unknown job type gracefully';
};

done_testing();

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

package Dashboard::Model::Jobs;
use Mojo::Base -base, -signatures;

has [qw(pg log openqa)];

sub add ($self, $job) {
  my $db = $self->pg->db;
  $db->query(
    'INSERT INTO openqa_jobs (incident_settings, update_settings, name, job_group, job_id, group_id, status, distri,
      flavor, version, arch, build) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT (distri, flavor, arch, version, build, name)
     DO UPDATE SET job_group = EXCLUDED.job_group, job_id = EXCLUDED.job_id, group_id = EXCLUDED.group_id,
       status = EXCLUDED.status, updated = NOW()', $job->{incident_settings}, $job->{update_settings}, $job->{name},
    $job->{job_group}, $job->{job_id}, $job->{group_id}, $job->{status}, $job->{distri}, $job->{flavor},
    $job->{version},   $job->{arch},   $job->{build}
  );
}

sub delete_job ($self, $id) {
  $self->pg->db('DELETE from openqa_jobs where job_id=?', $id);
}

# called from startup in AMQP watcher to catch up with jobs started/ended while the watcher wasn't alive
sub fetch_old ($self) {
  my $db = $self->pg->db;
  my $id = $db->query("SELECT min(job_id) from openqa_jobs where status='waiting'")->hash->{min};
  if (!$id) {
    $id = $db->query("SELECT max(job_id) from openqa_jobs")->hash->{max};
    $self->log->debug("Newest known job: $id");
  }
  else {
    $self->log->debug("Oldest job waiting: $id");
  }

  # passing $self to avoid cyclic dependencies between models
  $self->openqa->fetch_old_chunk($id, $self);
}

sub get ($self, $job_id) {
  return $self->pg->db->query(
    'SELECT incident_settings, update_settings, name, job_group, job_id, group_id, status, distri, flavor, version,
       arch, build
     FROM openqa_jobs where job_id = ? LIMIT 1', $job_id
  )->hash;
}

sub get_incident_settings ($self, $incident_settings) {
  return $self->pg->db->query(
    'SELECT incident_settings, update_settings, name, job_group, job_id, group_id, status, distri, flavor, version,
       arch, build
     FROM openqa_jobs where incident_settings = ?', $incident_settings
  )->hashes->to_array;
}

sub get_update_settings ($self, $update_settings) {
  return $self->pg->db->query(
    'SELECT incident_settings, update_settings, name, job_group, job_id, group_id, status, distri, flavor, version,
       arch, build
     FROM openqa_jobs where update_settings = ?', $update_settings
  )->hashes->to_array;
}

sub latest_update ($self) {
  return undef
    unless my $array
    = $self->pg->db->query('SELECT EXTRACT(EPOCH FROM updated) FROM openqa_jobs ORDER BY updated DESC LIMIT 1')->array;
  return $array->[0];
}

sub update_result ($self, $id, $result) {
  my $normalized = _normalize_result($result);

  return unless my $res = $self->pg->db->query(
    'UPDATE openqa_jobs
     SET status = ?, updated = NOW()
     WHERE job_id = ?
     RETURNING job_id', $normalized, $id
  )->hash;
  $self->log->info("$id: $normalized ($result)");
}

# Found on openQA or AMQP
sub update_or_insert_job ($self, $job_hash) {
  my $db = $self->pg->db;

  # we only care for jobs in a group
  return unless $job_hash->{group_id};

  my $db_job = $db->query("select * from openqa_jobs where job_id=?", $job_hash->{id})->hash;

  # if the job is already done, don't bother with querying the settings
  return if ($db_job && ($db_job->{status} ne 'waiting'));

  # ease reading dumps
  delete $job_hash->{modules};
  my $settings        = $job_hash->{settings};
  my $update_settings = $self->_find_settings('update_openqa_settings', $settings);
  my $incident_settings;
  if (!$update_settings) {
    $incident_settings = $self->_find_settings('incident_openqa_settings', $settings);
    return unless $incident_settings;
  }
  if (!$db_job) {
    $self->add(
      {
        update_settings   => $update_settings,
        incident_settings => $incident_settings,
        name              => $job_hash->{name},
        job_group         => $job_hash->{group},
        job_id            => $job_hash->{id},
        group_id          => $job_hash->{group_id},
        status            => 'waiting',
        distri            => $settings->{DISTRI},
        flavor            => $settings->{FLAVOR},
        version           => $settings->{VERSION},
        arch              => $settings->{ARCH},
        build             => $settings->{BUILD}
      }
    );
  }
  $self->update_result($job_hash->{id}, $job_hash->{result});
}

# if we get a restart event from AMQP, we ignore the old IDs and wait for the new jobs to finish
sub restart_job ($self, $old_id, $new_id) {
  $self->log->info("restart $old_id -> $new_id");
  $self->pg->db->query("UPDATE openqa_jobs set job_id=?, status='waiting' where job_id=?", $new_id, $old_id);
}

sub _find_settings ($self, $table_name, $settings) {
  my $row = $self->pg->db->query(
    "select * from $table_name where
                        settings->>'BUILD' = ? and
                        settings->>'FLAVOR' = ? and
                        settings->>'ARCH' = ? and
                        settings->>'DISTRI' = ? and
                        settings->>'VERSION' = ? and
                        settings->>'REPOHASH' = ? limit 1", $settings->{BUILD}, $settings->{FLAVOR}, $settings->{ARCH},
    $settings->{DISTRI}, $settings->{VERSION}, $settings->{REPOHASH}
  )->hash;
  return undef unless $row;
  return $row->{id};
}

sub _normalize_result ($result) {
  return 'passed'  if $result eq 'passed' || $result eq 'softfailed';
  return 'waiting' if $result eq 'none';
  return 'stopped'
    if grep { $result eq $_ }
    qw(timeout_exceeded incomplete obsoleted parallel_failed skipped parallel_restarted user_cancelled user_restarted);
  return 'failed' if $result eq 'failed';
  return 'failed';
}

1;

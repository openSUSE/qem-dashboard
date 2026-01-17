# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Model::Jobs;
use Mojo::Base -base, -signatures;

has [qw(days_to_keep_aggregates pg log)];

sub add ($self, $job) {
  my $new_job_id = $job->{job_id};
  my $res        = $self->pg->db->query(
    'INSERT INTO openqa_jobs (incident_settings, update_settings, name, job_group, job_id, group_id, status, distri,
      flavor, version, arch, build) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT (distri, flavor, arch, version, build, name)
     DO UPDATE SET job_group = EXCLUDED.job_group, job_id = EXCLUDED.job_id, group_id = EXCLUDED.group_id,
       status = EXCLUDED.status, updated = NOW()
     RETURNING
       id,
       (CASE WHEN (xmax = 0) THEN NULL ELSE (SELECT prev.job_id from openqa_jobs AS prev WHERE prev.id = openqa_jobs.id LIMIT 1)
       END) AS old_job_id', $job->{incident_settings}, $job->{update_settings}, $job->{name}, $job->{job_group},
    $new_job_id, $job->{group_id}, $job->{status}, $job->{distri}, $job->{flavor}, $job->{version}, $job->{arch},
    $job->{build}
  )->hash;
  my $internal_id = $res->{id};
  my $old_job_id  = $res->{old_job_id};
  $self->remove_remarks($internal_id) if defined($old_job_id) && ($old_job_id != $new_job_id);
  return $internal_id;
}

sub internal_job_id ($self, $openqa_job_id) {
  return undef
    unless my $res = $self->pg->db->query('SELECT id FROM openqa_jobs where job_id = ? LIMIT 1', $openqa_job_id)->array;
  return $res->[0];
}

sub remarks ($self, $job_id) {
  return $self->pg->db->query('SELECT incident_id, text FROM job_remarks where openqa_job_id = ? ORDER BY incident_id',
    $job_id)->hashes;
}

sub add_remark ($self, $job_id, $incident_id, $text) {
  $self->pg->db->query(
    'INSERT INTO job_remarks (openqa_job_id, incident_id, text) VALUES (?, ?, ?)
     ON CONFLICT (openqa_job_id, incident_id)
     DO UPDATE SET text = EXCLUDED.text
     RETURNING id', $job_id, $incident_id, $text
  )->array->[0];
}

sub remove_remarks ($self, $job_id) {
  $self->pg->db->query('DELETE FROM job_remarks WHERE openqa_job_id = ?', $job_id);
}

# Disabled to test without cleanup in production
#sub cleanup_aggregates ($self) {
#  $self->pg->db->query(
#    q{DELETE FROM update_openqa_settings
#      WHERE id IN (
#        SELECT update_settings FROM (
#          SELECT update_settings, MAX(updated) AS max_updated FROM openqa_jobs
#          WHERE update_settings IS NOT NULL
#          GROUP BY update_settings
#        ) AS jobs WHERE max_updated < NOW() - INTERVAL '1 days' * ?
#      )}, $self->days_to_keep_aggregates
#  );
#}

sub get ($self, $job_id) {
  return $self->pg->db->query(
    'SELECT incident_settings, update_settings, name, job_group, job_id, group_id, status, distri, flavor, version,
       arch, build, obsolete
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
     FROM openqa_jobs
     WHERE update_settings = ?', $update_settings
  )->hashes->to_array;
}

sub latest_update ($self) {
  return undef
    unless my $array
    = $self->pg->db->query('SELECT EXTRACT(EPOCH FROM updated) FROM openqa_jobs ORDER BY updated DESC LIMIT 1')->array;
  return $array->[0];
}

sub modify ($self, $job_id, $job_data) {
  $self->pg->db->query('UPDATE openqa_jobs SET obsolete = coalesce(?, obsolete) WHERE job_id = ?',
    $job_data->{obsolete}, $job_id);
}

sub update_result ($self, $id, $result) {
  my $normalized = _normalize_result($result);

  return unless my $res = $self->pg->db->query(
    'UPDATE openqa_jobs
     SET status = ?, updated = NOW()
     WHERE job_id = ?
     RETURNING job_id', $normalized, $id
  )->hash;
  $self->_log(info => {job_id => $id, status => $normalized, original_result => $result, type => 'job_update'});
}

sub restart_job ($self, $old_id, $new_id) {
  $self->_log(info => {old_job_id => $old_id, new_job_id => $new_id, type => 'job_restart'});
  $self->pg->db->query("UPDATE openqa_jobs set job_id=?, status='waiting' where job_id=?", $new_id, $old_id);
}

sub delete_job ($self, $id) {
  $self->_log(info => {job_id => $id, type => 'job_delete'});
  $self->pg->db->query("DELETE FROM openqa_jobs WHERE job_id=?", $id);
}

sub _log ($self, $level, $data) {
  $self->log->$level(Mojo::JSON::encode_json($data));
}

sub _normalize_result ($result) {
  return 'passed'  if $result eq 'passed' || $result eq 'softfailed';
  return 'waiting' if $result eq 'none';
  return 'stopped'
    if grep { $result eq $_ }
    qw(timeout_exceeded incomplete obsoleted parallel_failed skipped parallel_restarted user_cancelled user_restarted);
  return 'failed';
}

1;

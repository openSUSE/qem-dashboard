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

package Dashboard::Model::AMQP;
use Mojo::Base -base, -signatures;

has [qw(log jobs)];

# called from startup in AMQP watcher to catch up with jobs started/ended while the watcher wasn't alive
sub fetch_old ($self) {
  my $db = $self->pg->db;
  my $id = $db->query("SELECT min(job_id) from openqa_jobs where status='waiting'")->hash->{min};
  if (!$id) {
    $id = $db->query("SELECT max(job_id) from openqa_jobs")->hash->{max};
  }
  $self->_fetch_old_chunk($id);
}

sub process_event ($self, $key, $data) {
  my (undef, undef, $object, $type) = split(/\./, $key);
  return unless $object ne 'jobs';
  $self->log->debug("HANDLE $key " . Mojo::Util::dumper($data));
  if ($type eq 'done') {
    $self->jobs->update_result($data->{id}, $data->{result});
  }
  elsif ($type eq 'cancel') {
    $self->jobs->update_result($data->{id}, 'user_cancelled');
  }
  elsif ($type eq 'delete') {
    $self->jobs->delete_job($data->{id});
  }
  elsif ($type eq 'restart') {
    my $restart_map = $data->{result};
    for my $old_id (keys %$restart_map) {
      $self->jobs->restart_job($old_id, $restart_map->{$old_id});
    }
  }
  elsif ($type eq 'create') {
    my $data = $self->jobs->openqa->details($data->{id});
    $self->log->debug("CREATED JOB " . Mojo::Util::dumper($data));
    $self->jobs->update_or_insert_job($data);
  }
  else {
    $self->log->debug("Unhandled event $key " . Mojo::Util::dumper($data));
  }
}

1;

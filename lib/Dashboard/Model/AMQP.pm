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

package Dashboard::Model::AMQP;
use Mojo::Base -base, -signatures;

has [qw(log jobs)];

sub handle ($self, $key, $data) {
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
}

1;

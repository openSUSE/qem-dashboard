# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

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

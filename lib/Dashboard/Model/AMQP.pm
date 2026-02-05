# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Model::AMQP;
use Mojo::Base -base, -signatures;

has [qw(log jobs)];

sub handle ($self, $key, $data) {
  my (undef, undef, $object, $type) = split(/\./, $key);
  return unless $object eq 'job';
  $self->log->debug("HANDLE $key " . Mojo::Util::dumper($data));
  if ($type eq 'done') {
    return unless (defined $data->{id} && defined $data->{result});
    $self->jobs->update_result($data->{id}, $data->{result});
  }
  elsif ($type eq 'cancel') {
    return unless defined $data->{id};
    $self->jobs->update_result($data->{id}, 'user_cancelled');
  }
  elsif ($type eq 'delete') {
    return unless defined $data->{id};
    $self->jobs->delete_job($data->{id});
  }
  elsif ($type eq 'restart') {
    return unless defined $data->{result};
    my $restart_map = $data->{result};
    for my $old_id (keys %$restart_map) {
      $self->jobs->restart_job($old_id, $restart_map->{$old_id});
    }
  }
}

1;

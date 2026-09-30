# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Controller::API::Incidents;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Mojo::JSON qw(true false);

sub sync ($self) {
  $self = $self->openapi->valid_input or return;
  my $incidents = $self->req->json;
  $self->incidents->sync($incidents, $self->every_param('type'));

  # Disabled to test without cleanup in production
  #$self->jobs->cleanup_aggregates;

  $self->render(json => {message => 'Ok'});
}

sub list ($self) {
  $self = $self->openapi->valid_input or return;    # uncoverable branch true
  $self->render(json => _fix_booleans($self->incidents->find));
}

sub show ($self) {
  $self = $self->openapi->valid_input or return;
  return unless my $incident = $self->_find_one;
  $self->render(json => _fix_booleans([$incident])->[0]);
}

sub update ($self) {
  $self = $self->openapi->valid_input or return;
  my $incident = $self->req->json;
  $self->incidents->update($incident);
  $self->render(json => {message => 'Ok'});
}

sub update_rejection_reason ($self) {
  $self = $self->openapi->valid_input or return;
  return unless my $incident = $self->_find_one;
  my $incident_id = $self->incidents->ids_for($incident)->[0];

  my $payload = $self->req->json;
  $self->incidents->update_rejection_reason($incident_id, $payload->{rejection_reason});

  $self->render(json => {message => 'Ok'});
}

# Only active incidents can be found, type is optional and required only to tell apart incidents with the same number
# in one project
sub _find_one ($self) {
  my ($number, $project) = ($self->param('incident'), $self->param('project'));
  my $incidents = $self->incidents->find({number => $number, project => $project, type => $self->param('type')});
  return $incidents->[0] if @$incidents == 1;

  if (@$incidents) {
    $self->render(
      json   => {error => "Incident ($number) is ambiguous in project ($project), type is required"},
      status => 400
    );
  }
  else { $self->render(json => {error => 'Incident not found'}, status => 404) }
  return undef;
}

sub _fix_booleans ($incidents) {
  for my $incident (@$incidents) {
    for my $field (qw(approved emu isActive inReview inReviewQAM embargoed)) {
      $incident->{$field} = $incident->{$field} ? true : false;
    }
  }

  return $incidents;
}

1;

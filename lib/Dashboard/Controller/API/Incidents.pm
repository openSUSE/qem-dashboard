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
  my $number   = $self->param('incident');
  my $incident = $self->incidents->incident_for_number($number);
  return $self->render(json => {error => 'Incident not found'}, status => 404) unless $incident;

  $incident->{channels} = $self->incidents->channels_for_incident($incident->{id});
  delete $incident->{id};
  ($incident) = @{_fix_booleans([$incident])};
  $self->render(json => $incident);
}

sub update ($self) {
  $self = $self->openapi->valid_input or return;
  my $incident = $self->req->json;
  $self->incidents->update($incident);
  $self->render(json => {message => 'Ok'});
}

sub update_rejection_reason ($self) {
  $self = $self->openapi->valid_input or return;
  my $incident_number = $self->param('incident');

  return $self->render(json => {error => 'Incident not found'}, status => 404)
    unless $self->incidents->find({number => $incident_number})->[0];

  my $payload = $self->req->json;
  $self->incidents->update_rejection_reason($incident_number, $payload->{rejection_reason});

  $self->render(json => {message => 'Ok'});
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

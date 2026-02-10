# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Controller::API::Incidents;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Mojo::JSON qw(true false);

sub sync ($self) {
  if ($self->stash('openapi.path')) {
    return unless $self->openapi->valid_input;
  }
  else {
    return $self->render(json => {error => 'Incidents in JSON format required'}, status => 400)
      unless my $incidents = $self->req->json;

    my $jv     = $self->schema({type => 'array', items => [$self->schema('incident')->schema->data]});
    my @errors = $jv->validate($incidents);
    return $self->render(json => {error => "Incidents do not match the JSON schema: @errors"}, status => 400)
      if @errors;
  }

  my $incidents = $self->req->json;
  $self->incidents->sync($incidents, $self->every_param('type'));

  # Disabled to test without cleanup in production
  #$self->jobs->cleanup_aggregates;

  $self->render(json => {message => 'Ok'});
}

sub list ($self) {
  return unless !$self->stash('openapi.path') || $self->openapi->valid_input;
  $self->render(json => _fix_booleans($self->incidents->find));
}

sub show ($self) {
  return unless !$self->stash('openapi.path') || $self->openapi->valid_input;
  return $self->render(json => {error => 'Incident not found'}, status => 404)
    unless my $incident = _fix_booleans($self->incidents->find({number => $self->param('incident')}))->[0];
  $self->render(json => $incident);
}

sub update ($self) {
  if ($self->stash('openapi.path')) {
    return unless $self->openapi->valid_input;
  }
  else {
    return $self->render(json => {error => 'Incident in JSON format required'}, status => 400)
      unless my $incident = $self->req->json;

    my $jv     = $self->schema('incident');
    my @errors = $jv->validate($incident);
    return $self->render(json => {error => "Incident does not match the JSON schema: @errors"}, status => 400)
      if @errors;
  }

  my $incident = $self->req->json;
  $self->incidents->update($incident);
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

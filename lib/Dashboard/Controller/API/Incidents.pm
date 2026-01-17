# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Controller::API::Incidents;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Mojo::JSON qw(true false);

my $INCIDENT_SPEC = {
  type     => 'object',
  required => [
    'number',      'project',  'packages', 'channels', 'rr_number', 'inReview',
    'inReviewQAM', 'approved', 'emu',      'isActive', 'embargoed'
  ],
  properties => {
    number      => {type  => 'integer', minimum => 1},
    project     => {type  => 'string'},
    packages    => {type  => 'array', minItems => 1, items => [{type => 'string'}]},
    channels    => {type  => 'array', items    => [{type => 'string'}]},
    rr_number   => {anyOf => [{type => 'integer', minimum => 1}, {type => 'null'}]},
    inReview    => {type  => 'boolean'},
    inReviewQAM => {type  => 'boolean'},
    approved    => {type  => 'boolean'},
    emu         => {type  => 'boolean'},
    isActive    => {type  => 'boolean'},
    embargoed   => {type  => 'boolean'},
    priority    => {anyOf => [{type => 'integer'}, {type => 'null'}]},
    scminfo     => {type  => 'string'},
    url         => {type  => 'string'},
    type        => {type  => 'string'},
  }
};

sub sync ($self) {
  return $self->render(json => {error => 'Incidents in JSON format required'}, status => 400)
    unless my $incidents = $self->req->json;

  my $jv     = $self->schema({type => 'array', items => [$INCIDENT_SPEC]});
  my @errors = $jv->validate($incidents);
  return $self->render(json => {error => "Incidents do not match the JSON schema: @errors"}, status => 400) if @errors;

  $self->incidents->sync($incidents, $self->every_param('type'));

  # Disabled to test without cleanup in production
  #$self->jobs->cleanup_aggregates;

  $self->render(json => {message => 'Ok'});
}

sub list ($self) { $self->render(json => _fix_booleans($self->incidents->find)) }

sub show ($self) {
  return $self->render(json => {error => 'Incident not found'}, status => 404)
    unless my $incident = _fix_booleans($self->incidents->find({number => $self->param('incident')}))->[0];
  $self->render(json => $incident);
}

sub update ($self) {
  return $self->render(json => {error => 'Incident in JSON format required'}, status => 400)
    unless my $incident = $self->req->json;

  my $jv     = $self->schema($INCIDENT_SPEC);
  my @errors = $jv->validate($incident);
  return $self->render(json => {error => "Incident does not match the JSON schema: @errors"}, status => 400) if @errors;

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

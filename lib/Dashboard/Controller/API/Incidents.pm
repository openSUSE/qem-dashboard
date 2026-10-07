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
  my $number = $self->param('incident');
  return unless my $id = $self->resolve_incident_id($number);
  my $incident = $self->incidents->key_for_id($id);
  $incident = $self->pg->db->query('select * from incidents where id = ?', $id)->hash;
  $incident = $self->incidents->_map($incident);

  $incident->{channels} = $self->incidents->channels_for_incident($id);
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

  return unless my $id = $self->resolve_incident_id($incident_number);

  my $payload = $self->req->json;
  $self->incidents->update_rejection_reason_by_id($id, $payload->{rejection_reason});

  $self->render(json => {message => 'Ok'});
}

sub list_submissions ($self) {
  $self = $self->openapi->valid_input or return;    # uncoverable branch true
  $self->render(json => _fix_booleans($self->incidents->find));
}

sub sync_submissions ($self) {
  $self = $self->openapi->valid_input or return;
  my $submissions = $self->req->json;
  $self->incidents->sync($submissions, $self->every_param('type'));
  $self->render(json => {message => 'Ok'});
}

sub show_submission ($self) {
  $self = $self->openapi->valid_input or return;
  my $submission
    = $self->incidents->submission_for($self->param('submission'), $self->param('project'), $self->param('type'));
  return $self->render(json => {error => 'Submission not found'}, status => 404) unless $submission;

  $submission->{channels} = $self->incidents->channels_for_incident($submission->{id});
  delete $submission->{id};
  ($submission) = @{_fix_booleans([$submission])};
  $self->render(json => $submission);
}

sub update_submission ($self) {
  $self = $self->openapi->valid_input or return;
  my $submission = $self->req->json;
  $self->incidents->update($submission);
  $self->render(json => {message => 'Ok'});
}

sub update_submission_rejection_reason ($self) {
  $self = $self->openapi->valid_input or return;
  return
    unless my $id
    = $self->resolve_submission_id($self->param('submission'), $self->param('project'), $self->param('type'));

  my $payload = $self->req->json;
  $self->incidents->update_rejection_reason_by_id($id, $payload->{rejection_reason});

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

# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Controller::API::Jobs;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub add ($self) {
  if ($self->stash('openapi.path')) {
    return unless $self->openapi->valid_input;
  }
  else {
    return $self->render(json => {error => 'Job in JSON format required'}, status => 400)
      unless my $job = $self->req->json;

    my $jv     = $self->schema('job');
    my @errors = $jv->validate($job);
    return $self->render(json => {error => "Job does not match the JSON schema: @errors"}, status => 400) if @errors;
  }

  my $job   = $self->req->json;
  my $is_id = $job->{incident_settings};
  my $us_id = $job->{update_settings};
  return $self->render(json => {error => "Job needs to reference incident settings or update settings"}, status => 400)
    unless $is_id || $us_id;

  # Validate references to catch user errors
  if ($is_id) {
    return $self->render(json => {error => "Referenced incident settings ($is_id) do not exist"}, status => 400)
      unless $self->settings->incident_settings_exist($is_id);
  }
  if ($us_id) {
    return $self->render(json => {error => "Referenced update settings ($us_id) do not exist"}, status => 400)
      unless $self->settings->update_settings_exist($us_id);
  }

  $self->jobs->add($job);
  $self->render(json => {message => 'Ok'});
}

sub incidents ($self) {
  return unless !$self->stash('openapi.path') || $self->openapi->valid_input;
  my $job = $self->jobs->get_incident_settings($self->param('incident_settings'));
  $self->render(json => $job);
}

sub modify ($self) {
  if ($self->stash('openapi.path')) {
    return unless $self->openapi->valid_input;
  }
  else {
    return $self->render(json => {error => 'Job in JSON format required'}, status => 400)
      unless my $job_data = $self->req->json;

    my $jv     = $self->schema({type => 'object', properties => {obsolete => {type => 'boolean'}}});
    my @errors = $jv->validate($job_data);
    return $self->render(json => {error => "Job does not match the JSON schema: @errors"}, status => 400) if @errors;
  }

  my $job_id   = $self->param('job_id');
  my $job_data = $self->req->json;
  $self->jobs->modify($job_id, $job_data);
  $self->render(json => {message => 'Ok'});
}

sub _incident ($incidents, $remark) {
  return undef unless my $incident_id = $remark->{incident_id};
  return $incidents->number_for_id($incident_id);
}

sub show_remarks ($self) {
  return unless !$self->stash('openapi.path') || $self->openapi->valid_input;
  my $openqa_job_id   = $self->param('job_id');
  my $internal_job_id = $self->jobs->internal_job_id($openqa_job_id);
  return $self->render(json => {error => "openQA job ($openqa_job_id) does not exist"}, status => 404)
    unless $internal_job_id;

  my $incidents = $self->app->incidents;
  my $remarks   = $self->jobs->remarks($internal_job_id);
  my $res       = {remarks => [map { {text => $_->{text}, incident => _incident($incidents, $_)} } $remarks->each]};
  $self->render(json => $res);
}

sub update_remark ($self) {
  return unless !$self->stash('openapi.path') || $self->openapi->valid_input;
  my $incident_number = $self->param('incident_number');
  my $incident_id     = defined $incident_number ? $self->app->incidents->id_for_number($incident_number) : undef;
  my $openqa_job_id   = $self->param('job_id');
  my $internal_job_id = $self->jobs->internal_job_id($openqa_job_id);
  return $self->render(json => {error => "openQA job ($openqa_job_id) does not exist"}, status => 404)
    unless $internal_job_id;
  return $self->render(json => {error => "Incident ($incident_number) does not exist"}, status => 404)
    if defined $incident_number && !$incident_id;

  $self->jobs->add_remark($internal_job_id, $incident_id, $self->param('text'));
  $self->render(json => {message => 'Ok'});
}

sub show ($self) {
  return unless !$self->stash('openapi.path') || $self->openapi->valid_input;
  return $self->render(json => {error => 'Job not found'}, status => 400)
    unless my $job = $self->jobs->get($self->param('job_id'));
  $self->render(json => $job);
}

sub updates ($self) {
  return unless !$self->stash('openapi.path') || $self->openapi->valid_input;
  my $job = $self->jobs->get_update_settings($self->param('update_settings'));
  $self->render(json => $job);
}

1;

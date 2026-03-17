# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Controller::API::Jobs;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub add ($self) {
  $self = $self->openapi->valid_input or return;
  my $job = $self->req->json;

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
  $self = $self->openapi->valid_input or return;
  my $job = $self->jobs->get_incident_settings($self->param('incident_settings'));
  $self->render(json => $job);
}

sub modify ($self) {
  $self = $self->openapi->valid_input or return;
  my $job_id = $self->param('job_id');

  my $job_data = $self->req->json;
  $self->jobs->modify($job_id, $job_data);
  $self->render(json => {message => 'Ok'});
}

sub _incident ($incidents, $remark) {
  return undef unless my $incident_id = $remark->{incident_id};
  return $incidents->number_for_id($incident_id);
}

sub show_remarks ($self) {
  $self = $self->openapi->valid_input or return;
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
  $self = $self->openapi->valid_input or return;
  my $incident_number = $self->param('incident_number');
  my $text            = $self->param('text');

  if (my $json = $self->req->json) {
    $incident_number //= $json->{incident_number};
    $text            //= $json->{text};
  }

  return $self->render(json => {error => "Missing remark text"}, status => 400) unless defined $text;

  my $incident_id     = defined $incident_number ? $self->app->incidents->id_for_number($incident_number) : undef;
  my $openqa_job_id   = $self->param('job_id');
  my $internal_job_id = $self->jobs->internal_job_id($openqa_job_id);
  return $self->render(json => {error => "openQA job ($openqa_job_id) does not exist"}, status => 404)
    unless $internal_job_id;
  return $self->render(json => {error => "Incident ($incident_number) does not exist"}, status => 404)
    if defined $incident_number && !$incident_id;

  $self->jobs->add_remark($internal_job_id, $incident_id, $text);
  $self->render(json => {message => 'Ok'});
}

sub show ($self) {
  $self = $self->openapi->valid_input or return;
  return $self->render(json => {error => 'Job not found'}, status => 400)
    unless my $job = $self->jobs->get($self->param('job_id'));
  $self->render(json => $job);
}

sub updates ($self) {
  $self = $self->openapi->valid_input or return;
  my $job = $self->jobs->get_update_settings($self->param('update_settings'));
  $self->render(json => $job);
}

1;

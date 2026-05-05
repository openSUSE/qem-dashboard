# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Controller::API::Settings;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Mojo::JSON qw(true false);

sub add_incident_settings ($self) {
  $self = $self->openapi->valid_input or return;
  my $settings = $self->req->json;
  return $self->render(json => {error => 'Incident not found'}, status => 400)
    unless my $incident_id = $self->incidents->id_for_number($settings->{incident});

  my $id = $self->settings->add_incident_settings($incident_id, $settings);
  $self->render(json => {message => 'Ok', id => $id});
}

sub add_update_settings ($self) {
  $self = $self->openapi->valid_input or return;
  my $settings = $self->req->json;
  my @incident_ids;
  my $incidents = $self->incidents;
  for my $incident (@{$settings->{incidents}}) {
    return $self->render(json => {error => 'Incident not found'}, status => 400)
      unless my $incident_id = $incidents->id_for_number($incident);
    push @incident_ids, $incident_id;
  }

  my $id = $self->settings->add_update_settings(\@incident_ids, $settings);
  $self->render(json => {message => 'Ok', id => $id});
}

sub get_incident_settings ($self) {
  $self = $self->openapi->valid_input or return;
  return $self->render(json => {error => 'Incident not found'}, status => 400)
    unless my $incident_id = $self->incidents->id_for_number($self->param('incident'));
  $self->render(json => _fix_booleans($self->settings->get_incident_settings($incident_id)));
}

sub get_update_settings ($self) {
  $self = $self->openapi->valid_input or return;
  return $self->render(json => {error => 'Incident not found'}, status => 400)
    unless my $incident_id = $self->incidents->id_for_number($self->param('incident'));
  $self->render(json => $self->settings->get_update_settings($incident_id));
}

sub search_update_settings ($self) {
  $self = $self->openapi->valid_input or return;
  my $product = $self->param('product');
  my $arch    = $self->param('arch');
  my $limit   = $self->param('limit');

  $self->render(json => $self->settings->find_update_settings({product => $product, arch => $arch, limit => $limit}));
}

sub _fix_booleans ($settings) {
  for my $setting (@$settings) {
    $setting->{withAggregate} = $setting->{withAggregate} ? true : false;
  }
  return $settings;
}

1;

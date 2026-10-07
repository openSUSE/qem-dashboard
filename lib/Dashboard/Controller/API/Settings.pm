# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Controller::API::Settings;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Mojo::JSON qw(true false);

sub add_incident_settings ($self) {
  $self = $self->openapi->valid_input or return;
  my $settings = $self->req->json;
  return unless defined(my $incident_id = $self->resolve_incident_id($settings->{incident}));

  my $id = $self->settings->add_incident_settings($incident_id, $settings);
  $self->render(json => {message => 'Ok', id => $id});
}

sub add_submission_settings ($self) {
  $self = $self->openapi->valid_input or return;
  my $settings = $self->req->json;
  return
    unless defined(my $incident_id
      = $self->resolve_submission_id($settings->{incident}, $settings->{project}, $settings->{type}));

  my $id = $self->settings->add_incident_settings($incident_id, $settings);
  $self->render(json => {message => 'Ok', id => $id});
}

sub add_update_settings ($self) {
  $self = $self->openapi->valid_input or return;
  my $settings = $self->req->json;
  my @incident_ids;
  for my $incident (@{$settings->{incidents}}) {
    my $incident_id;
    if (ref $incident eq 'HASH' && $incident->{project} && $incident->{type}) {
      return
        unless defined($incident_id
          = $self->resolve_submission_id($incident->{number}, $incident->{project}, $incident->{type}));
    }
    else {
      my $number = ref $incident eq 'HASH' ? $incident->{number} : $incident;
      return unless defined($incident_id = $self->resolve_incident_id($number));
    }
    push @incident_ids, $incident_id;
  }

  my $id = $self->settings->add_update_settings(\@incident_ids, $settings);
  $self->render(json => {message => 'Ok', id => $id});
}

sub get_incident_settings ($self) {
  $self = $self->openapi->valid_input or return;
  return unless defined(my $incident_id = $self->resolve_incident_id($self->param('incident')));
  $self->render(json => _fix_booleans($self->settings->get_incident_settings($incident_id)));
}

sub get_submission_settings ($self) {
  $self = $self->openapi->valid_input or return;
  return
    unless defined(my $incident_id
      = $self->resolve_submission_id($self->param('submission'), $self->param('project'), $self->param('type')));
  $self->render(json => _fix_booleans($self->settings->get_incident_settings($incident_id)));
}

sub get_update_settings ($self) {
  $self = $self->openapi->valid_input or return;
  return unless defined(my $incident_id = $self->resolve_incident_id($self->param('incident')));
  $self->render(json => $self->settings->get_update_settings($incident_id));
}

sub get_submission_update_settings ($self) {
  $self = $self->openapi->valid_input or return;
  return
    unless defined(my $incident_id
      = $self->resolve_submission_id($self->param('submission'), $self->param('project'), $self->param('type')));
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

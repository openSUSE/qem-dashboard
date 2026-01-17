# Copyright SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package Dashboard::Controller::API::Settings;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Mojo::JSON qw(true false);

sub add_incident_settings ($self) {
  return $self->render(json => {error => 'Incident settings in JSON format required'}, status => 400)
    unless my $settings = $self->req->json;

  my $jv = $self->schema(
    {
      type       => 'object',
      required   => ['incident', 'version', 'flavor', 'arch', 'withAggregate', 'settings'],
      properties => {
        incident      => {type => 'integer', minimum => 1},
        version       => {type => 'string'},
        flavor        => {type => 'string'},
        arch          => {type => 'string'},
        withAggregate => {type => 'boolean'},
        settings      => {type => 'object'}
      }
    }
  );
  my @errors = $jv->validate($settings);
  return $self->render(json => {error => "Incident settings do not match the JSON schema: @errors"}, status => 400)
    if @errors;

  return $self->render(json => {error => 'Incident not found'}, status => 400)
    unless my $incident_id = $self->incidents->id_for_number($settings->{incident});

  my $id = $self->settings->add_incident_settings($incident_id, $settings);
  $self->render(json => {message => 'Ok', id => $id});
}

sub add_update_settings ($self) {
  return $self->render(json => {error => 'Update settings in JSON format required'}, status => 400)
    unless my $settings = $self->req->json;

  my $jv = $self->schema(
    {
      type       => 'object',
      required   => ['incidents', 'product', 'arch', 'build', 'repohash', 'settings'],
      properties => {
        incident => {type => 'array', minItems => 1, items => [{type => 'integer', minimum => 1}]},
        product  => {type => 'string'},
        arch     => {type => 'string'},
        build    => {type => 'string'},
        repohash => {type => 'string'},
        settings => {type => 'object'}
      }
    }
  );
  my @errors = $jv->validate($settings);
  return $self->render(json => {error => "Update settings do not match the JSON schema: @errors"}, status => 400)
    if @errors;

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
  return $self->render(json => {error => 'Incident not found'}, status => 400)
    unless my $incident_id = $self->incidents->id_for_number($self->param('incident'));
  $self->render(json => _fix_booleans($self->settings->get_incident_settings($incident_id)));
}

sub get_update_settings ($self) {
  return $self->render(json => {error => 'Incident not found'}, status => 400)
    unless my $incident_id = $self->incidents->id_for_number($self->param('incident'));
  $self->render(json => $self->settings->get_update_settings($incident_id));
}

sub search_update_settings ($self) {
  my $validation = $self->validation;
  $validation->required('product');
  $validation->required('arch');
  $validation->optional('limit')->num;
  return $self->reply->json_validation_error if $validation->has_error;

  my $product = $validation->param('product');
  my $arch    = $validation->param('arch');
  my $limit   = $validation->param('limit');

  $self->render(json => $self->settings->find_update_settings({product => $product, arch => $arch, limit => $limit}));
}

sub _fix_booleans ($settings) {
  for my $setting (@$settings) {
    $setting->{withAggregate} = $setting->{withAggregate} ? true : false;
  }
  return $settings;
}

1;

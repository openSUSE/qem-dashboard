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

package Dashboard::Model::Settings;
use Mojo::Base -base, -signatures;

has 'pg';

sub add_incident_settings ($self, $incident_id, $settings) {
  my $db = $self->pg->db;

  my $tx = $db->begin;
  $db->query(
    'INSERT INTO incident_openqa_settings (incident, version, flavor, arch, with_aggregate) VALUES (?, ?, ?, ?, ?)
     ON CONFLICT DO NOTHING', $incident_id, $settings->{version}, $settings->{flavor}, $settings->{arch},
    $settings->{withAggregate}
  );
  my $id = $db->query(
    'SELECT id FROM incident_openqa_settings
     WHERE incident = ? AND version = ? AND flavor = ? AND arch = ? LIMIT 1', $incident_id, $settings->{version},
    $settings->{flavor}, $settings->{arch}
  )->hash->{id};
  $db->query('UPDATE incident_openqa_settings SET settings = ? WHERE id = ?', {json => $settings->{settings}}, $id);
  $tx->commit;

  return $id;
}

sub add_update_settings ($self, $incident_ids, $settings) {
  my $db = $self->pg->db;

  my $tx = $db->begin;
  $db->query(
    'INSERT INTO update_openqa_settings (product, arch, build, repohash, settings) VALUES (?, ?, ?, ?, ?)
     ON CONFLICT DO NOTHING', $settings->{product}, $settings->{arch}, $settings->{build}, $settings->{repohash},
    {json => $settings->{settings}}
  );
  my $id = $db->query('SELECT id FROM update_openqa_settings WHERE product = ? AND arch = ? AND build = ? LIMIT 1',
    $settings->{product}, $settings->{arch}, $settings->{build})->hash->{id};
  $db->query('INSERT INTO incident_in_update (incident, settings) VALUES (?, ?)', $_, $id) for @$incident_ids;
  $tx->commit;

  return $id;
}

sub find_update_settings ($self, $options) {
  return $self->pg->db->query(
    'SELECT ios.id as id, ARRAY_AGG(number) AS incidents, product, arch, build, repohash, ios.settings
     FROM update_openqa_settings ios INNER JOIN incident_in_update iiu ON iiu.settings = ios.id
       INNER JOIN incidents i ON i.id = iiu.incident
     WHERE product = ? AND arch = ?
     GROUP BY product, arch, build, repohash, ios.settings, ios.id
     ORDER BY ios.id DESC LIMIT ?', $options->{product}, $options->{arch}, $options->{limit} || 50
  )->expand->hashes->to_array;
}

sub get_incident_settings ($self, $incident_id) {
  return $self->pg->db->query(
    'SELECT ios.id as id, number AS incident, version, flavor, arch, with_aggregate, settings
     FROM incident_openqa_settings ios JOIN incidents i ON ios.incident = i.id
     WHERE i.id = ?
     ORDER BY ios.id DESC', $incident_id
  )->expand->hashes->each(sub { $_->{withAggregate} = delete $_->{with_aggregate} })->to_array;
}

sub get_update_settings ($self, $incident_id) {
  return $self->pg->db->query(
    'SELECT ios.id as id, ARRAY_AGG(number) AS incidents, product, arch, build, repohash, ios.settings
     FROM update_openqa_settings ios INNER JOIN incident_in_update iiu ON iiu.settings = ios.id
       INNER JOIN incidents i ON i.id = iiu.incident
     WHERE i.id = ?
     GROUP BY product, arch, build, repohash, ios.settings, ios.id
     ORDER BY ios.id DESC', $incident_id
  )->expand->hashes->to_array;
}

sub incident_settings_exist ($self, $id) {
  return !!$self->pg->db->query('SELECT id FROM incident_openqa_settings WHERE id = ?', $id)->array;
}

sub update_settings_exist ($self, $id) {
  return !!$self->pg->db->query('SELECT id FROM update_openqa_settings WHERE id = ?', $id)->array;
}

1;

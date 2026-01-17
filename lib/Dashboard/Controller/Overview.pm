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

package Dashboard::Controller::Overview;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub blocked ($self) {
  $self->_render_api_response({blocked => $self->incidents->blocked});
}

sub list ($self) {
  $self->_render_api_response({incidents => $self->incidents->find});
}

sub incident ($self) {
  my $number = $self->param('incident');

  my $incidents = $self->incidents;
  my $incident  = $incidents->incident_for_number($number);
  $self->_render_api_response(
    {
      details => {
        jobs             => $incidents->openqa_summary_only_aggregates($incident),
        incident         => $incident,
        build_nr         => $incidents->build_nr($incident),
        incident_summary => $incidents->openqa_summary_only_incident($incident)
      }
    }
  );
}

sub repos ($self) {
  $self->_render_api_response({repos => $self->incidents->repos});
}

# HTML!
sub index ($self) {
}

sub _render_api_response ($self, $data) {
  my $updated = $self->jobs->latest_update;
  $data->{last_updated} = defined $updated ? int($updated * 1000) : undef;
  return $self->render(json => $data);
}

1;

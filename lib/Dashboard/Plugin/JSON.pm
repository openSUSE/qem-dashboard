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

package Dashboard::Plugin::JSON;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

sub register ($self, $app, $conf) {
  $app->hook(before_render => \&_before_render);
}

sub _before_render ($c, $args) {
  return unless my $template = $args->{template};
  return unless $template eq 'exception' || $template eq 'not_found';
  return unless $c->accepts('json');

  if   ($template eq 'exception') { $args->{json} = {error => 'Unexpected server error'} }
  else                            { $args->{json} = {error => 'Resource not found'} }
}

1;

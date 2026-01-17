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

package Dashboard::Plugin::Helpers;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use JSON::Validator;
use Mojo::ByteStream;
use Mojo::URL;

sub register ($self, $app, $conf) {
  $app->helper('reply.json_validation_error' => \&_json_validation_error);
  $app->helper('openqa_url'                  => sub ($c) { Mojo::URL->new($c->app->config->{openqa}{url}) });
  $app->helper('schema'                      => sub ($c, $schema) { JSON::Validator->new->schema($schema) });
}

sub _json_validation_error ($c) {
  my $failed = join ', ', @{$c->validation->failed};
  $c->render(json => {error => "Invalid request parameters ($failed)"}, status => 400);
}

1;

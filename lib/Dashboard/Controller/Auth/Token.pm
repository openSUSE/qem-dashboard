# Copyright (C) 2020 SUSE LLC
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

package Dashboard::Controller::Auth::Token;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub check ($self) {

  return 1 if $self->req->method eq 'GET';

  my $tokens = $self->app->config('tokens');
  return 1 unless @$tokens;

  $self->_denied and return undef unless my $auth = $self->req->headers->authorization;
  $self->_denied and return undef unless $auth =~ /^Token\ (\S+)$/;
  my $token = $1;

  $self->_denied and return undef unless grep { $token eq $_ } @$tokens;

  return 1;
}

sub _denied ($self) { $self->render(json => {error => 'Permission denied'}, status => 403) }

1;

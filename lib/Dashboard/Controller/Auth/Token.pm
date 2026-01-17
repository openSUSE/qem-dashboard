# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

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

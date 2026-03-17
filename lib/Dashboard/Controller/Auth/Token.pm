# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Controller::Auth::Token;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub check ($self) {

  return 1 if $self->req->method eq 'GET';

  my $tokens = $self->app->config('tokens');
  return 1 unless @$tokens;

  my $auth = $self->req->headers->authorization;
  if (!$auth) {
    $self->_denied;
    return undef;
  }
  if ($auth !~ /^Token\ (\S+)$/) {
    $self->_denied;
    return undef;
  }
  my $token = $1;

  if (!grep { $token eq $_ } @$tokens) {
    $self->_denied;
    return undef;
  }

  return 1;
}

sub _denied ($self) { $self->render(json => {error => 'Permission denied'}, status => 403) }

1;

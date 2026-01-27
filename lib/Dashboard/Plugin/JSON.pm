# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Plugin::JSON;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

sub register ($self, $app, $conf) {
  $app->hook(before_render => \&_before_render);
}

sub _before_render ($c, $args) {
  return unless my $template = $args->{template};
  return unless $template eq 'exception' || $template eq 'not_found';
  return unless $c->accepts('json');

  if ($template eq 'exception') { $args->{json} = {error => 'Unexpected server error'} }

  else { $args->{json} = {error => 'Resource not found'} }
}

1;

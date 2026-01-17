# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

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

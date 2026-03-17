# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Plugin::Helpers;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use JSON::Validator;
use Mojo::ByteStream;
use Mojo::URL;

sub register ($self, $app, $conf) {
  $app->helper('openqa_url' => sub ($c) { Mojo::URL->new($c->app->config->{openqa}{url}) });
  $app->helper(
    'schema' => sub ($c, $schema) {
      my $validator = JSON::Validator->new;
      return $validator->schema($schema) if ref $schema;
      my $path = $c->app->home->child('resources', 'schemas', "$schema.json");
      return $validator->schema($path->to_string);
    }
  );
}

1;

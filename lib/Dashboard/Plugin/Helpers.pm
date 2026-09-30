# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Plugin::Helpers;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use JSON::Validator;
use Mojo::ByteStream;
use Mojo::URL;

sub register ($self, $app, $conf) {
  $app->helper('openqa_url' => sub ($c) { Mojo::URL->new($c->app->config->{openqa}{url}) });

  # Incidents are unique by (number, project, type) but type is optional in requests, renders an error and returns
  # undef unless exactly one incident matches
  $app->helper(
    'incident_id' => sub ($c, $key, %options) {
      my $ids = $c->app->incidents->ids_for($key);
      return $ids->[0] if @$ids == 1;

      if (@$ids) {
        my ($number, $project) = @{$key}{qw(number project)};
        $c->render(
          json   => {error => "Incident ($number) is ambiguous in project ($project), type is required"},
          status => 400
        );
      }
      else {
        $c->render(json => {error => $options{error} // 'Incident not found'}, status => $options{status} // 400);
      }
      return undef;
    }
  );
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

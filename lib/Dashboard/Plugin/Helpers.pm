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
    'resolve_incident_id' => sub ($c, $number) {
      my $ids = $c->app->incidents->ids_for_number($number);
      return $ids->[0] if @$ids == 1;

      if (@$ids) {
        $c->render(
          json   => {error => "Incident ($number) is ambiguous, please migrate to the /submissions API"},
          status => 400
        );
      }
      else {
        $c->render(json => {error => 'Incident not found'}, status => 404);
      }
      return undef;
    }
  );

  $app->helper(
    'resolve_submission_id' => sub ($c, $number, $project, $type) {
      my $id = $c->app->incidents->id_for_submission($number, $project, $type);
      return $id if $id;

      $c->render(json => {error => 'Submission not found'}, status => 404);
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

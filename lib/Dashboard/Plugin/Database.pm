# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Plugin::Database;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Mojo::Pg;

sub register ($self, $app, $config) {
  my $log = $app->log;
  $app->helper(
    pg => sub {
      state $pg      = Mojo::Pg->new($config->{pg})->max_connections(1);
      state $backoff = 0;
      $pg->on(
        connection => sub ($pg, $dbh) {
          $backoff = 0;
        }
      );
      $pg->on(
        error => sub ($pg, $err) {
          $log->error("Database error: $err");
          $backoff = $backoff ? $backoff * 2 : 1;
          $backoff = 60 if $backoff > 60;
          $log->info("Retrying database connection in $backoff seconds");
          Mojo::IOLoop->timer($backoff => sub { $pg->db });
        }
      );
      return $pg;
    }
  );
}

1;

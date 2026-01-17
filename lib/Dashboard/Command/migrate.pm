# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Command::migrate;
use Mojo::Base 'Mojolicious::Command', -signatures;

has description => 'Migrate the database to latest version';
has usage       => sub { shift->extract_usage };

sub run ($self, @args) {

  my $app        = $self->app;
  my $migrations = $app->pg->migrations;
  my $before     = $migrations->active;
  say 'Nothing to do' and return if $before == $migrations->latest;

  $migrations->migrate;
  say "Migrated from $before to " . $migrations->active;
}

1;

=encoding utf8

=head1 NAME

Dashboard::Command::migrate - command to migrate the DB schema

=head1 SYNOPSIS

  Usage: APPLICATION migrate

    script/dashboard migrate

  Options:
    -h, --help   Show this summary of available options

=cut

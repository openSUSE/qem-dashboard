# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Controller::MCP;
use Mojo::Base -base, -signatures;
use MCP::Server;
use Mojo::JSON qw(encode_json);

has 'incidents';
has 'jobs';

sub new ($class, %args) {
  my $self   = $class->SUPER::new(%args);
  my $server = $self->{server} = MCP::Server->new;

  $server->tool(
    name         => 'list_submissions',
    description  => 'List active incidents/submissions.',
    input_schema => {
      type       => 'object',
      properties => {
        number  => {type => 'integer', description => 'Filter by incident number'},
        project => {type => 'string',  description => 'Filter by project'},
        type    => {type => 'string',  description => 'Filter by incident type'}
      }
    },
    code => sub ($tool, $args) {
      my @results;
      for my $incident (@{$self->incidents->find($args)}) {
        my @packages  = @{$incident->{packages} // []};
        my @channels  = grep {defined} @{$incident->{channels} // []};
        my $chan_text = @channels ? join(', ', @channels) : 'N/A';
        push @results,
          sprintf(
          "• **Incident %d**\n  * **Project:** %s\n  * **Type:** %s\n  * **Packages:** %s\n  * **Channels:** %s",
          $incident->{number}  // 0,
          $incident->{project} // '',
          $incident->{type}    // '',
          join(', ', @packages), $chan_text
          );
      }
      return @results ? "```\n" . (join("\n\n", @results)) . "\n```" : "No active incidents found.";
    }
  );

  $server->tool(
    name         => 'get_submission_details',
    description  => 'Get details for a specific submission including openQA results.',
    input_schema => {
      type       => 'object',
      properties => {
        number  => {type => 'integer', description => 'Incident number'},
        project => {type => 'string',  description => 'Project of the incident'},
        type    => {type => 'string',  description => 'Incident type, only needed if the number is ambiguous'}
      },
      required => ['number']
    },
    code => sub ($tool, $args) {
      my $incidents = $self->incidents;
      my $key       = {number => $args->{number}, project => $args->{project}, type => $args->{type}};
      my $ids       = $incidents->ids_for($key);

      unless (@$ids) {
        my $msg = "Error: Incident $args->{number} not found";
        $msg .= " in project $args->{project}" if $args->{project};
        return "```\n$msg\n```";
      }
      if (@$ids > 1) {
        my $msg = "Error: Incident $args->{number} is ambiguous";
        if ($args->{project}) {
          $msg .= " in project $args->{project}, type is required";
        }
        else {
          $msg .= ", project is required";
        }
        return "```\n$msg\n```";
      }
      my $incident = $incidents->incident_for($key);

      my @lines = (
        sprintf("Incident %d Details", $incident->{number} // 0),
        "=" x 40, "",
        sprintf("**Project:** %s", $incident->{project} // ''),
        sprintf("**Type:** %s",    $incident->{type}    // ''),
      );
      my @packages = @{$incident->{packages} // []};
      push @lines, sprintf("**Packages:** %s", join(', ', @packages));
      my @channels  = @{$incidents->channels_for_incident($incident->{id}) // []};
      my $chan_text = @channels ? join(', ', @channels) : 'N/A';
      push @lines, sprintf("**Channels:** %s", $chan_text);
      push @lines, sprintf("**Priority:** %d", $incident->{priority} // 0);
      push @lines, ("", "openQA Summary:", "-" x 40);

      my $jobs = $incidents->openqa_summary_only_aggregates($incident);
      if (%$jobs) {
        for my $build (sort keys %$jobs) {
          for my $job (@{$jobs->{$build}}) {
            push @lines, sprintf("• %s: %s", $job->{name}, $job->{status});
          }
        }
      }
      else {
        push @lines, "No openQA jobs found.";
      }

      return "```\n" . join("\n", @lines) . "\n```";
    }
  );

  $server->tool(
    name        => 'list_blocked',
    description => 'List incidents that are currently blocked.',
    code        => sub ($tool, $args) {
      my $blocked = $self->incidents->blocked;

      return "```\nNo incidents currently blocked.\n```" unless @$blocked;

      my @lines = ("Blocked Incidents:", "=" x 40);
      for my $entry (@$blocked) {
        my $incident = $entry->{incident};
        push @lines,
          sprintf("• **Incident %d** (%s)",
          $incident->{number}, join(' ', grep {length} @{$incident}{qw(project type)}));
        if (my $reasons = $incident->{blocked_reasons}) {
          for my $reason (@$reasons) {
            push @lines, sprintf("  - %s", $reason);
          }
        }
      }
      return "```\n" . join("\n", @lines) . "\n```";
    }
  );

  $server->tool(
    name        => 'get_repo_status',
    description => 'Get status of various repositories/products.',
    code        => sub ($tool, $args) {
      my $repos = $self->incidents->repos;

      return "```\nNo repository information available.\n```" unless %$repos;

      my @lines = ("Repository Status:", "=" x 40);
      for my $repo (sort keys %$repos) {
        my $status = $repos->{$repo};
        push @lines, sprintf("**%s:** %s", $repo, $status);
      }
      return "```\n" . join("\n", @lines) . "\n```";
    }
  );

  return $self;
}

=head2 server

Returns the MCP server instance.

=cut

sub server ($self) { $self->{server} }

1;

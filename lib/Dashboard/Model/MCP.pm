# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Model::MCP;
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
    description  => 'List active incidents/submissions',
    input_schema =>
      {type => 'object', properties => {number => {type => 'integer', description => 'Filter by incident number'}}},
    code => sub ($tool, $args) {
      return encode_json($self->incidents->find($args));
    }
  );

  $server->tool(
    name         => 'get_submission_details',
    description  => 'Get details for a specific submission including openQA results',
    input_schema => {
      type       => 'object',
      properties => {number => {type => 'integer', description => 'Incident number'}},
      required   => ['number']
    },
    code => sub ($tool, $args) {
      my $incidents = $self->incidents;
      my $incident  = $incidents->incident_for_number($args->{number});
      return encode_json({error => "Incident $args->{number} not found"}) unless $incident;

      return encode_json(
        {
          jobs             => $incidents->openqa_summary_only_aggregates($incident),
          incident         => $incident,
          build_nr         => $incidents->build_nr($incident),
          incident_summary => $incidents->openqa_summary_only_incident($incident)
        }
      );
    }
  );

  $server->tool(
    name        => 'list_blocked',
    description => 'List incidents that are currently blocked',
    code        => sub ($tool, $args) {
      return encode_json($self->incidents->blocked);
    }
  );

  $server->tool(
    name        => 'get_repo_status',
    description => 'Get status of various repositories/products',
    code        => sub ($tool, $args) {
      return encode_json($self->incidents->repos);
    }
  );

  return $self;
}

sub server ($self) { $self->{server} }

1;

# Copyright (C) 2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package Dashboard::Plugin::Helpers;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use JSON::Validator;
use Mojo::ByteStream;
use Mojo::URL;

sub register ($self, $app, $conf) {
  $app->helper('latest_update'               => sub ($c) { $c->jobs->latest_update });
  $app->helper('link_to_incident'            => \&_link_to_incident);
  $app->helper('link_to_incident_openqa'     => \&_link_to_incident_openqa);
  $app->helper('link_to_smelt'               => \&_link_to_smelt);
  $app->helper('reply.json_validation_error' => \&_json_validation_error);
  $app->helper('openqa_url'                  => sub ($c) { Mojo::URL->new($c->app->config->{openqa}{url}) });
  $app->helper('schema'                      => sub ($c, $schema) { JSON::Validator->new->schema($schema) });
  $app->helper('summary'                     => \&_summary);
  $app->helper('summary_for_incident_build'  => \&_summary_for_incident_build);
}

sub _json_validation_error ($c) {
  my $failed = join ', ', @{$c->validation->failed};
  $c->render(json => {error => "Invalid request parameters ($failed)"}, status => 400);
}

sub _link_to_incident ($c, $inc) {
  return $c->helpers->link_to(
    $c->incidents->name($inc) => $c->helpers->url_for('incident', incident => $inc->{number}) =>
      (class => 'incident-link'));
}

sub _link_to_incident_openqa ($c, $inc) {
  return Mojo::ByteStream->new("No incident build found") unless my $build = $c->incidents->build_nr($inc);

  my $url     = $c->openqa_url->path('/tests/overview')->query(build => $build);
  my $summary = $c->incidents->openqa_summary_only_incident($inc);
  my @results;
  push(@results, "$summary->{passed} passed") if $summary->{passed};
  delete $summary->{passed};
  for my $key (sort keys %$summary) {
    push(@results, "$summary->{$key} $key");
  }

  return Mojo::ByteStream->new(join(', ', @results) . " - see details on " . $c->helpers->link_to("openqa." => $url));
}

sub _link_to_smelt ($c, $inc) {
  my $config = $c->app->config;
  my $smelt  = $config->{smelt}{url};
  my $obs    = $config->{obs}{url};

  my $link = $c->helpers->link_to($c->incidents->name($inc) => "$smelt/incident/$inc->{number}", target => '_blank');

  my $badge = '';
  if ($inc->{rr_number}) {
    $badge = <<"EOF";
<a href="$obs/request/show/$inc->{rr_number}" target="_blank" class="rr-link">
  <i class="fas fa-box"></i>
</a>
EOF
  }

  return Mojo::ByteStream->new(qq{<div class="incident-link">$link$badge</div>});
}

sub _summary ($c, $result) {
  my $group = delete $result->{name};
  my $link  = $c->openqa_url->path('/tests/overview')->query(delete $result->{linkinfo});
  my $total = 0;
  $total += $_ for values %$result;

  my $html = "$group is problematic";
  if ($result->{failed}) {
    $html = <<"EOF";
<a href="$link" class="btn btn-danger" target="_blank">
  $group <span class="badge badge-light">$result->{failed}/$total</span>
  <span class="sr-only">failed jobs</span>
</a>
EOF
  }
  elsif ($result->{stopped}) {
    $html = <<"EOF";
<a href="$link" class="btn btn-secondary" target="_blank">
  $group <span class="badge badge-light">$result->{stopped}/$total</span>
  <span class="sr-only">stopped jobs</span>
</a>
EOF
  }
  elsif ($result->{waiting}) {
    $html = <<"EOF";
<a href="$link" class="btn btn-info" target="_blank">
  $group <span class="badge badge-light">$result->{waiting}/$total</span>
  <span class="sr-only">stopped jobs</span>
</a>
EOF
  }
  elsif ($result->{passed} == $total) {
    $html = <<"EOF";
<a href="$link" class="btn btn-success" target="_blank">
  $group <span class="badge badge-light">$result->{passed}</span>
  <span class="sr-only">passed jobs</span>
</a>
EOF
  }

  return Mojo::ByteStream->new($html);
}

sub _summary_for_incident_build ($c, $build, $jobs) {
  my %groups;
  my %links;
  my $passed = 0;
  for my $job (@$jobs) {
    my $key = $job->{job_group} . "@" . $job->{flavor};
    if ($job->{status} eq 'passed') {
      $passed++;
      next;
    }
    $groups{$key} ||= {};
    $groups{$key}->{$job->{status}} ||= 0;
    $groups{$key}->{$job->{status}}++;
    $links{$key} ||= $c->openqa_url->path('/tests/overview')->query(
      version => $job->{version},
      groupid => $job->{group_id},
      flavor  => $job->{flavor},
      distri  => $job->{distri},
      build   => $job->{build}
    );
  }

  my $html = "<h3 cass='card-title d-flex'>Build $build ($passed passed)</h3>";
  for my $group (sort keys %groups) {
    my %info   = %{$groups{$group}};
    my $failed = delete $info{failed};

    my $link = $html .= "<p><strong>Group " . $c->link_to($group => $links{$group}) . "</strong> (";
    $html .= "<mark>$failed failed</mark>" if $failed;
    for my $status (sort keys %info) {
      $html .= ", " if $failed;
      $html .= "<mark>$info{$status} $status</mark>";
    }
    $html .= ")</p>";
  }

  return Mojo::ByteStream->new($html);
}

1;

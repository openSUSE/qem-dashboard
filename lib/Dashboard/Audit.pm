# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard::Audit;
use v5.36;

use JSON::PP ();

my %SEVERITY_RANK = (info => 0, low => 1, moderate => 2, high => 3, critical => 4);

sub severity_rank ($severity) {

  # Unknown labels rank as critical so a new label cannot slip under the threshold.
  return $SEVERITY_RANK{$severity // ''} // $SEVERITY_RANK{critical};
}

sub perl_advisories ($json) {
  my $report = _decode($json);
  die 'cpan-audit reported errors: ' . JSON::PP->new->canonical->encode($report->{errors}) . "\n"
    if @{$report->{errors} // []};
  my %advisories;
  for my $dist (values %{$report->{dists} // {}}) {
    $advisories{$_->{id}} = {severity => $_->{severity}, source => $_->{distribution}} for @{$dist->{advisories} // []};
  }
  return \%advisories;
}

sub npm_advisories ($json) {
  my $report = _decode($json);
  die "npm audit failed: $report->{error}{summary}\n" if $report->{error};
  my %advisories;
  for my $name (sort keys %{$report->{vulnerabilities} // {}}) {
    my $vulnerability = $report->{vulnerabilities}{$name};
    for my $via (grep {ref} @{$vulnerability->{via} // []}) {
      my ($id) = ($via->{url} // '') =~ m{/([^/]+)\z} or die "npm advisory without URL in $vulnerability->{name}\n";
      $advisories{$id} //= {severity => $via->{severity}, source => $vulnerability->{name}};
    }
  }
  return \%advisories;
}

sub parse_waivers ($text) {
  my %waivers;
  for my $line (split /\n/, $text) {
    next if $line =~ /^\s*(?:#|\z)/;
    my ($id, $expires, $reason) = $line =~ /^\s*(\S+)\s+(\d{4}-\d{2}-\d{2})\s+(.+?)\s*\z/
      or die "Malformed waiver: $line\n";
    $waivers{$id} = {expires => $expires, reason => $reason};
  }
  return \%waivers;
}

sub findings ($head, %args) {
  my $base    = $args{base};
  my $waivers = $args{waivers};
  my $min     = severity_rank($args{threshold});
  my $today   = $args{today};
  return grep {
    severity_rank($head->{$_}{severity}) >= $min && !($base && exists $base->{$_}) && !_waived($waivers->{$_}, $today)
  } sort keys %$head;
}

sub _waived ($waiver, $today) {
  return $waiver && $waiver->{expires} ge $today;
}

sub _decode ($json) {
  my $report = eval { JSON::PP->new->decode($json) };
  die "Audit report is not valid JSON: $@" if $@;
  return $report;
}

1;

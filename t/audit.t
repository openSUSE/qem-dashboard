# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Mojo::Base -strict, -signatures;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Test::Warnings ':report_warnings';
use Dashboard::Audit;
use File::Spec;
use File::Temp;

subtest 'severity ranks' => sub {
  my @cases = (
    ['info',     0, 'info ranks lowest'],
    ['moderate', 2, 'moderate ranks above low'],
    ['critical', 4, 'critical ranks highest'],
    ['unknown',  4, 'unknown label ranks as critical'],
    [undef,      4, 'undefined severity ranks as critical'],
  );
  for my $case (@cases) {
    my ($severity, $rank, $desc) = @$case;
    is(Dashboard::Audit::severity_rank($severity), $rank, $desc);
  }
};

subtest 'perl advisories' => sub {
  is_deeply(
    Dashboard::Audit::perl_advisories(
          '{"dists":{"A":{"advisories":[{"id":"CPANSA-A-1","severity":"high","distribution":"A"}]},'
        . '"B":{"advisories":[{"id":"CPANSA-B-1","severity":"moderate","distribution":"B"}]}}}'
    ),
    {'CPANSA-A-1' => {severity => 'high', source => 'A'}, 'CPANSA-B-1' => {severity => 'moderate', source => 'B'},},
    'advisories are keyed by id across all dists'
  );
  is_deeply(Dashboard::Audit::perl_advisories('{"dists":{"A":{"advisories":[]}}}'),
    {}, 'dist without advisories yields no findings');
  is_deeply(Dashboard::Audit::perl_advisories('{}'), {}, 'report without dists yields no findings');
  eval { Dashboard::Audit::perl_advisories('{"errors":["boom"]}') };
  like($@, qr/cpan-audit reported errors: \["boom"\]/, 'cpan-audit errors are fatal');
};

subtest 'npm advisories' => sub {
  my $report = <<'JSON';
{"vulnerabilities":{
  "glob":{"name":"glob","via":[
    {"url":"https://github.com/advisories/GHSA-aaaa-bbbb-cccc","severity":"moderate","name":"glob"},
    "minimatch"]},
  "js-beautify":{"name":"js-beautify","via":[
    {"url":"https://github.com/advisories/GHSA-aaaa-bbbb-cccc","severity":"moderate","name":"glob"}]},
  "plain":{"name":"plain","via":["glob"]}
}}
JSON
  is_deeply(
    Dashboard::Audit::npm_advisories($report),
    {'GHSA-aaaa-bbbb-cccc' => {severity => 'moderate', source => 'glob'}},
    'advisories are keyed by GHSA id, deduplicated, and string via entries are skipped'
  );
  is_deeply(Dashboard::Audit::npm_advisories('{}'), {}, 'report without vulnerabilities yields no findings');
  eval { Dashboard::Audit::npm_advisories('') };
  like($@, qr/Audit report is not valid JSON/, 'empty report is fatal with a clear message');
  eval { Dashboard::Audit::npm_advisories('{"error":{"summary":"registry down"}}') };
  like($@, qr/npm audit failed: registry down/, 'npm error is fatal');
  eval { Dashboard::Audit::npm_advisories('{"vulnerabilities":{"x":{"name":"x","via":[{"severity":"low"}]}}}') };
  like($@, qr/npm advisory without URL in x/, 'advisory without URL is fatal');
};

subtest 'waiver file' => sub {
  my $text = "# header\n\nCPANSA-A-1 2027-05-15 accepted risk  \n  GHSA-b  2027-01-01   dev only\n";
  is_deeply(
    Dashboard::Audit::parse_waivers($text),
    {
      'CPANSA-A-1' => {expires => '2027-05-15', reason => 'accepted risk'},
      'GHSA-b'     => {expires => '2027-01-01', reason => 'dev only'},
    },
    'comments and blank lines are ignored, reasons are trimmed'
  );
  eval { Dashboard::Audit::parse_waivers("CPANSA-A-1 next-year reason\n") };
  like($@, qr/Malformed waiver: CPANSA-A-1 next-year reason/, 'waiver without ISO date is fatal');
};

subtest 'findings' => sub {
  my $moderate = {'M-1' => {severity => 'moderate', source => 'p'}};
  my $cases    = [
    {desc => 'advisory absent from base is reported', head => $moderate, base => {}, waivers => '', expect => ['M-1'],},
    {
      desc    => 'advisory already present in base is not reported',
      head    => $moderate,
      base    => $moderate,
      waivers => '',
      expect  => [],
    },
    {
      desc    => 'advisory below threshold is not reported',
      head    => {'L-1' => {severity => 'low', source => 'p'}},
      base    => {},
      waivers => '',
      expect  => [],
    },
    {
      desc      => 'advisory with unknown severity is reported above a high threshold',
      head      => {'X-1' => {severity => 'bogus', source => 'p'}},
      base      => {},
      waivers   => '',
      threshold => 'high',
      expect    => ['X-1'],
    },
    {
      desc    => 'waived advisory is not reported on its expiry day',
      head    => $moderate,
      base    => {},
      waivers => 'M-1 2027-05-15 accepted',
      expect  => [],
    },
    {
      desc    => 'waived advisory is reported after its expiry day',
      head    => $moderate,
      base    => {},
      waivers => 'M-1 2027-05-14 accepted',
      expect  => ['M-1'],
    },
    {
      desc    => 'without base every unwaived advisory at threshold is reported',
      head    => {%$moderate, 'H-1' => {severity => 'high', source => 'q'}},
      base    => undef,
      waivers => '',
      expect  => ['H-1', 'M-1'],
    },
  ];
  for my $case (@$cases) {
    is_deeply(
      [
        Dashboard::Audit::findings(
          $case->{head},
          base      => $case->{base},
          waivers   => Dashboard::Audit::parse_waivers($case->{waivers}),
          threshold => $case->{threshold} // 'moderate',
          today     => '2027-05-15',
        )
      ],
      $case->{expect},
      $case->{desc}
    );
  }
};

subtest "audit-diff exit status" => sub {
  my $head = File::Temp->new;
  print {$head}
    q({"vulnerabilities":{"p":{"name":"p","via":[{"url":"https://github.com/advisories/GHSA-x","severity":"high","name":"p"}]}}});
  close $head;
  my $waivers = File::Temp->new;
  close $waivers;
  my $run = sub (@args) {
    my $devnull = File::Spec->devnull;
    open my $saved, ">&", \*STDOUT or die $!;
    open STDOUT,    ">",  $devnull or die $!;
    my $status = system($^X, "$FindBin::Bin/../script/audit-diff",
      "--ecosystem", "npm", "--head", $head->filename, "--waivers", $waivers->filename, @args);
    open STDOUT, ">&", $saved or die $!;
    $status == -1 and die "cannot run audit-diff: $!";
    return $? >> 8;
  };
  is($run->(), 1, "unwaived advisory at threshold fails");
  is($run->("--base",      $head->filename), 0, "advisory present in base passes");
  is($run->("--threshold", "critical"),      0, "advisory below threshold passes");
};

done_testing;

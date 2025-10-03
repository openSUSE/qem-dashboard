# Copyright (C) 2020 SUSE LLC
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

use Mojo::Base -strict, -signatures;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Test::Mojo;
use Test::Output 'stderr_like';
use Dashboard::Test;
use Mojo::JSON qw(false true);

plan skip_all => 'set TEST_ONLINE to enable this test' unless $ENV{TEST_ONLINE};

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'api_test');
my $config         = $dashboard_test->default_config;
my $t              = Test::Mojo->new(Dashboard => $config);
$dashboard_test->no_fixtures($t->app);
my $auth_headers = {Authorization => 'Token test_token', Accept => 'application/json'};

my $mock_incident = {
  number   => 16860,
  project  => 'SUSE:Maintenance:16860',
  packages =>
    ['salt', 'cobbler', 'spacecmd', 'mgr-daemon', 'spacewalk-abrt', 'yum-rhn-plugin', 'spacewalk-client-tools'],
  channels    => ['Test'],
  rr_number   => undef,
  inReview    => true,
  inReviewQAM => true,
  approved    => false,
  emu         => true,
  isActive    => true,
  embargoed   => false,
  priority    => 123,
};

subtest 'Migrations' => sub {
  is $t->app->pg->migrations->latest, 9, 'latest version';
  is $t->app->pg->migrations->active, 9, 'active version';
};

subtest 'Unknown endpoint' => sub {
  $t->get_ok('/api/unknown' => $auth_headers)->status_is(404)->json_is({error => 'Resource not found'});
};

subtest 'No incidents yet' => sub {
  $t->get_ok('/api/incidents'       => $auth_headers)->status_is(200)->json_is([]);
  $t->get_ok('/api/incidents/1'     => $auth_headers)->status_is(404)->json_is({error => 'Incident not found'});
  $t->get_ok('/api/incidents/16860' => $auth_headers)->status_is(404)->json_is({error => 'Incident not found'});
};

subtest 'Compression available' => sub {
  $t->app->renderer->min_compress_size(1);
  $t->get_ok('/api/incidents' => $auth_headers)->status_is(200)->header_like(Vary => qr/Accept-Encoding/)->json_is([]);
};

subtest 'JSON schema validation failed' => sub {
  $t->patch_ok('/api/incidents' => $auth_headers => json => [{number => 16861}])->status_is(400);
  like $t->tx->res->json('/error'), qr/Incidents do not match the JSON schema:.+/, 'right error';

  $t->patch_ok('/api/incidents' => $auth_headers => json =>
      [{%$mock_incident, packages => [], embargoed => true, priority => undef,}])->status_is(400);
  like $t->tx->res->json('/error'), qr/Incidents do not match the JSON schema:.+/, 'right error';

  $t->patch_ok('/api/incidents/16860' => $auth_headers => json => {%$mock_incident, packages => [], priority => undef})
    ->status_is(400);
  like $t->tx->res->json('/error'), qr/Incident does not match the JSON schema:.+/, 'right error';

  $t->patch_ok('/api/incidents' => $auth_headers => json => [{%$mock_incident, inReviewQAM => [], priority => undef}])
    ->status_is(400);
  like $t->tx->res->json('/error'), qr/Expected boolean - got array/, 'right error';

  $t->patch_ok(
    '/api/incidents/16862' => $auth_headers => json => {
      %$mock_incident,
      number      => 16862,
      project     => 'SUSE:Maintenance:16862',
      packages    => ['perl-Mojo-Pg'],
      channels    => ['Test3'],
      rr_number   => 12345,
      inReview    => false,
      inReviewQAM => [],
      emu         => false,
      priority    => undef,
    }
  )->status_is(400);
  like $t->tx->res->json('/error'), qr/Expected boolean - got array/, 'right error';
};

subtest 'Add incident' => sub {
  $t->patch_ok('/api/incidents' => $auth_headers => json => [$mock_incident])
    ->status_is(200)
    ->json_is({message => 'Ok'});
  my $expected = {%$mock_incident, type => '', url => '', scminfo => ''};
  $t->get_ok('/api/incidents'       => $auth_headers)->status_is(200)->json_is([$expected]);
  $t->get_ok('/api/incidents/16860' => $auth_headers)->status_is(200)->json_is($expected);
  $t->get_ok('/api/incidents/1'     => $auth_headers)->status_is(404)->json_is({error => 'Incident not found'});
};

subtest 'Update incident' => sub {
  $t->patch_ok(
    '/api/incidents' => $auth_headers => json => [
      {
        %$mock_incident,
        packages    => ['salt', 'cobbler', 'spacecmd', 'mgr-daemon', 'yum-rhn-plugin', 'spacewalk-client-tools'],
        channels    => ['Test', 'Test2',   'Test3'],
        rr_number   => 228241,
        inReview    => false,
        inReviewQAM => false,
        emu         => false,
        embargoed   => true,
        priority    => 456,
      }
    ]
  )->status_is(200)->json_is({message => 'Ok'});

  $t->get_ok('/api/incidents' => $auth_headers)->status_is(200)->json_is(
    [
      {
        number      => 16860,
        project     => 'SUSE:Maintenance:16860',
        packages    => ['salt', 'cobbler', 'spacecmd', 'mgr-daemon', 'yum-rhn-plugin', 'spacewalk-client-tools'],
        channels    => ['Test', 'Test2',   'Test3'],
        rr_number   => 228241,
        inReview    => false,
        inReviewQAM => false,
        approved    => false,
        emu         => false,
        isActive    => true,
        embargoed   => true,
        priority    => 456,
        scminfo     => '',
        url         => '',
        type        => '',
      }
    ]
  );

  $t->get_ok('/api/incidents/16860' => $auth_headers)->status_is(200)->json_is(
    {
      number      => 16860,
      project     => 'SUSE:Maintenance:16860',
      packages    => ['salt', 'cobbler', 'spacecmd', 'mgr-daemon', 'yum-rhn-plugin', 'spacewalk-client-tools'],
      channels    => ['Test', 'Test2',   'Test3'],
      rr_number   => 228241,
      inReview    => false,
      inReviewQAM => false,
      approved    => false,
      emu         => false,
      isActive    => true,
      embargoed   => true,
      priority    => 456,
      scminfo     => '',
      url         => '',
      type        => '',
    }
  );
  $t->get_ok('/api/incidents/1' => $auth_headers)->status_is(404)->json_is({error => 'Incident not found'});
};

subtest 'Obsolete incident' => sub {
  $t->patch_ok(
    '/api/incidents?type=git' => $auth_headers => json => [
      {
        number      => 42,
        project     => 'SLFO',
        packages    => ['bc'],
        channels    => ['foo'],
        isActive    => true,
        embargoed   => false,
        rr_number   => undef,
        inReview    => false,
        inReviewQAM => false,
        approved    => false,
        emu         => false,
        type        => 'git'
      }
    ]
  );
  $t->status_is(200)->json_is({message => 'Ok'});
  $t->get_ok('/api/incidents/16860' => $auth_headers);
  $t->status_is(200, 'SMELT incidents not obsoleted when type=git specified');

  $t->patch_ok(
    '/api/incidents' => $auth_headers => json => [
      {
        number      => 16861,
        project     => 'SUSE:Maintenance:16861',
        packages    => ['perl-Mojolicious'],
        channels    => ['Test2'],
        rr_number   => undef,
        inReview    => false,
        inReviewQAM => false,
        approved    => false,
        emu         => false,
        isActive    => true,
        embargoed   => false
      }
    ]
  )->status_is(200)->json_is({message => 'Ok'});
  $t->get_ok('/api/incidents/16860' => $auth_headers);
  $t->status_is(404, 'SMELT incidents obsoleted when no type specified');
  $t->get_ok('/api/incidents/42' => $auth_headers);
  $t->status_is(200, 'Git incidents not obsoleted when no type specified');

  $t->patch_ok('/api/incidents?type=foo&type=git&type=bar' => $auth_headers => json => []);
  $t->status_is(200)->json_is({message => 'Ok'});
  $t->get_ok('/api/incidents/42' => $auth_headers);
  $t->status_is(404, 'Git incident obsoleted when type=git specified among other types');

  $t->get_ok('/api/incidents' => $auth_headers)->status_is(200)->json_is(
    [
      {
        number      => 16861,
        project     => 'SUSE:Maintenance:16861',
        packages    => ['perl-Mojolicious'],
        channels    => ['Test2'],
        rr_number   => undef,
        inReview    => false,
        inReviewQAM => false,
        approved    => false,
        emu         => false,
        isActive    => true,
        embargoed   => false,
        priority    => undef,
        scminfo     => '',
        url         => '',
        type        => '',
      }
    ]
  );

  $t->get_ok('/api/incidents/16861' => $auth_headers)->status_is(200)->json_is(
    {
      number      => 16861,
      project     => 'SUSE:Maintenance:16861',
      packages    => ['perl-Mojolicious'],
      channels    => ['Test2'],
      rr_number   => undef,
      inReview    => false,
      inReviewQAM => false,
      approved    => false,
      emu         => false,
      isActive    => true,
      embargoed   => false,
      priority    => undef,
      scminfo     => '',
      url         => '',
      type        => '',
    }
  );
  $t->get_ok('/api/incidents/16860' => $auth_headers)->status_is(404)->json_is({error => 'Incident not found'});
};

subtest 'Update individual incidents' => sub {
  $t->patch_ok(
    '/api/incidents/16862' => $auth_headers => json => {
      number      => 16862,
      project     => 'SUSE:Maintenance:16862',
      packages    => ['perl-Mojo-Pg'],
      channels    => ['Test3'],
      rr_number   => 12345,
      inReview    => false,
      inReviewQAM => false,
      approved    => false,
      emu         => false,
      isActive    => true,
      embargoed   => false,
      priority    => undef,
      scminfo     => '18bfa2a23fb7985d5d0cc356474a96a19d91d2d8652442badf7f13bc07cd1f3d',
      url         => 'https://src.suse.de/products/SLFO/pulls/124',
      type        => 'git',
    }
  )->status_is(200)->json_is({message => 'Ok'});

  $t->get_ok('/api/incidents/16861' => $auth_headers)->status_is(200)->json_is(
    {
      number      => 16861,
      project     => 'SUSE:Maintenance:16861',
      packages    => ['perl-Mojolicious'],
      channels    => ['Test2'],
      rr_number   => undef,
      inReview    => false,
      inReviewQAM => false,
      approved    => false,
      emu         => false,
      isActive    => true,
      embargoed   => false,
      priority    => undef,
      scminfo     => '',
      url         => '',
      type        => '',
    }
  );
  $t->get_ok('/api/incidents/16862' => $auth_headers)->status_is(200)->json_is(
    {
      number      => 16862,
      project     => 'SUSE:Maintenance:16862',
      packages    => ['perl-Mojo-Pg'],
      channels    => ['Test3'],
      rr_number   => 12345,
      inReview    => false,
      inReviewQAM => false,
      approved    => false,
      emu         => false,
      isActive    => true,
      embargoed   => false,
      priority    => undef,
      scminfo     => '18bfa2a23fb7985d5d0cc356474a96a19d91d2d8652442badf7f13bc07cd1f3d',
      url         => 'https://src.suse.de/products/SLFO/pulls/124',
      type        => 'git',
    }
  );

  stderr_like {
    $t->patch_ok(
      '/api/incidents/16862' => $auth_headers => json => {
        number      => 16862,
        project     => 'SUSE:Maintenance:16862',
        packages    => ['perl-Mojo-Pg'],
        channels    => ['Test4'],
        rr_number   => 54321,
        inReview    => false,
        inReviewQAM => false,
        approved    => false,
        emu         => false,
        isActive    => true,
        embargoed   => true,
        priority    => undef,
        scminfo     => '18bfa2a23fb7985d5d0cc356474a96a19d91d2d8652442badf7f13bc07cd1f3d',
        url         => 'https://src.suse.de/products/SLFO/pulls/124',
        type        => 'git',
      }
    )->status_is(200)->json_is({message => 'Ok'})
  }
  qr/Cleaning up old jobs/, 'log message';

  $t->get_ok('/api/incidents' => $auth_headers)->status_is(200)->json_is(
    [
      {
        number      => 16861,
        project     => 'SUSE:Maintenance:16861',
        packages    => ['perl-Mojolicious'],
        channels    => ['Test2'],
        rr_number   => undef,
        inReview    => false,
        inReviewQAM => false,
        approved    => false,
        emu         => false,
        isActive    => true,
        embargoed   => false,
        priority    => undef,
        scminfo     => '',
        url         => '',
        type        => '',
      },
      {
        number      => 16862,
        project     => 'SUSE:Maintenance:16862',
        packages    => ['perl-Mojo-Pg'],
        channels    => ['Test4'],
        rr_number   => 54321,
        inReview    => false,
        inReviewQAM => false,
        approved    => false,
        emu         => false,
        isActive    => true,
        embargoed   => true,
        priority    => undef,
        scminfo     => '18bfa2a23fb7985d5d0cc356474a96a19d91d2d8652442badf7f13bc07cd1f3d',
        url         => 'https://src.suse.de/products/SLFO/pulls/124',
        type        => 'git',
      }
    ]
  );

  $t->patch_ok(
    '/api/incidents/16862' => $auth_headers => json => {
      number      => 16862,
      project     => 'SUSE:Maintenance:16862',
      packages    => ['perl-Mojo-Pg'],
      channels    => ['Test4'],
      rr_number   => 54321,
      inReview    => false,
      inReviewQAM => false,
      approved    => false,
      emu         => false,
      isActive    => false,
      embargoed   => false,
      priority    => undef,
      scminfo     => '',
      url         => '',
      type        => '',
    }
  )->status_is(200)->json_is({message => 'Ok'});
  $t->get_ok('/api/incidents/16862' => $auth_headers)->status_is(404)->json_is({error => 'Incident not found'});
};

subtest 'Add incident settings' => sub {
  $t->get_ok('/api/incident_settings/1'     => $auth_headers)->status_is(400)->json_is({error => 'Incident not found'});
  $t->get_ok('/api/incident_settings/16861' => $auth_headers)->status_is(200)->json_is([]);

  $t->put_ok(
    '/api/incident_settings' => $auth_headers => json => {
      incident      => 16861,
      version       => '15-SP2',
      flavor        => 'Server-DVD-HA-Incidents-Install',
      arch          => 'x86_64',
      withAggregate => true,
      settings      => {DISTRI => 'sle', VERSION => '15-SP2'}
    }
  )->status_is(200)->json_is({message => 'Ok', id => 1});

  $t->get_ok('/api/incident_settings/16861' => $auth_headers)->status_is(200)->json_is(
    [
      {
        id            => 1,
        incident      => 16861,
        version       => '15-SP2',
        flavor        => 'Server-DVD-HA-Incidents-Install',
        arch          => 'x86_64',
        withAggregate => true,
        settings      => {DISTRI => 'sle', VERSION => '15-SP2'}
      }
    ]
  );
};

subtest 'Add update settings' => sub {
  $t->get_ok('/api/update_settings/1'     => $auth_headers)->status_is(400)->json_is({error => 'Incident not found'});
  $t->get_ok('/api/update_settings/16861' => $auth_headers)->status_is(200)->json_is([]);

  $t->put_ok(
    '/api/update_settings' => $auth_headers => json => {
      incidents => [16861],
      product   => 'SLES-15-GA',
      arch      => 'x86_64',
      build     => '20201107-1',
      repohash  => 'd5815a9f8aa482ec8288508da27a9d36',
      settings  => {DISTRI => 'sle', VERSION => '15-SP2'}
    }
  )->status_is(200)->json_is({message => 'Ok', id => 1});

  $t->get_ok('/api/update_settings/16861' => $auth_headers)->status_is(200)->json_is(
    [
      {
        id        => 1,
        incidents => [16861],
        product   => 'SLES-15-GA',
        arch      => 'x86_64',
        build     => '20201107-1',
        repohash  => 'd5815a9f8aa482ec8288508da27a9d36',
        settings  => {DISTRI => 'sle', VERSION => '15-SP2'}
      }
    ]
  );
};

subtest 'Add openQA job' => sub {
  $t->get_ok('/api/jobs/1' => $auth_headers)->status_is(400)->json_is({error => 'Job not found'});

  $t->put_ok(
    '/api/jobs' => $auth_headers => json => {
      incident_settings => 1,
      update_settings   => 1,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP5 Incidents',
      status            => 'passed',
      job_id            => 4953193,
      group_id          => 282,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'x86_64',
      version           => '12-SP5',
      build             => ':17063:wpa_supplicant'
    }
  )->status_is(200)->json_is({message => 'Ok'});

  $t->get_ok('/api/jobs/4953193' => $auth_headers)->status_is(200)->json_is(
    {
      incident_settings => 1,
      update_settings   => 1,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP5 Incidents',
      status            => 'passed',
      job_id            => 4953193,
      group_id          => 282,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'x86_64',
      version           => '12-SP5',
      build             => ':17063:wpa_supplicant',
      obsolete          => false
    }
  );
};

subtest 'Modify openQA job' => sub {
  $t->get_ok('/api/jobs/4953193' => $auth_headers)->status_is(200)->json_is(
    {
      incident_settings => 1,
      update_settings   => 1,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP5 Incidents',
      status            => 'passed',
      job_id            => 4953193,
      group_id          => 282,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'x86_64',
      version           => '12-SP5',
      build             => ':17063:wpa_supplicant',
      obsolete          => false
    }
  );

  $t->patch_ok('/api/jobs/4953193' => $auth_headers => json => {obsolete => true})
    ->status_is(200)
    ->json_is({message => 'Ok'});

  $t->get_ok('/api/jobs/4953193' => $auth_headers)->status_is(200)->json_is(
    {
      incident_settings => 1,
      update_settings   => 1,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP5 Incidents',
      status            => 'passed',
      job_id            => 4953193,
      group_id          => 282,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'x86_64',
      version           => '12-SP5',
      build             => ':17063:wpa_supplicant',
      obsolete          => true
    }
  );

  $t->patch_ok('/api/jobs/4953193' => $auth_headers => json => {})->status_is(200)->json_is({message => 'Ok'});
  $t->get_ok('/api/jobs/4953193' => $auth_headers)->status_is(200)->json_is(
    {
      incident_settings => 1,
      update_settings   => 1,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP5 Incidents',
      status            => 'passed',
      job_id            => 4953193,
      group_id          => 282,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'x86_64',
      version           => '12-SP5',
      build             => ':17063:wpa_supplicant',
      obsolete          => true
    }
  );

  $t->patch_ok('/api/jobs/4953193' => $auth_headers => json => {obsolete => 'whatever'})
    ->status_is(400)
    ->json_like('/error', qr/Expected boolean - got string/);
};

subtest 'Add remark on openQA job and related incident' => sub {
  $t->patch_ok('/api/jobs/4953193/remarks?incident_number=123&text=acceptable_for' => $auth_headers);
  $t->status_is(404, 'error if incident does not exist');

  $t->patch_ok('/api/jobs/8888888/remarks?incident_number=16860&text=acceptable_for' => $auth_headers);
  $t->status_is(404, 'error if job does not exist');
  $t->patch_ok('/api/jobs/4953193/remarks?incident_number=16860&text=acceptable_for' => $auth_headers);
  $t->status_is(200)->json_is({message => 'Ok'});
  $t->get_ok('/api/jobs/4953193/remarks' => $auth_headers)->status_is(200);
  $t->json_is('/remarks', [{incident => 16860, text => 'acceptable_for'}], 'remark exists');

  $t->patch_ok('/api/jobs/4953193/remarks?incident_number=16861&text=foo' => $auth_headers);
  $t->status_is(200)->json_is('/message', 'Ok', 'second remark added');
  $t->patch_ok('/api/jobs/4953193/remarks?incident_number=16860&text=bar' => $auth_headers);
  $t->status_is(200)->json_is('/message', 'Ok', 'first remark updated');
  $t->get_ok('/api/jobs/4953193/remarks' => $auth_headers)->status_is(200);
  $t->json_is(
    '/remarks',
    [{incident => 16860, text => 'bar'}, {incident => 16861, text => 'foo'}],
    'existing remark updated, new remark added'
  );
};

subtest 'Replace openQA job' => sub {
  my %json = (
    incident_settings => 1,
    update_settings   => 1,
    name              => 'mau-webserver@64bit',
    job_group         => 'Maintenance: SLE 12 SP5 Incidents',
    status            => 'failed',
    job_id            => 4953193,
    group_id          => 282,
    distri            => 'sle',
    flavor            => 'Server-DVD-Incidents',
    arch              => 'x86_64',
    version           => '12-SP5',
    build             => ':17063:wpa_supplicant',
    obsolete          => true,
  );
  $t->put_ok('/api/jobs' => $auth_headers => json => \%json)->status_is(200);
  $t->json_is({message => 'Ok'});
  $t->get_ok('/api/jobs/4953193' => $auth_headers)->status_is(200);
  $t->json_is('', \%json, 'job updated');
  $t->get_ok('/api/jobs/4953193/remarks' => $auth_headers)->status_is(200);
  $t->json_has('/remarks/0', 'remark still present if openQA job ID does not change (1)');
  $t->json_has('/remarks/1', 'remark still present if openQA job ID does not change (2)');

  # change job ID from 4953193 to 4953293
  $json{job_id} = 4953293;
  $t->put_ok('/api/jobs' => $auth_headers => json => \%json)->status_is(200);
  $t->json_is({message => 'Ok'});

  $t->get_ok('/api/jobs/4953293' => $auth_headers)->status_is(200);
  $t->json_is('', \%json, 'job replaced');

  $t->get_ok('/api/jobs/4953293/remarks' => $auth_headers)->status_is(200);
  $t->json_is('/remarks', [], 'remark on job being replaced was removed');
};

subtest 'Search update settings' => sub {
  $t->put_ok(
    '/api/update_settings' => $auth_headers => json => {
      incidents => [16861, 16860],
      product   => 'SLES-15-GA',
      arch      => 'x86_64',
      build     => '20201107-2',
      repohash  => 'd5815a9f8aa482ec8288508da27a9d37',
      settings  => {DISTRI => 'sle', VERSION => '15-SP1'}
    }
  )->status_is(200)->json_is({message => 'Ok', id => 2});

  $t->put_ok(
    '/api/update_settings' => $auth_headers => json => {
      incidents => [16861],
      product   => 'HA-15-SP2',
      arch      => 'aarch64',
      build     => '20201107-3',
      repohash  => 'd5815a9f8aa482ec8288508da27a9d38',
      settings  => {DISTRI => 'sle', VERSION => '15-SP2'}
    }
  )->status_is(200)->json_is({message => 'Ok', id => 3});

  $t->get_ok('/api/update_settings' => $auth_headers)
    ->status_is(400)
    ->json_is({error => 'Invalid request parameters (arch, product)'});

  $t->get_ok('/api/update_settings?product=SLES-15-GA&arch=x86_64' => $auth_headers)->status_is(200)->json_is(
    [
      {
        id        => 2,
        incidents => [16861, 16860],
        product   => 'SLES-15-GA',
        arch      => 'x86_64',
        build     => '20201107-2',
        repohash  => 'd5815a9f8aa482ec8288508da27a9d37',
        settings  => {DISTRI => 'sle', VERSION => '15-SP1'}
      },
      {
        id        => 1,
        incidents => [16861],
        product   => 'SLES-15-GA',
        arch      => 'x86_64',
        build     => '20201107-1',
        repohash  => 'd5815a9f8aa482ec8288508da27a9d36',
        settings  => {DISTRI => 'sle', VERSION => '15-SP2'}
      }
    ]
  );

  $t->get_ok('/api/update_settings?product=SLES-15-GA&arch=x86_64&limit=1' => $auth_headers)->status_is(200)->json_is(
    [
      {
        id        => 2,
        incidents => [16861, 16860],
        product   => 'SLES-15-GA',
        arch      => 'x86_64',
        build     => '20201107-2',
        repohash  => 'd5815a9f8aa482ec8288508da27a9d37',
        settings  => {DISTRI => 'sle', VERSION => '15-SP1'}
      }
    ]
  );

  $t->get_ok('/api/update_settings?product=HA-15-SP2&arch=aarch64' => $auth_headers)->status_is(200)->json_is(
    [
      {
        id        => 3,
        incidents => [16861],
        product   => 'HA-15-SP2',
        arch      => 'aarch64',
        build     => '20201107-3',
        repohash  => 'd5815a9f8aa482ec8288508da27a9d38',
        settings  => {DISTRI => 'sle', VERSION => '15-SP2'}
      }
    ]
  );
};

subtest 'Job validation' => sub {
  $t->put_ok(
    '/api/jobs' => $auth_headers => json => {
      incident_settings => 1000,
      update_settings   => undef,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP5 Incidents',
      status            => 'passed',
      job_id            => 4953193,
      group_id          => 282,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'x86_64',
      version           => '12-SP5',
      build             => ':17063:wpa_supplicant'
    }
  )->status_is(400)->json_is({error => 'Referenced incident settings (1000) do not exist'});

  $t->put_ok(
    '/api/jobs' => $auth_headers => json => {
      incident_settings => undef,
      update_settings   => 1000,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP5 Incidents',
      status            => 'passed',
      job_id            => 4953193,
      group_id          => 282,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'x86_64',
      version           => '12-SP5',
      build             => ':17063:wpa_supplicant'
    }
  )->status_is(400)->json_is({error => 'Referenced update settings (1000) do not exist'});

  $t->put_ok(
    '/api/jobs' => $auth_headers => json => {
      incident_settings => undef,
      update_settings   => undef,
      name              => 'mau-webserver@64bit',
      job_group         => 'Maintenance: SLE 12 SP5 Incidents',
      status            => 'passed',
      job_id            => 4953193,
      group_id          => 282,
      distri            => 'sle',
      flavor            => 'Server-DVD-Incidents',
      arch              => 'x86_64',
      version           => '12-SP5',
      build             => ':17063:wpa_supplicant'
    }
  )->status_is(400)->json_is({error => 'Job needs to reference incident settings or update settings'});
};

subtest "Get jobs by settings" => sub {
  $t->get_ok('/api/jobs/incident/1' => $auth_headers)->status_is(200)->json_is(
    [
      {
        incident_settings => 1,
        update_settings   => 1,
        name              => 'mau-webserver@64bit',
        job_group         => 'Maintenance: SLE 12 SP5 Incidents',
        status            => 'failed',
        job_id            => 4953293,
        group_id          => 282,
        distri            => 'sle',
        flavor            => 'Server-DVD-Incidents',
        arch              => 'x86_64',
        version           => '12-SP5',
        build             => ':17063:wpa_supplicant'
      }
    ]
  );

  $t->get_ok('/api/jobs/update/1' => $auth_headers)->status_is(200)->json_is(
    [
      {
        incident_settings => 1,
        update_settings   => 1,
        name              => 'mau-webserver@64bit',
        job_group         => 'Maintenance: SLE 12 SP5 Incidents',
        status            => 'failed',
        job_id            => 4953293,
        group_id          => 282,
        distri            => 'sle',
        flavor            => 'Server-DVD-Incidents',
        arch              => 'x86_64',
        version           => '12-SP5',
        build             => ':17063:wpa_supplicant'
      }
    ]
  );

  $t->get_ok('/api/jobs/incident/2' => $auth_headers)->status_is(200)->json_is([]);

  $t->get_ok('/api/jobs/update/2' => $auth_headers)->status_is(200)->json_is([]);
};

subtest 'Authentication' => sub {
  $t->get_ok('/api/incidents')->status_is(200);
  $t->get_ok('/api/incidents' => $auth_headers)->status_is(200);
  $t->patch_ok('/api/incidents' => json => [{%$mock_incident, embargoed => true,}])
    ->status_is(403)
    ->json_is({error => 'Permission denied'});
  $t->patch_ok('/api/incidents' => $auth_headers => json => [{%$mock_incident}])
    ->status_is(200)
    ->json_is({message => 'Ok'});
};


done_testing();

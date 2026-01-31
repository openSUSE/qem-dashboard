package Dashboard::Test::APICommon;
use Mojo::Base -strict, -signatures;
use Test::More;
use Test::Mojo;
use Test::Output 'stderr_like';
use Mojo::JSON qw(false true);
use Exporter 'import';

our @EXPORT = qw(run_api_tests);

sub run_api_tests ($t, $prefix) {
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
    stderr_like {
      $t->get_ok("$prefix/unknown" => $auth_headers)
        ->status_is(404)
        ->json_is('', {error => 'Resource not found'}, 'correct error body');
    }
    qr/access_log/, 'access log caught';
  };

  subtest 'No incidents yet' => sub {
    stderr_like {
      $t->get_ok("$prefix/incidents"       => $auth_headers)->status_is(200)->json_is('',       [], 'empty list');
      $t->get_ok("$prefix/incidents/1"     => $auth_headers)->status_is(404)->json_is('/error', 'Incident not found');
      $t->get_ok("$prefix/incidents/16860" => $auth_headers)->status_is(404)->json_is('/error', 'Incident not found');
    }
    qr/access_log/, 'access log caught';
  };

  subtest 'Compression available' => sub {
    $t->app->renderer->min_compress_size(1);
    stderr_like {
      $t->get_ok("$prefix/incidents" => $auth_headers)
        ->status_is(200)
        ->header_like(Vary => qr/Accept-Encoding/)
        ->json_is('', []);
    }
    qr/access_log/, 'access log caught';
  };

  subtest 'JSON schema validation failed' => sub {
    stderr_like {
      $t->patch_ok("$prefix/incidents" => $auth_headers)
        ->status_is(400)
        ->json_is('/error',            'Validation failed')
        ->json_is('/errors/0/message', 'Missing property.')
        ->json_is('/errors/0/path',    '/body');
      $t->patch_ok("$prefix/incidents" => $auth_headers => json => [{number => 16861}])->status_is(400);
      is $t->tx->res->json('/error'), 'Validation failed', 'right error';

      $t->patch_ok("$prefix/incidents" => $auth_headers => json =>
          [{%$mock_incident, packages => [], embargoed => true, priority => undef,}])->status_is(400);
      is $t->tx->res->json('/error'), 'Validation failed', 'right error';

      $t->patch_ok("$prefix/incidents/16860" => $auth_headers)
        ->status_is(400)
        ->json_is('/error',            'Validation failed')
        ->json_is('/errors/0/message', 'Missing property.')
        ->json_is('/errors/0/path',    '/body');
      $t->patch_ok(
        "$prefix/incidents/16860" => $auth_headers => json => {%$mock_incident, packages => [], priority => undef})
        ->status_is(400);
      is $t->tx->res->json('/error'), 'Validation failed', 'right error';

      $t->patch_ok(
        "$prefix/incidents" => $auth_headers => json => [{%$mock_incident, inReviewQAM => [], priority => undef}])
        ->status_is(400);
      is $t->tx->res->json('/error'),            'Validation failed',             'right error';
      is $t->tx->res->json('/errors/0/message'), 'Expected boolean - got array.', 'right error message';
    }
    qr/access_log/, 'access log caught';
  };

  subtest 'Add and Update incidents' => sub {
    stderr_like {
      $t->patch_ok("$prefix/incidents" => $auth_headers => json => [$mock_incident])
        ->status_is(200)
        ->json_is('/message', 'Ok');

      my $expected = {%$mock_incident, type => '', url => '', scminfo => ''};
      $t->get_ok("$prefix/incidents"       => $auth_headers)->status_is(200)->json_is('', [$expected]);
      $t->get_ok("$prefix/incidents/16860" => $auth_headers)->status_is(200)->json_is('', $expected);

      # Update
      my $updated_mock = {%$mock_incident, priority => 456, embargoed => true};
      $t->patch_ok("$prefix/incidents/16860" => $auth_headers => json => $updated_mock);
      diag $t->tx->res->body unless $t->tx->res->code == 200;
      $t->status_is(200)->json_is('/message', 'Ok');

      $t->get_ok("$prefix/incidents/16860" => $auth_headers)
        ->status_is(200)
        ->json_is('/priority',  456)
        ->json_is('/embargoed', true);

      # Test new fields from qem-bot
      my $qem_bot_incident = {
        %$mock_incident,
        number                           => 16861,
        'scminfo_Foo'                    => 'deadbeef',
        'scminfo_BAR'                    => 'cafebabe',
        'failed_or_unpublished_packages' => ['foo'],
        'successful_packages'            => ['bar'],
      };
      $t->patch_ok("$prefix/incidents" => $auth_headers => json => [$qem_bot_incident])
        ->status_is(200)
        ->json_is('/message', 'Ok');
    }
    qr/access_log/, 'access log caught';
  };

  subtest 'Settings and Jobs' => sub {
    stderr_like {

      # Add incident settings
      $t->put_ok(
        "$prefix/incident_settings" => $auth_headers => json => {
          incident      => 16860,
          version       => '12-SP5',
          flavor        => 'Server-DVD-HA-Incidents-Install',
          arch          => 'x86_64',
          withAggregate => true,
          settings      => {DISTRI => 'sle', VERSION => '12-SP5'}
        }
      )->status_is(200)->json_is('/message', 'Ok')->json_is('/id', 1);

      # Test missing branch in Settings.pm (incident not found)
      $t->get_ok("$prefix/incident_settings/99999" => $auth_headers)
        ->status_is(400)
        ->json_is('/error', 'Incident not found');

      # Add update settings
      $t->put_ok(
        "$prefix/update_settings" => $auth_headers => json => {
          incidents => [16860],
          product   => 'SLES-15-GA',
          arch      => 'x86_64',
          build     => '20201107-1',
          repohash  => 'd5815a9f8aa482ec8288508da27a9d36',
          settings  => {DISTRI => 'sle', VERSION => '15-SP2'}
        }
      )->status_is(200)->json_is('/message', 'Ok')->json_is('/id', 1);

      # Add job
      my $job_data = {
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
        build             => ':16860:wpa_supplicant'
      };
      $t->put_ok("$prefix/jobs" => $auth_headers => json => $job_data)->status_is(200)->json_is('/message', 'Ok');

      # Add job with incident_settings only (covers branch in Jobs.pm)
      my $job_data_2 = {%$job_data, job_id => 4953194, name => 'other-job@64bit', update_settings => undef};
      $t->put_ok("$prefix/jobs" => $auth_headers => json => $job_data_2)->status_is(200)->json_is('/message', 'Ok');

      # Verify Get jobs by settings
      $t->get_ok("$prefix/jobs/incident/1" => $auth_headers)->status_is(200);
      is scalar @{$t->tx->res->json}, 2, 'two jobs for incident settings 1';

      # Branch coverage: same group_id for multiple jobs in _incident_openqa_jobs
      my $job_data_same_group = {%$job_data, job_id => 4953195, name => 'third-job@64bit', status => 'failed'};
      $t->put_ok("$prefix/jobs" => $auth_headers => json => $job_data_same_group)->status_is(200);
      $t->get_ok('/app/api/incident/16860')->status_is(200);
    }
    qr/access_log/, 'access log caught';
  };

  subtest 'Remarks' => sub {
    stderr_like {
      $t->patch_ok("$prefix/jobs/4953193/remarks?incident_number=16860&text=acceptable_for" => $auth_headers)
        ->status_is(200)
        ->json_is('/message', 'Ok');

      $t->get_ok("$prefix/jobs/4953193/remarks" => $auth_headers)
        ->status_is(200)
        ->json_is('/remarks/0/text', 'acceptable_for');

      # Branch coverage: job remark without incident number
      $t->patch_ok("$prefix/jobs/4953193/remarks?text=global_remark" => $auth_headers)
        ->status_is(200)
        ->json_is('/message', 'Ok');
      $t->get_ok("$prefix/jobs/4953193/remarks" => $auth_headers)
        ->status_is(200)
        ->json_is('/remarks/1/text', 'global_remark')
        ->json_is('/remarks/1/incident', undef, 'incident is undef for global remark');

      # Missing branch: non-existent job
      $t->get_ok("$prefix/jobs/8888888/remarks" => $auth_headers)
        ->status_is(404)
        ->json_is('/error', 'openQA job (8888888) does not exist');

      # Missing branch: non-existent incident
      $t->patch_ok("$prefix/jobs/4953193/remarks?incident_number=99999&text=foo" => $auth_headers)
        ->status_is(404)
        ->json_is('/error', 'Incident (99999) does not exist');
    }
    qr/access_log/, 'access log caught';
  };

  subtest 'Extra Settings Coverage' => sub {
    stderr_like {

      # add_incident_settings: incident not found
      $t->put_ok("$prefix/incident_settings" => $auth_headers => json =>
          {incident => 99999, version => 'v', flavor => 'f', arch => 'a', withAggregate => true, settings => {}})
        ->status_is(400)
        ->json_is('/error', 'Incident not found');

      # add_update_settings: one of incidents not found
      $t->put_ok("$prefix/update_settings" => $auth_headers => json =>
          {incidents => [16860, 99999], product => 'p', arch => 'a', build => 'b', repohash => 'h', settings => {}})
        ->status_is(400)
        ->json_is('/error', 'Incident not found');

      # _fix_booleans: withAggregate is false
      $t->put_ok("$prefix/incident_settings" => $auth_headers => json =>
          {incident => 16860, version => 'v2', flavor => 'f2', arch => 'a2', withAggregate => false, settings => {}})
        ->status_is(200);
      $t->get_ok("$prefix/incident_settings/16860" => $auth_headers)
        ->status_is(200)
        ->json_is('/0/withAggregate', false, 'withAggregate is correctly returned as false');
    }
    qr/access_log/, 'access log caught';
  };

  subtest 'Authentication' => sub {
    stderr_like {
      $t->get_ok("$prefix/incidents")->status_is(200);
      $t->patch_ok("$prefix/incidents" => json => [])->status_is(403)->json_is('/error', 'Permission denied');
    }
    qr/access_log/, 'access log caught';
  };
}

1;

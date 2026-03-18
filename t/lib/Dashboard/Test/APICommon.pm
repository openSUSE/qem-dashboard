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

  my $is_info     = $t->app->log->level eq 'info';
  my $stderr_test = sub ($code, $label) {
    if ($is_info) {
      stderr_like { $code->() } qr/access_log/, $label;
    }
    else {
      $code->();
      ok 1, $label;
    }
  };

  subtest 'Migrations' => sub {
    is $t->app->pg->migrations->latest, 9, 'latest version';
    is $t->app->pg->migrations->active, 9, 'active version';
  };

  subtest 'Unknown endpoint' => sub {
    $stderr_test->(
      sub {
        $t->get_ok("$prefix/unknown" => $auth_headers)
          ->status_is(404)
          ->json_is('', {error => 'Resource not found'}, 'correct error body');
      },
      'access log caught'
    );
  };

  subtest 'No incidents yet' => sub {
    $stderr_test->(
      sub {
        $t->get_ok("$prefix/incidents"   => $auth_headers)->status_is(200)->json_is('', [], 'empty list');
        $t->get_ok("$prefix/incidents/1" => $auth_headers)
          ->status_is(404)
          ->json_is('/error', 'Incident not found', 'error for incident 1');
        $t->get_ok("$prefix/incidents/16860" => $auth_headers)
          ->status_is(404)
          ->json_is('/error', 'Incident not found', 'error for incident 16860');
        $t->get_ok("$prefix/incidents/abc" => $auth_headers)->status_is(400)->json_is('/error', 'Validation failed');
      },
      'access log caught'
    );
  };

  subtest 'Compression available' => sub {
    $t->app->renderer->min_compress_size(1);
    $stderr_test->(
      sub {
        $t->get_ok("$prefix/incidents" => $auth_headers)
          ->status_is(200)
          ->header_like(Vary => qr/Accept-Encoding/)
          ->json_is('', []);
      },
      'access log caught'
    );
  };

  subtest 'JSON schema validation failed' => sub {
    $stderr_test->(
      sub {
        $t->patch_ok("$prefix/incidents" => $auth_headers)
          ->status_is(400)
          ->json_is('/error',            'Validation failed')
          ->json_is('/errors/0/message', 'Missing property.')
          ->json_is('/errors/0/path',    '/body');
        $t->patch_ok("$prefix/incidents" => $auth_headers => json => [{number => 16861}])->status_is(400);
        is $t->tx->res->json('/error'), 'Validation failed', 'right error for missing project';

        $t->patch_ok("$prefix/incidents" => $auth_headers => json => [{%$mock_incident, packages => "not an array"}])
          ->status_is(400);
        is $t->tx->res->json('/error'), 'Validation failed', 'right error for empty packages';

        $t->patch_ok("$prefix/incidents/16860" => $auth_headers)
          ->status_is(400)
          ->json_is('/error',            'Validation failed')
          ->json_is('/errors/0/message', 'Missing property.')
          ->json_is('/errors/0/path',    '/body');
        $t->patch_ok(
          "$prefix/incidents/16860" => $auth_headers => json => {%$mock_incident, packages => "not an array"})
          ->status_is(400);
        is $t->tx->res->json('/error'), 'Validation failed', 'right error for missing priority';

        $t->patch_ok(
          "$prefix/incidents" => $auth_headers => json => [{%$mock_incident, inReviewQAM => [], priority => undef}])
          ->status_is(400);
        is $t->tx->res->json('/error'), 'Validation failed', 'right error for invalid inReviewQAM';
        is $t->tx->res->json('/errors/0/message'), 'Expected boolean - got array.',
          'right error message for inReviewQAM';
      },
      'access log caught'
    );
  };

  subtest 'Add and Update incidents' => sub {
    $stderr_test->(
      sub {
        $t->patch_ok("$prefix/incidents" => $auth_headers => json => [$mock_incident])
          ->status_is(200)
          ->json_is('/message', 'Ok', 'patch incidents returns Ok');

        my $expected = {%$mock_incident, type => '', url => '', scminfo => ''};
        $t->get_ok("$prefix/incidents"       => $auth_headers)->status_is(200)->json_is('', [$expected]);
        $t->get_ok("$prefix/incidents/16860" => $auth_headers)->status_is(200)->json_is('', $expected);

        # Update
        my $updated_mock = {%$mock_incident, priority => 456, embargoed => true};
        $t->patch_ok("$prefix/incidents/16860" => $auth_headers => json => $updated_mock);
        diag $t->tx->res->body unless $t->tx->res->code == 200;    # uncoverable branch true
        $t->status_is(200)->json_is('/message', 'Ok', 'update incident 16860 returns Ok');

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
          ->json_is('/message', 'Ok', 'patch qem-bot incident returns Ok');
      },
      'access log caught'
    );
  };

  subtest 'Settings and Jobs' => sub {
    $stderr_test->(
      sub {

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
        )->status_is(200)->json_is('/message', 'Ok', 'put incident_settings returns Ok')->json_is('/id', 1);

        # Test missing branch in Settings.pm (incident not found)
        $t->get_ok("$prefix/incident_settings/99999" => $auth_headers)
          ->status_is(400)
          ->json_is('/error', 'Incident not found', 'error for non-existent incident settings');

        # Validation failure: incident settings with invalid number
        $t->get_ok("$prefix/incident_settings/abc" => $auth_headers)->status_is(400);

        # Validation failure: add incident settings with invalid body
        $t->put_ok("$prefix/incident_settings" => $auth_headers => json => {incident => 'abc'})->status_is(400);

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
        )->status_is(200)->json_is('/message', 'Ok', 'put update_settings returns Ok')->json_is('/id', 1);

        # Validation failure: add update settings with invalid body
        $t->put_ok("$prefix/update_settings" => $auth_headers => json => {incidents => 'abc'})->status_is(400);

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
        $t->put_ok("$prefix/jobs" => $auth_headers => json => $job_data)
          ->status_is(200)
          ->json_is('/message', 'Ok', 'put jobs returns Ok');

        # Validation failure: add jobs with invalid body
        $t->put_ok("$prefix/jobs" => $auth_headers => json => {job_id => 'abc'})->status_is(400);

        # Add job with incident_settings only (covers branch in Jobs.pm)
        my $job_data_2 = {%$job_data, job_id => 4953194, name => 'other-job@64bit', update_settings => undef};
        $t->put_ok("$prefix/jobs" => $auth_headers => json => $job_data_2)
          ->status_is(200)
          ->json_is('/message', 'Ok', 'put jobs (incident only) returns Ok');

        # Missing branches: job without references
        $t->put_ok(
          "$prefix/jobs" => $auth_headers => json => {%$job_data, incident_settings => undef, update_settings => undef})
          ->status_is(400)
          ->json_is('/error', 'Job needs to reference incident settings or update settings');

        # Missing branches: non-existent references
        $t->put_ok(
          "$prefix/jobs" => $auth_headers => json => {%$job_data, incident_settings => 9999, update_settings => undef})
          ->status_is(400)
          ->json_is('/error', 'Referenced incident settings (9999) do not exist');
        $t->put_ok(
          "$prefix/jobs" => $auth_headers => json => {%$job_data, incident_settings => undef, update_settings => 9999})
          ->status_is(400)
          ->json_is('/error', 'Referenced update settings (9999) do not exist');

        # Validation failure: modify job with invalid id
        $t->patch_ok("$prefix/jobs/abc" => $auth_headers => json => {})->status_is(400);

        # Verify Get jobs by settings
        $t->get_ok("$prefix/jobs/incident/1" => $auth_headers)->status_is(200);
        is scalar @{$t->tx->res->json}, 2, 'two jobs for incident settings 1';

        # Validation failure: get jobs by incident settings with invalid id
        $t->get_ok("$prefix/jobs/incident/abc" => $auth_headers)->status_is(400);

        # Verify Get update settings
        $t->get_ok("$prefix/update_settings/16860" => $auth_headers)
          ->status_is(200)
          ->json_is('/0/product', 'SLES-15-GA');

        # Verify Get jobs by update settings
        $t->get_ok("$prefix/jobs/update/1" => $auth_headers)->status_is(200)->json_is('/0/name', 'mau-webserver@64bit');

        # Validation failure: get jobs by update settings with invalid id
        $t->get_ok("$prefix/jobs/update/abc" => $auth_headers)->status_is(400);

        # Verify Get update settings for non-existent incident
        $t->get_ok("$prefix/update_settings/99999" => $auth_headers)
          ->status_is(400)
          ->json_is('/error', 'Incident not found');

        # Validation failure: get update settings with invalid incident id
        $t->get_ok("$prefix/update_settings/abc" => $auth_headers)->status_is(400);

        # Verify search update settings
        $t->get_ok("$prefix/update_settings?product=SLES-15-GA&arch=x86_64" => $auth_headers)
          ->status_is(200)
          ->json_is('/0/product', 'SLES-15-GA');

        # Branch coverage: search with no results
        $t->get_ok("$prefix/update_settings?product=None&arch=x86_64" => $auth_headers)
          ->status_is(200)
          ->json_is('', []);

        # Validation failure: search update settings with invalid limit
        $t->get_ok("$prefix/update_settings?limit=abc" => $auth_headers)->status_is(400);

        # Modify job
        $t->patch_ok("$prefix/jobs/4953193" => $auth_headers => json => {obsolete => true})
          ->status_is(200)
          ->json_is('/message', 'Ok', 'patch jobs returns Ok');
        $t->get_ok("$prefix/jobs/4953193" => $auth_headers)->status_is(200)->json_is('/obsolete', 1);

        # Missing branch: non-existent job in show
        $t->get_ok("$prefix/jobs/9999999" => $auth_headers)->status_is(400)->json_is('/error', 'Job not found');

        # Branch coverage: same group_id for multiple jobs in _incident_openqa_jobs
        my $job_data_same_group = {%$job_data, job_id => 4953195, name => 'third-job@64bit', status => 'failed'};
        $t->put_ok("$prefix/jobs" => $auth_headers => json => $job_data_same_group)->status_is(200);
        $t->get_ok('/app/api/incident/16860')->status_is(200);
      },
      'access log caught'
    );
  };

  subtest 'Remarks' => sub {
    $t->patch_ok(
      "$prefix/jobs/4953193/remarks" => $auth_headers => form => {incident_number => '16860', text => 'acceptable_for'})
      ->status_is(200);

    $t->get_ok("$prefix/jobs/4953193/remarks" => $auth_headers)
      ->status_is(200)
      ->json_is('/remarks/0/text', 'acceptable_for');

    # Test update_remark with JSON body
    $t->patch_ok(
      "$prefix/jobs/4953193/remarks" => $auth_headers => json => {incident_number => '16860', text => 'json_remark'})
      ->status_is(200);

    $t->get_ok("$prefix/jobs/4953193/remarks" => $auth_headers)->status_is(200);
    my $remarks = $t->tx->res->json->{remarks};
    ok((grep { $_->{text} eq 'json_remark' } @$remarks), 'json_remark added');

    # Branch coverage: job remark without incident number
    $t->patch_ok("$prefix/jobs/4953193/remarks" => $auth_headers => form => {text => 'global_remark'})->status_is(200);

    $t->get_ok("$prefix/jobs/4953193/remarks" => $auth_headers)->status_is(200);
    $remarks = $t->tx->res->json->{remarks};
    ok((grep { $_->{text} eq 'global_remark' } @$remarks), 'global_remark added');

    # Validation failure: show job with invalid id
    $t->get_ok("$prefix/jobs/abc" => $auth_headers)->status_is(400);

    # Validation failure: show remarks with invalid job id
    $t->get_ok("$prefix/jobs/abc/remarks" => $auth_headers)->status_is(400);

    # Missing branch: non-existent job
    $t->get_ok("$prefix/jobs/8888888/remarks" => $auth_headers)
      ->status_is(404)
      ->json_is('/error', 'openQA job (8888888) does not exist');
    $t->patch_ok("$prefix/jobs/8888888/remarks" => $auth_headers => json => {text => 'foo'})
      ->status_is(404)
      ->json_is('/error', 'openQA job (8888888) does not exist');

    # Missing branch: non-existent incident
    $t->patch_ok("$prefix/jobs/4953193/remarks?incident_number=99999&text=foo" => $auth_headers)
      ->status_is(404)
      ->json_is('/error', 'Incident (99999) does not exist');

    # Validation failure: invalid incident_number in JSON
    $t->patch_ok("$prefix/jobs/4953193/remarks" => $auth_headers => json => {incident_number => 'abc', text => 'foo'})
      ->status_is(400);

    # Validation failure: missing text in JSON
    $t->patch_ok("$prefix/jobs/4953193/remarks" => $auth_headers => json => {incident_number => '16860'})
      ->status_is(400);

    # Coverage for Jobs.pm line 69-70: incident_number/text from query string override JSON
    $t->patch_ok("$prefix/jobs/4953193/remarks?incident_number=16860&text=query_remark" => $auth_headers => json =>
        {incident_number => '99999', text => 'json_remark'})->status_is(200);

    # Validation failure: missing text in form (triggers line 73 in Jobs.pm)
    $t->patch_ok("$prefix/jobs/4953193/remarks" => $auth_headers => form => {incident_number => '16860'})
      ->status_is(400);

    # Validation failure: invalid incident_number in form
    $t->patch_ok("$prefix/jobs/4953193/remarks" => $auth_headers => form => {incident_number => 'abc', text => 'foo'})
      ->status_is(400);

    # Coverage for Jobs.pm line 73: missing text (no body)
    $t->patch_ok("$prefix/jobs/4953193/remarks" => $auth_headers)
      ->status_is(400)
      ->json_is('/error', 'Missing remark text');
  };

  subtest 'Extra Settings Coverage' => sub {
    $stderr_test->(
      sub {

        # add_incident_settings: incident not found
        $t->put_ok("$prefix/incident_settings" => $auth_headers => json =>
            {incident => 99999, version => 'v', flavor => 'f', arch => 'a', withAggregate => true, settings => {}})
          ->status_is(400)
          ->json_is('/error', 'Incident not found', 'error for adding incident_settings with non-existent incident');

        # add_update_settings: one of incidents not found
        $t->put_ok("$prefix/update_settings" => $auth_headers => json =>
            {incidents => [16860, 99999], product => 'p', arch => 'a', build => 'b', repohash => 'h', settings => {}})
          ->status_is(400)
          ->json_is('/error', 'Incident not found', 'error for adding update_settings with non-existent incident');

        # _fix_booleans: withAggregate is false
        $t->put_ok("$prefix/incident_settings" => $auth_headers => json =>
            {incident => 16860, version => 'v2', flavor => 'f2', arch => 'a2', withAggregate => false, settings => {}})
          ->status_is(200);
        $t->get_ok("$prefix/incident_settings/16860" => $auth_headers)
          ->status_is(200)
          ->json_is('/0/withAggregate', false, 'withAggregate is correctly returned as false');
      },
      'access log caught'
    );
  };

  subtest 'Authentication' => sub {
    $stderr_test->(
      sub {
        $t->get_ok("$prefix/incidents")->status_is(200);
        $t->patch_ok("$prefix/incidents" => json => [])->status_is(403)->json_is('/error', 'Permission denied');
      },
      'access log caught'
    );
  };
}

1;

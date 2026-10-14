# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Mojo::Base -strict, -signatures;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Test::Mojo;
use Test::MockModule;
use Test::Output 'stderr_like';
use Dashboard::Test;
use IPC::Open3;
use MCP::Constants qw(META_CLIENT_CAPABILITIES META_CLIENT_INFO META_PROTOCOL_VERSION PROTOCOL_VERSION);
use Mojo::JSON     qw(false true decode_json encode_json);
use Symbol 'gensym';

if (!$ENV{TEST_ONLINE}) {    # uncoverable branch true
  plan skip_all => 'set TEST_ONLINE to enable this test';    # uncoverable statement
}

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'mcp_test');
my $config         = $dashboard_test->default_config;
my $t              = Test::Mojo->new(Dashboard => $config);
$dashboard_test->minimal_fixtures($t->app);
my $access_log = sub { $t->app->log->level eq 'info' ? qr/access_log/ : qr/^$/ };

sub mcp_post ($test, $method, $params = {}, $id = 1) {
  my %headers = ('MCP-Protocol-Version' => PROTOCOL_VERSION, 'Mcp-Method' => $method);
  $headers{'Mcp-Name'} = $params->{name} if $method eq 'tools/call';
  my $body = {
    jsonrpc => '2.0',
    id      => $id,
    method  => $method,
    params  => {
      %$params,
      _meta => {
        META_PROTOCOL_VERSION()    => PROTOCOL_VERSION,
        META_CLIENT_CAPABILITIES() => {},
        META_CLIENT_INFO()         => {name => 'TestClient', version => '1.0.0'},
      },
    },
  };
  return $test->post_ok('/mcp' => \%headers => json => $body);
}

subtest 'Log level coverage' => sub {
  my $old_level = $t->app->log->level;
  $t->app->log->level('info');
  like 'access_log', $access_log->(), 'access_log info branch';
  $t->app->log->level('warn');
  like '', $access_log->(), 'access_log warn branch';
  $t->app->log->level($old_level);
};

subtest 'MCP Discovery' => sub {
  stderr_like {
    mcp_post($t, 'server/discover', {}, 0)->status_is(200);
  }
  $access_log->(), 'access log caught';
  ok $t->tx->res->json('/result'), 'server/discover returns a result';
};

subtest 'MCP Tool listing' => sub {
  stderr_like {
    mcp_post($t, 'tools/list', {}, 1)
      ->status_is(200)
      ->json_is('/result/tools/0/name', 'list_submissions')
      ->json_is('/result/tools/1/name', 'get_submission_details')
      ->json_is('/result/tools/2/name', 'list_blocked')
      ->json_is('/result/tools/3/name', 'get_repo_status');
  }
  $access_log->(), 'access log caught';
};

subtest 'MCP HTTP transport rejects unsupported methods' => sub {
  $t->get_ok('/mcp')->status_is(405);
  $t->delete_ok('/mcp')->status_is(405);
};

subtest 'MCP stdio transport lists tools' => sub {
  my $request = encode_json({jsonrpc => '2.0', id => 1, method => 'tools/list', params => {}});
  my $err     = gensym;
  my $pid     = open3(my $in, my $out, $err, $^X, "$FindBin::Bin/../script/mcp-stdio");
  print {$in} "$request\n";
  close $in;
  my $response = decode_json(scalar <$out>);
  waitpid $pid, 0;
  is $response->{id},                     1,                  'stdio response echoes request id';
  is $response->{result}{tools}[0]{name}, 'list_submissions', 'stdio tools/list returns list_submissions first';
  is $?,                                  0,                  'mcp-stdio exits with status 0 after stdin is closed';
};

subtest 'MCP Tool: list_submissions' => sub {

  # Seed data
  my $mock_incident = {
    number      => 12345,
    project     => 'SUSE:Maintenance:12345',
    packages    => ['test-pkg'],
    channels    => ['Test'],
    rr_number   => 6789,
    inReview    => 1,
    inReviewQAM => 1,
    approved    => 0,
    emu         => 1,
    isActive    => 1,
    embargoed   => 0,
    priority    => 100,
  };
  $t->app->incidents->sync([$mock_incident]);

  stderr_like {
    mcp_post($t, 'tools/call', {name => 'list_submissions', arguments => {number => 12345}}, 2)->status_is(200);
  }
  $access_log->(), 'access log caught';
  my $text = $t->tx->res->json('/result/content/0/text');
  like $text, qr/Incident 12345/, 'response contains incident number';

  # Seed an incident without channels
  my $mock_incident_no_channels = {
    number      => 54321,
    project     => 'SUSE:Maintenance:54321',
    packages    => ['test-pkg-2'],
    channels    => [],
    rr_number   => 9876,
    inReview    => 1,
    inReviewQAM => 1,
    approved    => 0,
    emu         => 1,
    isActive    => 1,
    embargoed   => 0,
    priority    => 100,
  };
  $t->app->incidents->sync([$mock_incident, $mock_incident_no_channels]);
  stderr_like {
    mcp_post($t, 'tools/call', {name => 'list_submissions', arguments => {number => 54321}}, 2)->status_is(200);
  }
  $access_log->(), 'access log caught';
  like $t->tx->res->json('/result/content/0/text'), qr/N\/A/, 'N/A for missing channels';

  # Seed an incident without channels (undef)
  my $mock_incident_undef_channels = {
    number      => 666,
    project     => 'SUSE:Maintenance:666',
    packages    => ['test-pkg-3'],
    channels    => undef,
    rr_number   => 666,
    inReview    => 1,
    inReviewQAM => 1,
    approved    => 0,
    emu         => 1,
    isActive    => 1,
    embargoed   => 0,
    priority    => 100,
  };
  $t->app->incidents->sync([$mock_incident, $mock_incident_no_channels, $mock_incident_undef_channels]);
  stderr_like {
    mcp_post($t, 'tools/call', {name => 'list_submissions', arguments => {number => 666}}, 2)->status_is(200);
  }
  $access_log->(), 'access log caught';
  like $t->tx->res->json('/result/content/0/text'), qr/N\/A/, 'N/A for undef channels';

  # Test no incidents found
  stderr_like {
    mcp_post($t, 'tools/call', {name => 'list_submissions', arguments => {number => 99999}}, 2)
      ->status_is(200)
      ->json_is('/result/content/0/text', 'No active incidents found.');
  }
  $access_log->(), 'access log caught';

  # Seed an incident with NULL project
  my $mock_incident_no_project = {
    number      => 777,
    project     => undef,
    packages    => ['pkg-no-project'],
    channels    => ['Channel1'],
    rr_number   => 777,
    inReview    => 1,
    inReviewQAM => 1,
    approved    => 0,
    emu         => 1,
    isActive    => 1,
    embargoed   => 0,
    priority    => 100,
  };
  $t->app->incidents->update($mock_incident_no_project);
  stderr_like {
    mcp_post($t, 'tools/call', {name => 'list_submissions', arguments => {number => 777}}, 2)->status_is(200);
  }
  $access_log->(), 'access log caught';
  like $t->tx->res->json('/result/content/0/text'), qr/\*\*Project:\*\* \n/, 'Project is empty for NULL project';
};

subtest 'MCP Tool: get_submission_details (found)' => sub {
  stderr_like {
    mcp_post($t, 'tools/call', {name => 'get_submission_details', arguments => {number => 12345}}, 3)->status_is(200);
  }
  $access_log->(), 'access log caught';
  my $text = $t->tx->res->json('/result/content/0/text');
  like $text, qr/Incident 12345 Details/, 'response contains incident details';
  like $text, qr/\*\*Channels:\*\* Test/, 'channels listed in details';
  like $text, qr/No openQA jobs found/,   'no jobs found message';

  stderr_like {
    mcp_post($t, 'tools/call', {name => 'get_submission_details', arguments => {number => 54321}}, 3)->status_is(200);
  }
  $access_log->(), 'access log caught';
  like $t->tx->res->json('/result/content/0/text'), qr/\*\*Channels:\*\* N\/A/, 'N/A for missing channels in details';

  stderr_like {
    mcp_post($t, 'tools/call', {name => 'get_submission_details', arguments => {number => 666}}, 3)->status_is(200);
  }
  $access_log->(), 'access log caught';
  like $t->tx->res->json('/result/content/0/text'), qr/\*\*Channels:\*\* N\/A/, 'N/A for undef channels in details';

  # Seed data for jobs
  my $inc_id = $t->app->incidents->id_for_number(12345);
  $t->app->pg->db->query(
    'INSERT INTO update_openqa_settings (product, arch, build, repohash, settings) VALUES (?, ?, ?, ?, ?) ON CONFLICT DO NOTHING',
    'SLES', 'x86_64', '1234', 'hash2', '{}'
  );
  my $uid2 = $t->app->pg->db->query("SELECT id FROM update_openqa_settings WHERE build = '1234'")->hash->{id};
  $t->app->pg->db->query('INSERT INTO incident_in_update (settings, incident) VALUES (?, ?) ON CONFLICT DO NOTHING',
    $uid2, $inc_id);
  $t->app->pg->db->query(
    'INSERT INTO openqa_jobs (update_settings, status, distri, version, flavor, arch, build, job_group, group_id, job_id, name)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT DO NOTHING', $uid2, 'failed', 'sle', '15-SP3', 'Online',
    'x86_64', '1234', 'Group', 1, 101, 'failed_job'
  );

  stderr_like {
    mcp_post($t, 'tools/call', {name => 'get_submission_details', arguments => {number => 12345}}, 3)->status_is(200);
  }
  $access_log->(), 'access log caught';
  like $t->tx->res->json('/result/content/0/text'), qr/failed_job/, 'job status in details';
};

subtest 'MCP Tool: get_submission_details (not found)' => sub {
  stderr_like {
    mcp_post($t, 'tools/call', {name => 'get_submission_details', arguments => {number => 99999}}, 3)
      ->status_is(200)
      ->json_is('/result/content/0/text', "```\nError: Incident 99999 not found\n```");
  }
  $access_log->(), 'access log caught';
};

subtest 'MCP Tool: list_blocked' => sub {
  my $mock = Test::MockModule->new('Dashboard::Model::Incidents');
  $mock->redefine(blocked => sub { [] });

  stderr_like {
    mcp_post($t, 'tools/call', {name => 'list_blocked'}, 4)
      ->status_is(200)
      ->json_is('/result/content/0/text', "```\nNo incidents currently blocked.\n```");
  }
  $access_log->(), 'access log caught';

  $mock->redefine(
    blocked => sub {
      [{incident => {number => 12345, project => 'SUSE:Maintenance:12345', blocked_reasons => ['reason1']}}];
    }
  );

  stderr_like {
    mcp_post($t, 'tools/call', {name => 'list_blocked'}, 4)->status_is(200);
  }
  $access_log->(), 'access log caught';
  like $t->tx->res->json('/result/content/0/text'), qr/reason1/, 'blocked incident with reason listed';

  # Without reasons
  $mock->redefine(
    blocked => sub {
      [{incident => {number => 54321, project => 'SUSE:Maintenance:54321',}}];
    }
  );
  stderr_like {
    mcp_post($t, 'tools/call', {name => 'list_blocked'}, 4)->status_is(200);
  }
  $access_log->(), 'access log caught';
};

subtest 'MCP Tool: get_repo_status' => sub {
  $t->app->pg->db->query('DELETE FROM openqa_jobs');
  $t->app->pg->db->query('DELETE FROM update_openqa_settings');
  stderr_like {
    mcp_post($t, 'tools/call', {name => 'get_repo_status'}, 5)
      ->status_is(200)
      ->json_is('/result/content/0/text', "```\nNo repository information available.\n```");
  }
  $access_log->(), 'access log caught';

  # Seed repo data
  # Avoid duplicate key by checking if it exists or just using different data
  $t->app->pg->db->query(
    'INSERT INTO update_openqa_settings (product, arch, build, repohash, settings) VALUES (?, ?, ?, ?, ?) ON CONFLICT DO NOTHING',
    'SLES', 'x86_64', '1234', 'hash', '{}'
  );
  my $uid = $t->app->pg->db->query("SELECT id FROM update_openqa_settings WHERE build = '1234'")->hash->{id};
  $t->app->pg->db->query(
    'INSERT INTO openqa_jobs (update_settings, status, distri, version, flavor, arch, build, job_group, group_id, job_id, name)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT DO NOTHING', $uid, 'passed', 'sle', '15-SP3', 'Online',
    'x86_64', '1234', 'Group', 1, 100, 'test_job'
  );

  stderr_like {
    mcp_post($t, 'tools/call', {name => 'get_repo_status'}, 5)->status_is(200);
  }
  $access_log->(), 'access log caught';
  like $t->tx->res->json('/result/content/0/text'), qr/Online-15-SP3-x86_64/, 'repo status listed';
};

subtest 'Coverage for missing keys' => sub {
  my $mock = Test::MockModule->new('Dashboard::Model::Incidents');

  # Return an incident missing some keys to hit // branches
  $mock->redefine(find => sub { [{}] });    # Missing everything
  mcp_post($t, 'tools/call', {name => 'list_submissions', arguments => {}}, 6)->status_is(200);
  like $t->tx->res->json('/result/content/0/text'), qr/Incident 0/, 'handles missing keys';

  $mock->redefine(incident_for_number   => sub { {id => 1} });    # Missing number, project, packages, etc.
  $mock->redefine(channels_for_incident => sub {undef});          # Missing channels
  mcp_post($t, 'tools/call', {name => 'get_submission_details', arguments => {number => 1}}, 7)->status_is(200);
  like $t->tx->res->json('/result/content/0/text'), qr/Incident 0 Details/, 'handles missing keys in details';
};


done_testing();

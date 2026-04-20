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
use Mojo::JSON qw(false true decode_json);

if (!$ENV{TEST_ONLINE}) {    # uncoverable branch true
  plan skip_all => 'set TEST_ONLINE to enable this test';    # uncoverable statement
}

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'mcp_test');
my $config         = $dashboard_test->default_config;
my $t              = Test::Mojo->new(Dashboard => $config);
$dashboard_test->minimal_fixtures($t->app);
my $access_log = sub { $t->app->log->level eq 'info' ? qr/access_log/ : qr/^$/ };

subtest 'Log level coverage' => sub {
  my $old_level = $t->app->log->level;
  $t->app->log->level('info');
  like 'access_log', $access_log->(), 'access_log info branch';
  $t->app->log->level('warn');
  like '', $access_log->(), 'access_log warn branch';
  $t->app->log->level($old_level);
};

my $session_id;
subtest 'MCP Initialization' => sub {
  stderr_like {
    $t->post_ok(
      '/app/mcp' => json => {
        jsonrpc => "2.0",
        id      => 0,
        method  => "initialize",
        params  => {
          protocolVersion => "2024-11-05",
          capabilities    => {},
          clientInfo      => {name => "TestClient", version => "1.0.0"}
        }
      }
    )->status_is(200);
  }
  $access_log->(), 'access log caught';
  $session_id = $t->tx->res->headers->header('Mcp-Session-Id');
  ok $session_id, 'got session ID';
};


subtest 'MCP Discovery' => sub {
  stderr_like {
    $t->post_ok(
      '/app/mcp' => {'Mcp-Session-Id' => $session_id} => json => {jsonrpc => "2.0", method => "tools/list", id => 1})
      ->status_is(200)
      ->json_is('/result/tools/0/name', 'list_submissions')
      ->json_is('/result/tools/1/name', 'get_submission_details')
      ->json_is('/result/tools/2/name', 'list_blocked')
      ->json_is('/result/tools/3/name', 'get_repo_status');
  }
  $access_log->(), 'access log caught';
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
    $t->post_ok(
      '/app/mcp' => {'Mcp-Session-Id' => $session_id} => json => {
        jsonrpc => "2.0",
        method  => "tools/call",
        params  => {name => 'list_submissions', arguments => {number => 12345}},
        id      => 2
      }
    )->status_is(200);
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
  $t->post_ok(
    '/app/mcp' => {'Mcp-Session-Id' => $session_id} => json => {
      jsonrpc => "2.0",
      method  => "tools/call",
      params  => {name => 'list_submissions', arguments => {number => 54321}},
      id      => 2
    }
  )->status_is(200);
  like $t->tx->res->json('/result/content/0/text'), qr/N\/A/, 'N/A for missing channels';

  # Test no incidents found
  $t->post_ok(
    '/app/mcp' => {'Mcp-Session-Id' => $session_id} => json => {
      jsonrpc => "2.0",
      method  => "tools/call",
      params  => {name => 'list_submissions', arguments => {number => 99999}},
      id      => 2
    }
  )->status_is(200)->json_is('/result/content/0/text', 'No active incidents found.');
};

subtest 'MCP Tool: get_submission_details (found)' => sub {
  stderr_like {
    $t->post_ok(
      '/app/mcp' => {'Mcp-Session-Id' => $session_id} => json => {
        jsonrpc => "2.0",
        method  => "tools/call",
        params  => {name => 'get_submission_details', arguments => {number => 12345}},
        id      => 3
      }
    )->status_is(200);
  }
  $access_log->(), 'access log caught';
  my $text = $t->tx->res->json('/result/content/0/text');
  like $text, qr/Incident 12345 Details/, 'response contains incident details';
  like $text, qr/No openQA jobs found/,   'no jobs found message';

  $t->post_ok(
    '/app/mcp' => {'Mcp-Session-Id' => $session_id} => json => {
      jsonrpc => "2.0",
      method  => "tools/call",
      params  => {name => 'get_submission_details', arguments => {number => 54321}},
      id      => 3
    }
  )->status_is(200);
  like $t->tx->res->json('/result/content/0/text'), qr/\*\*Channels:\*\* N\/A/, 'N/A for missing channels in details';

  # Seed data for jobs
  my $inc_id = $t->app->incidents->id_for_number(12345);
  $t->app->pg->db->query(
    'INSERT INTO update_openqa_settings (product, arch, build, repohash, settings) VALUES (?, ?, ?, ?, ?)',
    'SLES', 'x86_64', '1234', 'hash2', '{}');
  my $uid2 = $t->app->pg->db->query('SELECT id FROM update_openqa_settings ORDER BY id DESC LIMIT 1')->hash->{id};
  $t->app->pg->db->query('INSERT INTO incident_in_update (settings, incident) VALUES (?, ?)', $uid2, $inc_id);
  $t->app->pg->db->query(
    'INSERT INTO openqa_jobs (update_settings, status, distri, version, flavor, arch, build, job_group, group_id, job_id, name)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', $uid2, 'failed', 'sle', '15-SP3', 'Online', 'x86_64', '1234',
    'Group', 1, 101, 'failed_job'
  );

  $t->post_ok(
    '/app/mcp' => {'Mcp-Session-Id' => $session_id} => json => {
      jsonrpc => "2.0",
      method  => "tools/call",
      params  => {name => 'get_submission_details', arguments => {number => 12345}},
      id      => 3
    }
  )->status_is(200);
  like $t->tx->res->json('/result/content/0/text'), qr/failed_job/, 'job status in details';
};

subtest 'MCP Tool: get_submission_details (not found)' => sub {
  stderr_like {
    $t->post_ok(
      '/app/mcp' => {'Mcp-Session-Id' => $session_id} => json => {
        jsonrpc => "2.0",
        method  => "tools/call",
        params  => {name => 'get_submission_details', arguments => {number => 99999}},
        id      => 3
      }
    )->status_is(200)->json_is('/result/content/0/text', "```\nError: Incident 99999 not found\n```");
  }
  $access_log->(), 'access log caught';
};

subtest 'MCP Tool: list_blocked' => sub {
  my $mock = Test::MockModule->new('Dashboard::Model::Incidents');
  $mock->redefine(blocked => sub { [] });

  stderr_like {
    $t->post_ok('/app/mcp' => {'Mcp-Session-Id' => $session_id} => json =>
        {jsonrpc => "2.0", method => "tools/call", params => {name => 'list_blocked'}, id => 4})
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
    $t->post_ok('/app/mcp' => {'Mcp-Session-Id' => $session_id} => json =>
        {jsonrpc => "2.0", method => "tools/call", params => {name => 'list_blocked'}, id => 4})->status_is(200);
  }
  $access_log->(), 'access log caught';
  like $t->tx->res->json('/result/content/0/text'), qr/reason1/, 'blocked incident with reason listed';

  # Without reasons
  $mock->redefine(
    blocked => sub {
      [{incident => {number => 54321, project => 'SUSE:Maintenance:54321',}}];
    }
  );
  $t->post_ok('/app/mcp' => {'Mcp-Session-Id' => $session_id} => json =>
      {jsonrpc => "2.0", method => "tools/call", params => {name => 'list_blocked'}, id => 4})->status_is(200);
};

subtest 'MCP Tool: get_repo_status' => sub {

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
    $t->post_ok('/app/mcp' => {'Mcp-Session-Id' => $session_id} => json =>
        {jsonrpc => "2.0", method => "tools/call", params => {name => 'get_repo_status'}, id => 5})->status_is(200);
  }
  $access_log->(), 'access log caught';
  like $t->tx->res->json('/result/content/0/text'), qr/Online-15-SP3-x86_64/, 'repo status listed';
};


done_testing();

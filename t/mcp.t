# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Mojo::Base -strict, -signatures;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Test::Mojo;
use Test::Output 'stderr_like';
use Dashboard::Test;
use Mojo::JSON qw(false true decode_json);

plan skip_all => 'set TEST_ONLINE to enable this test' unless $ENV{TEST_ONLINE};

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'mcp_test');
my $config         = $dashboard_test->default_config;
my $t              = Test::Mojo->new(Dashboard => $config);
$dashboard_test->no_fixtures($t->app);

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
  qr/access_log/, 'access log caught';
  $session_id = $t->tx->res->headers->header('Mcp-Session-Id');
  ok $session_id, 'got session ID';
};

subtest 'MCP Discovery' => sub {
  stderr_like {
    $t->post_ok(
      '/app/mcp' => {'Mcp-Session-Id' => $session_id} => json => {jsonrpc => "2.0", method => "tools/list", id => 1})
      ->status_is(200)
      ->or(sub { diag shift->tx->res->body })
      ->json_is('/result/tools/0/name', 'list_submissions')
      ->json_is('/result/tools/1/name', 'get_submission_details')
      ->json_is('/result/tools/2/name', 'list_blocked')
      ->json_is('/result/tools/3/name', 'get_repo_status');
  }
  qr/access_log/, 'access log caught';
};

subtest 'MCP Tool: list_submissions' => sub {

  # Seed data
  my $mock_incident = {
    number      => 12345,
    project     => 'SUSE:Maintenance:12345',
    packages    => ['test-pkg'],
    channels    => ['Test'],
    rr_number   => undef,
    inReview    => true,
    inReviewQAM => true,
    approved    => false,
    emu         => true,
    isActive    => true,
    embargoed   => false,
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
  qr/access_log/, 'access log caught';
  my $text = $t->tx->res->json('/result/content/0/text');
  my $res  = decode_json($text);
  is $res->[0]{number}, 12345, 'correct incident number';
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
  qr/access_log/, 'access log caught';
  my $text = $t->tx->res->json('/result/content/0/text');
  my $res  = decode_json($text);
  is $res->{incident}{number}, 12345, 'correct incident number in details';
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
    )->status_is(200)->json_is('/result/content/0/text', '{"error":"Incident 99999 not found"}');
  }
  qr/access_log/, 'access log caught';
};

subtest 'MCP Tool: list_blocked' => sub {
  stderr_like {
    $t->post_ok('/app/mcp' => {'Mcp-Session-Id' => $session_id} => json =>
        {jsonrpc => "2.0", method => "tools/call", params => {name => 'list_blocked'}, id => 4})
      ->status_is(200)
      ->json_is('/result/content/0/type', 'text');
  }
  qr/access_log/, 'access log caught';
};

subtest 'MCP Tool: get_repo_status' => sub {
  stderr_like {
    $t->post_ok('/app/mcp' => {'Mcp-Session-Id' => $session_id} => json =>
        {jsonrpc => "2.0", method => "tools/call", params => {name => 'get_repo_status'}, id => 5})
      ->status_is(200)
      ->json_is('/result/content/0/type', 'text');
  }
  qr/access_log/, 'access log caught';
};

done_testing();

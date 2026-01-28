# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Dashboard;
use Mojo::Base 'Mojolicious', -signatures;

use Mojo::Pg;
use Mojo::File qw(curfile);
use Mojo::JSON;
use Dashboard::Model::Incidents;
use Dashboard::Model::Jobs;
use Dashboard::Model::Settings;
use Dashboard::Model::AMQP;
use Dashboard::Model::MCP;

# Avoid installing random npm packages bypassing package-lock.json
BEGIN { $ENV{MOJO_NPM_BINARY} = curfile->sibling('../script/npm-noop') }

# This method will run once at server start
sub startup ($self) {

  # Custom config file for qem2 deployment
  my $custom_file = '/home/lurklur/dashboard.yml';

  # Load configuration from config file
  my $file   = $ENV{DASHBOARD_CONF} || (-r $custom_file ? $custom_file : 'dashboard.yml');    # uncoverable branch true
  my $config = $self->plugin(NotYAMLConfig => {file => $file});

  if (my $override = $ENV{DASHBOARD_CONF_OVERRIDE}) {
    my $override_config = Mojo::JSON::decode_json($override);
    $self->config({%{$self->config}, %$override_config});
    $config = $self->config;
  }

  $self->secrets($config->{secrets});

  $self->{boot_id} = Mojo::Util::md5_sum(Time::HiRes::time() . rand());

  $self->_setup_logging;
  $self->_setup_helpers($config);
  $self->_register_routes($config);
}

sub _setup_logging ($self) {

  # Short logs for systemd
  if ($self->mode eq 'production') {
    $self->log->short(1);

    # All interesting log messages are "info" or higher
    $self->log->level('info');
  }

  # Structured JSON logging
  $self->hook(
    before_dispatch => sub ($c) {
      $c->stash(
        request_id => $c->req->request_id // Mojo::Util::monkey_patch(    # uncoverable branch true
          'Mojo::Transaction', 'request_id' =>
            sub { shift->{request_id} ||= Mojo::Util::md5_sum(Time::HiRes::time() . rand()) }  # uncoverable branch true
        )
      );
    }
  );

  $self->hook(
    before_routes => sub ($c) {
      my $req     = $c->req;
      my $method  = $req->method;
      my $url     = $req->url->to_abs->to_string;
      my $started = [Time::HiRes::gettimeofday];
      $c->tx->on(
        finish => sub ($tx, @args) {
          my $code    = $tx->res->code;
          my $elapsed = Time::HiRes::tv_interval($started, [Time::HiRes::gettimeofday()]);
          my $rps     = $elapsed == 0 ? '??' : sprintf '%.3f', 1 / $elapsed;
          $self->log->info(
            Mojo::JSON::encode_json(
              {
                method     => $method,
                url        => $url,
                code       => $code,
                elapsed    => $elapsed,
                rps        => $rps,
                request_id => $c->stash('request_id'),
                type       => 'access_log'
              }
            )
          );
        }
      );
    }
  );
}

sub _setup_helpers ($self, $config) {

  # Application specific commands
  push @{$self->commands->namespaces}, 'Dashboard::Command';
  $self->commands->hint($self->commands->hint . <<EOF);

Environment variables:
  DASHBOARD_CONF           Path to configuration file
  DASHBOARD_CONF_OVERRIDE  JSON string to override configuration values
EOF

  $self->plugin('Dashboard::Plugin::JSON');
  $self->plugin('Dashboard::Plugin::Helpers');
  $self->plugin('Dashboard::Plugin::Database', $config);

  # Serve Swagger UI assets from npm package
  push @{$self->static->paths}, $self->home->child('node_modules', 'swagger-ui-dist');

  # Vite asset helper
  $self->helper(
    vite_asset => sub ($c, $entry) {
      state $is_dev = $self->mode eq 'development' && $ENV{VITE_DEV_SERVER};
      return Mojo::ByteStream->new(qq{<script type="module" src="http://localhost:5173/asset/$entry"></script>})
        if $is_dev;

      state $manifest = eval {
        my $path = $self->home->child('public', 'asset', '.vite', 'manifest.json');
        $path = $self->home->child('public', 'asset', 'manifest.json') unless -e $path;
        -e $path ? Mojo::JSON::decode_json($path->slurp) : undef;
      };

      if (!$manifest && $self->mode eq 'development') {
        return Mojo::ByteStream->new(qq{<script type="module" src="http://localhost:5173/asset/$entry"></script>});
      }

      return Mojo::ByteStream->new('<!-- vite_asset: manifest not found -->') unless $manifest;

      my $asset = $manifest->{$entry} or return Mojo::ByteStream->new("<!-- vite_asset: entry $entry not found -->");
      my $res   = qq{<script type="module" src="/asset/$asset->{file}"></script>};
      if (my $css = $asset->{css}) {
        $res .= qq{<link rel="stylesheet" href="/asset/$_">} for @$css;
      }
      return Mojo::ByteStream->new($res);
    }
  );

  # Compress dynamically generated content
  $self->renderer->compress(1);

  # Model
  my $log = $self->log;
  $self->helper(
    incidents => sub ($c) { state $incidents = Dashboard::Model::Incidents->new(log => $log, pg => $c->pg) });
  $self->helper(
    jobs => sub ($c) {
      state $jobs = Dashboard::Model::Jobs->new(
        days_to_keep_aggregates => $config->{days_to_keep_aggregates},
        pg                      => $c->pg,
        log                     => $self->log
      );
    }
  );
  $self->helper(settings => sub ($c) { state $settings = Dashboard::Model::Settings->new(pg => $c->pg) });
  $self->helper(amqp     => sub ($c) { state $amqp     = Dashboard::Model::AMQP->new(log => $log, jobs => $c->jobs) });
  $self->helper(
    mcp => sub ($c) {
      state $mcp = Dashboard::Model::MCP->new(incidents => $c->incidents, jobs => $c->jobs);
    }
  );

  # Migrations
  my $path = $self->home->child('migrations', 'dashboard.sql');
  $self->pg->auto_migrate($config->{auto_migrate} // 1)->migrations->name('dashboard')->from_file($path);
}

sub _register_routes ($self, $config) {

  # Authentication
  my $public = $self->routes;
  my $token  = $public->under('/')->to('Auth::Token#check');

  # Health checks
  $public->get('/health' => sub ($c) { $c->render(json => {status => 'ok'}) });
  $public->get(
    '/ready' => sub ($c) {
      eval { $c->pg->db->query('SELECT 1') };
      return $c->render(json => {status => 'fail', error => $@}, status => 500) if $@;
      $c->render(json => {status => 'ok'});
    }
  );

  # Single page app
  $public->get(
    '/app-config' => sub ($c) {
      my $config = $c->app->config;
      $c->render(
        json => {
          bootId                => $self->{boot_id},
          openqaUrl             => $c->openqa_url->path('/tests/overview'),
          obsUrl                => $config->{obs}{url},
          smeltUrl              => $config->{smelt}{url},
          giteaFallbackPriority => $config->{gitea_fallback_priority} // 550
        }
      );
    }
  );

  # Dashboard JSON API for UI
  my $json = $public->any('/app/api' => [format => ['json']])->to(format => undef);
  $json->get('/list')->to('overview#list');
  $json->get('/blocked')->to('overview#blocked');
  $json->get('/repos')->to('overview#repos');
  $json->get('/incident/<incident:num>')->to('overview#incident');
  $json->get('/submission/<incident:num>')->to('overview#incident');

  # MCP
  $public->any('/app/mcp' => $self->mcp->server->to_action);

  # Catch all for delivering the webpack UI
  $public->get('/')->to('overview#index')->name('index');
  $public->get('/:name' => [name => ['repos', 'blocked']])->to('overview#index');
  $public->get('/incident/<incident:num>')->to('overview#index');
  $public->get('/submission/<incident:num>')->to('overview#index');

  # API (v1 and legacy)
  $self->plugin(
    'OpenAPI' => {
      url    => $self->home->child('resources', 'openapi.yaml'),
      route  => $token->any('/api'),
      coerce => {body => 1, params => 1}
    }
  );

  $self->plugin(
    'OpenAPI' => {
      url    => $self->home->child('resources', 'openapi.yaml'),
      route  => $token->any('/api/v1'),
      coerce => {body => 1, params => 1}
    }
  );

  $self->helper(
    'openapi.build_response_body' => sub ($c, $data) {
      if (ref $data eq 'HASH' && $data->{errors}) {
        my $status = $data->{status} // 400;
        if ($status == 404) { return Mojo::JSON::encode_json({error => 'Resource not found'}) }
        my @errors = map { ref $_ ? {message => $_->message, path => $_->path . ""} : {message => "$_", path => ""} }
          @{$data->{errors}};
        return Mojo::JSON::encode_json({error => "Validation failed", errors => \@errors});
      }
      return Mojo::JSON::encode_json($data);
    }
  );

  # Serve the OpenAPI spec for Swagger UI
  $public->get(
    '/api/v1/openapi.yaml' => sub ($c) { $c->reply->file($c->app->home->child('resources', 'openapi.yaml')) });

  # Swagger UI page
  $public->get(
    '/swagger' => sub ($c) {
      $c->render(inline => <<'EOF');
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <title>QEM Dashboard API</title>
    <link rel="stylesheet" type="text/css" href="/swagger-ui.css" />
    <link rel="icon" type="image/png" href="/favicon-32x32.png" sizes="32x32" />
    <link rel="icon" type="image/png" href="/favicon-16x16.png" sizes="16x16" />
    <style>
      html
      {
        box-sizing: border-box;
        overflow: -moz-scrollbars-vertical;
        overflow-y: scroll;
      }

      *,
      *:before,
      *:after
      {
        box-sizing: inherit;
      }

      body
      {
        margin:0;
        background: #fafafa;
      }
    </style>
  </head>

  <body>
    <div style="background-color: #1b1b1b; padding: 10px 20px;">
      <a href="/" style="color: #fff; text-decoration: none; font-family: sans-serif; font-weight: bold;">&larr; Back to Dashboard</a>
    </div>
    <div id="swagger-ui"></div>

    <script src="/swagger-ui-bundle.js" charset="UTF-8"> </script>
    <script src="/swagger-ui-standalone-preset.js" charset="UTF-8"> </script>
    <script>
    window.onload = function() {
      // Begin Swagger UI call region
      const ui = SwaggerUIBundle({
        url: "/api/v1/openapi.yaml",
        dom_id: '#swagger-ui',
        deepLinking: true,
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ],
        plugins: [
          SwaggerUIBundle.plugins.DownloadUrl
        ],
        layout: "StandaloneLayout"
      });
      // End Swagger UI call region

      window.ui = ui;
    };
  </script>
  </body>
</html>
EOF
    }
  );
}


1;

=encoding utf8

=head1 NAME

qem-dashboard

=head1 SYNOPSIS

  use Dashboard;

=head1 AUTHORS

=over 2

Sebastian Riedel, C<sriedel@suse.de>

Stephan Kulow, C<coolo@suse.de>

=back

=head1 COPYRIGHT AND LICENSE

 Copyright SUSE LLC
 SPDX-License-Identifier: GPL-2.0-or-later

=cut

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

# Avoid installing random npm packages bypassing package-lock.json
BEGIN { $ENV{MOJO_NPM_BINARY} = curfile->sibling('../script/npm-noop') }

# This method will run once at server start
sub startup ($self) {

  # Custom config file for qem2 deployment
  my $custom_file = '/home/lurklur/dashboard.yml';

  # Load configuration from config file
  my $file   = $ENV{DASHBOARD_CONF} || (-r $custom_file ? $custom_file : 'dashboard.yml');
  my $config = $self->plugin(NotYAMLConfig => {file => $file});

  if (my $override = $ENV{DASHBOARD_CONF_OVERRIDE}) {
    my $override_config = Mojo::JSON::decode_json($override);
    $self->config({%{$self->config}, %$override_config});
    $config = $self->config;
  }

  $self->secrets($config->{secrets});

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
        request_id => $c->req->request_id // Mojo::Util::monkey_patch(
          'Mojo::Transaction', 'request_id' =>
            sub { shift->{request_id} ||= Mojo::Util::md5_sum(Time::HiRes::time() . rand()) }   # uncoverable subroutine
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

  $self->plugin('Dashboard::Plugin::JSON');
  $self->plugin('Dashboard::Plugin::Helpers');
  $self->plugin('Dashboard::Plugin::Database', $config);

  # Automatic Webpack asset rebuilding in development mode
  my $process = $self->mode eq 'development' ? [qw(js vue scss sass)] : [];
  $self->plugin('Webpack', {process => $process});

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
          openqaUrl => $c->openqa_url->path('/tests/overview'),
          obsUrl    => $config->{obs}{url},
          smeltUrl  => $config->{smelt}{url}
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

  # Catch all for delivering the webpack UI
  $public->get('/')->to('overview#index')->name('index');
  $public->get('/:name' => [name => ['repos', 'blocked']])->to('overview#index');
  $public->get('/incident/<incident:num>')->to('overview#index');

  # API (v1 and legacy)
  my $register_api_routes = sub ($api) {
    $api->get('/incidents/<incident:num>')->to('API::Incidents#show');
    $api->get('/incidents')->to('API::Incidents#list');
    $api->patch('/incidents/<incident:num>')->to('API::Incidents#update');
    $api->patch('/incidents')->to('API::Incidents#sync');
    $api->get('/incident_settings/<incident:num>')->to('API::Settings#get_incident_settings');
    $api->put('/incident_settings')->to('API::Settings#add_incident_settings');
    $api->get('/update_settings/<incident:num>')->to('API::Settings#get_update_settings');
    $api->get('/update_settings')->to('API::Settings#search_update_settings');
    $api->put('/update_settings')->to('API::Settings#add_update_settings');
    $api->get('/jobs/<job_id:num>')->to('API::Jobs#show');
    $api->patch('/jobs/<job_id:num>')->to('API::Jobs#modify');
    $api->get('/jobs/<job_id:num>/remarks')->to('API::Jobs#show_remarks');
    $api->patch('/jobs/<job_id:num>/remarks')->to('API::Jobs#update_remark');
    $api->put('/jobs')->to('API::Jobs#add');
    $api->get('/jobs/incident/<incident_settings:num>')->to('API::Jobs#incidents');
    $api->get('/jobs/update/<update_settings:num>')->to('API::Jobs#updates');
  };

  $register_api_routes->($token->any('/api/v1'));
  $register_api_routes->($token->any('/api'));
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

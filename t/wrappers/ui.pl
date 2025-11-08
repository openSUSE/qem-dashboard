use Mojo::Base -strict, -signatures;


use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../lib";

use Mojo::Server::Daemon;
use Mojo::File qw(curfile);
use Test::Mojo;
use Dashboard::Test;

$ENV{MOJO_WEBPACK_BUILD} = 1;
my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'js_ui_test');
my $daemon         = Mojo::Server::Daemon->new(listen => ['http://*?fd=3'], silent => 1);

my $app = Test::Mojo->new(Dashboard => $dashboard_test->default_config)->app;
$daemon->app($app);
$app->log->level('warn');

my $r = $app->routes;
$r->get(
  '/deactivate_incidents' => sub ($c) {
    $c->pg->db->query('UPDATE incidents SET active = false');
    $c->render(text => 'ok');
  }
);

$r->get(
  '/obsolete_jobs' => sub ($c) {
    $c->pg->db->query('UPDATE openqa_jobs SET obsolete = true WHERE job_id = 4953194');
    $c->render(text => 'ok');
  }
);

$dashboard_test->minimal_fixtures($app);

$daemon->run;

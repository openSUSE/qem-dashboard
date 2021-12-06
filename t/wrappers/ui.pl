use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../lib";

use Mojo::Server::Daemon;
use Mojo::File qw(curfile);
use Test::Mojo;
use Dashboard::Test;

my $dashboard_test = Dashboard::Test->new(online => $ENV{TEST_ONLINE}, schema => 'js_ui_test');
my $daemon         = Mojo::Server::Daemon->new(listen => ['http://*?fd=3']);

my $app = Test::Mojo->new(Dashboard => $dashboard_test->default_config)->app;
$daemon->app($app);
$app->log->level('debug');
$dashboard_test->minimal_fixtures($app);

$daemon->run;

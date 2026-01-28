use Mojo::Base -strict, -signatures;

use Test::More;
use Test::Mojo;
use Dashboard::Test;
use Dashboard::Test::APICommon;

my $dashboard_test = Dashboard::Test->new;
my $config         = $dashboard_test->default_config;
my $t              = Test::Mojo->new(Dashboard => $config);
$dashboard_test->no_fixtures($t->app);

run_api_tests($t, '/api');

done_testing();
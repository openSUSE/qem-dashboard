use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Mojo::File qw(curfile);
use lib curfile->dirname->sibling('lib')->to_string;

# Mock database connection if needed, or rely on defaults if Dashboard handles missing DB gracefully for static pages
# However, Dashboard.pm startup connects to DB.
# We'll rely on the existing test setup helpers if possible, but for a quick check:

$ENV{MOJO_MODE} = 'development';

# We need to set up a dummy config or mocking if we don't want a real DB
# But for now let's assume we can just load the app if we provide minimal config

use Dashboard;

my $t = Test::Mojo->new('Dashboard');

# Try to fetch the swagger page
$t->get_ok('/swagger')->status_is(200)->content_like(qr/QEM Dashboard API/);

# Try to fetch the openapi.json
$t->get_ok('/api/v1/openapi.json')->status_is(200)->json_is('/openapi', '3.0.0');

done_testing();

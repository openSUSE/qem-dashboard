use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Mojo::File qw(curfile);
use lib curfile->dirname->sibling('lib')->to_string;

$ENV{MOJO_MODE} = 'development';
use Dashboard;
my $t = Test::Mojo->new('Dashboard');
$t->get_ok('/swagger')->status_is(200)->content_like(qr/QEM Dashboard API/);
$t->get_ok('/api/openapi.yaml')->status_is(200)->content_like(qr/openapi: 3.0.0/);

done_testing();

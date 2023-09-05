use Mojo::Base -strict, -signatures;

use FindBin;
use lib "$FindBin::Bin/lib", "$FindBin::Bin/t/lib";

use Dashboard;
use Dashboard::Test;

my $t = Dashboard::Test->new(online => $ARGV[0] // 'postgresql:///dashboard');
my $d = Dashboard->new;
$t->minimal_fixtures($d);

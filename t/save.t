use Test::More 0.98;

use HTTP::Cookies::Mozilla;

use lib 't';
use TestRelaxDiff ();

my $class = 'HTTP::Cookies::Mozilla';
use_ok( $class );

my $dist_file = 't/cookies.txt';
my $save_file = 't/cookies2.txt';

my %Domains = qw( .ebay.com 2 .usatoday.com 3 );


my $start = time();
my $jar = HTTP::Cookies::Mozilla->new( File => $dist_file );
my $time_delta = time() - $start;

isa_ok( $jar, 'HTTP::Cookies::Mozilla' );
my $result = $jar->save( $save_file );

my $diff = TestRelaxDiff::diff( $dist_file, $save_file, $time_delta );
my $same = not $diff;
ok( $same, 'Saved file is same as original' );
print STDERR $diff;

END { unlink $save_file }

done_testing();

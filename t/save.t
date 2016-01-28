use Test::More 0.98;
use Text::Diff;

use HTTP::Cookies::Mozilla;

my $class = 'HTTP::Cookies::Mozilla';
use_ok( $class );

my $dist_file = 't/cookies.txt';
my $save_file = 't/cookies2.txt';

my %Domains = qw( .ebay.com 2 .usatoday.com 3 );


# get cookie jar, attempt multiple times to be sure to operate in the
# same second (time-wise) so we can avoid race condition with
# HTTP::Cookies
my ($jar, $time_delta);
for my $attempt (1 .. 5) {
   my $start = time();
   $jar = HTTP::Cookies::Mozilla->new( File => $dist_file );
   $time_delta = time() - $start;
   last unless $time_delta > 0;
}

isa_ok( $jar, 'HTTP::Cookies::Mozilla' );

SKIP: {
   skip 'could not avoid race condition', 1
      if $time_delta > 0;

   my $result = $jar->save( $save_file );

   my $diff = Text::Diff::diff( $dist_file, $save_file );
   my $same = not $diff;
   ok( $same, 'Saved file is same as original' );
   print STDERR $diff;

};

END { unlink $save_file if $jar }

done_testing();

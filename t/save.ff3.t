use Test::More tests => 8;
use Text::Diff;

use HTTP::Cookies::Mozilla;

use lib 't';
use TestSqliteCmd;

my $dist_file = 't/cookies.sqlite';
my $save_file = 't/cookies2.sqlite';
my $txt_file1 = 't/cookies2.former';
my $txt_file2 = 't/cookies2.later';
END { -e $_ && unlink $_ for $save_file, $txt_file1, $txt_file2 }

SKIP: {
   eval {
      require DBI;
      require DBD::SQLite;
   } or skip('DBI/DBD::SQLite not installed', 4);
   check("DBI/DBD::SQLite");
} ## end SKIP:

SKIP: {    # FF3, using sqlite executable
   my ($prg, $error) = TestSqliteCmd::which_sqlite();
   skip($error, 4) unless $prg;

   $HTTP::Cookies::Mozilla::SQLITE = $prg;
   {       # force complaining from DBI
      no warnings;
      *DBI::connect = sub { die 'oops!' };
   }

   check("external program $prg");
} ## end SKIP:

sub check {
   my ($condition) = @_;

   my %Domains = qw( .ebay.com 2 .usatoday.com 3 );

   # get cookie jar, attempt multiple times to be sure to operate in the
   # same second (time-wise) so we can avoid race condition with
   # HTTP::Cookies
   my ($jar, $time_delta_1);
   for my $attempt (1 .. 5) {
      my $start = time();
      $jar = HTTP::Cookies::Mozilla->new(File => $dist_file);
      $time_delta_1 = time() - $start;
      last unless $time_delta_1;
   }

   isa_ok($jar, 'HTTP::Cookies::Mozilla');

   my $result = $jar->save($save_file);
   ok(-s $save_file, "something was saved, actually ($condition)");

   # attempt multiple times too
   my ($jar2, $time_delta_2);
   for my $attempt (1 .. 5) {
      my $start = time();
      $jar2 = HTTP::Cookies::Mozilla->new(File => $save_file);
      $time_delta_2 = time() - $start;
      last unless $time_delta_2;
   }

   isa_ok($jar2, 'HTTP::Cookies::Mozilla');

   SKIP: {
      skip 'could not avoid race condition', 1
         if ($time_delta_1 + $time_delta_2) > 0;

      $jar->save($txt_file1);
      $jar2->save($txt_file2);

      my $diff = Text::Diff::diff($txt_file1, $txt_file2);
      my $same = not $diff;
      ok($same, "Saved file is same as original ($condition)");
      print STDERR $diff;
   };


   # clean up for next call to check, if any
   -e $_ && unlink $_ for $save_file, $txt_file1, $txt_file2;

   return;
}

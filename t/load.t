# $Id$

use Test::More tests => 15;

use HTTP::Cookies::Mozilla;
use Data::Dumper;

my %Domains = qw( .ebay.com 2 .usatoday.com 3 );

check('t/cookies.txt');

SKIP: {    # FF3, using DBI
   eval {
      require DBI;
      require DBD::SQLite;
   } or skip('DBI/DBD::SQLite not installed', 5);
   check('t/cookies.sqlite');
} ## end SKIP:

SKIP: {    # FF3, using sqlite executable
   my $prg = $ENV{SQLITE_PATH} || '/usr/bin/sqlite3';
   skip("$prg not executable", 5) unless -x $prg;

   {       # force complaining from DBI
      no warnings;
      *DBI::connect = sub { die 'oops!' };
   }

   check('t/cookies.sqlite');
} ## end SKIP:

sub check {
   my ($file) = @_;

   my $jar = HTTP::Cookies::Mozilla->new(File => $file);
   isa_ok($jar, 'HTTP::Cookies::Mozilla');

   my $hash = $jar->{COOKIES};

   my $domain_count = keys %$hash;
   is($domain_count, 2, 'Count of cookies');

   foreach my $domain (keys %Domains) {
      my $domain_hash = $hash->{$domain}{'/'};
      my $count       = keys %$domain_hash;
      is($count, $Domains{$domain}, "$domain has $count cookies");
   }

   is($hash->{'.ebay.com'}{'/'}{'lucky9'}[1],
      '88341', 'Cookie has right value');
} ## end sub check

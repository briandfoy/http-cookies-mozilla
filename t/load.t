use Test::More 1.0;

use lib 't';
use TestSqliteCmd;

my $class = 'HTTP::Cookies::Mozilla';
my %Domains = qw( .ebay.com 2 .usatoday.com 3 );

subtest 'sanity' => sub {
	use_ok $class;
	can_ok $class, 'new';

	check('t/cookies.txt', 'plain text');
	};

subtest 'dbi' => sub {
	eval { require DBI; require DBD::SQLite; } or
		plan skip_all => 'DBI/DBD::SQLite not installed';
	check('t/cookies.sqlite', 'DBI/DBD::SQLite');
	};


subtest 'sqlite' => sub {
	my( $prg, $error ) = TestSqliteCmd::which_sqlite();
	plan skip_all => $error unless $prg;

	no warnings qw(once);
	$HTTP::Cookies::Mozilla::SQLITE = $prg;
	{       # force complaining from DBI
      no warnings;
      *DBI::connect = sub { die 'oops!' };
	}

   check('t/cookies.sqlite', "external program $prg");
   };

done_testing();

sub check {
	my( $file, $condition ) = @_;

	my $jar = $class->new(File => $file);
	isa_ok $jar, $class;

	my $hash = $jar->{COOKIES};

	my $domain_count = keys %$hash;
	is $domain_count, 3, "Count of cookies ($condition)";

	foreach my $domain (keys %Domains) {
		my $domain_hash = $hash->{$domain}{'/'};
		my $count       = keys %$domain_hash;
		is $count, $Domains{$domain}, "$domain has $count cookies ($condition)";
		}

	is $hash->{'.ebay.com'}{'/'}{'lucky9'}[1],
		'88341', "Cookie has right value ($condition)";
	}

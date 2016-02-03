use v5.10;

use Test::More;
use strict;
use warnings;

use Data::Dumper;
use File::Basename;
use File::Spec::Functions qw(catfile);
use HTTP::Cookies::Mozilla;

use lib 't';
use TestSqliteCmd;

subtest plain_text => sub {
	my $file = catfile( qw(t cookies.txt) );
	ok( -e $file, "$file exists" );
	check( $file );
	};

subtest using_dbi => sub {
		SKIP: {    # FF3, using DBI
		   eval {
			  require DBI;
			  require DBD::SQLite;
			  1;
		   } or skip('DBI/DBD::SQLite not installed', 5);
		   check( catfile( qw( t cookies.sqlite) ) );
		}
	};

subtest using_sqlite => sub {
		SKIP: {    # FF3, using sqlite executable
			my( $sqlite, $error ) = TestSqliteCmd::which_sqlite();
			diag( "sqlite TestSqliteCmd from is $sqlite" );
			skip($error, 5) unless $sqlite;

			no strict 'refs';
			no warnings 'redefine';
			local *{ "HTTP::Cookies::Mozilla::_has_dbi" } = sub { 0 };
			local *{ "HTTP::Cookies::Mozilla::_has_ipc_system_simple" } = sub { 0 };

			HTTP::Cookies::Mozilla->sqlite( $sqlite );
			is(
				basename( HTTP::Cookies::Mozilla->sqlite() ), $sqlite,
				"Set sqlite location correctly"
				);

			my $sqlite_path = HTTP::Cookies::Mozilla->sqlite();
			diag( "sqlite_path is $sqlite_path" );

			ok( -e $sqlite_path, "sqlite exists (found at $sqlite_path)" );
			ok( -x $sqlite_path, "sqlite is executable" );

			HTTP::Cookies::Mozilla->sqlite( $sqlite );
			is(
				basename( HTTP::Cookies::Mozilla->sqlite() ), $sqlite,
				"Set sqlite location correctly"
				);

			check( catfile( qw( t cookies.sqlite) ) );
		} ## end SKIP:
	};

sub check {
	state $Domains = { '.ebay.com' => 2, '.usatoday.com' => 3 };
	my( $file ) = @_;

	my $cookie_jar = HTTP::Cookies::Mozilla->new(File => $file);
	isa_ok( $cookie_jar, 'HTTP::Cookies::Mozilla' );

	my %found;
	$cookie_jar->scan( sub {
		my @data = @_;

		# 4: domain 3: path 1: name 2: value
		$found{ $data[4] }{ $data[3] }{ $data[1] } = $data[2];
		}
		);

	is( scalar keys %$Domains, 2, "Count of domains");

	foreach my $domain (keys %$Domains) {
		my $domain_hash = $found{$domain}{'/'};
		my $count       = keys %$domain_hash;
		is($count, $Domains->{$domain}, "$domain has $count cookies");
		}

	is($found{'.ebay.com'}{'/'}{'lucky9'}, '88341', "ebay.com lucky9 cookie has right value");
	}

done_testing();

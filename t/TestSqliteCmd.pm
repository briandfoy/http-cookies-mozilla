package TestSqliteCmd;
use v5.10;

use strict;
use warnings;

use Carp qw(croak);
use File::Which qw(which);

sub which_sqlite {
	my $sqlite = $ENV{SQLITE_PATH} || which('sqlite3');

	my $version = do {;
		unless( $^O eq 'MSWin32' ) {
			# this part doesn't work on Windows
			open my $fh, '-|', $sqlite, '-version'
				or return (undef, "no pipe to $sqlite");
			chomp( my $version = <$fh> );
			$version;
			}
		else { # Windows, so untaint
			croak "Bad path for SQLite [$sqlite]"
				unless $sqlite =~ m/\A [a-z0-9\._\-\\\/]+ \z /x;
			`$sqlite -version`;
			}
		};

	return (undef, "could not read $sqlite version") unless $version;

	if( $version =~ /\A ([0-9]+) /x ) {
		my $major = $1;
		return ( undef, "need sqlite to be at least version 3" )
			unless $major >= 3;
		}
	else {
		return ( undef, "no suitable version in $sqlite" );
		}

	return ( $sqlite, undef );
	}

1;

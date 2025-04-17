use v5.8;
package HTTP::Cookies::Mozilla;
use strict;

use warnings;
no warnings;

=encoding utf8

=head1 NAME

HTTP::Cookies::Mozilla - Cookie storage and management for Mozilla

=head1 SYNOPSIS

	use HTTP::Cookies::Mozilla;

	# see "SQLite access notes"
	my $file = ...; # Firefox profile dir / cookies.sqlite
	my $cookie_jar = HTTP::Cookies::Mozilla->new( file => $file );

	# otherwise same as HTTP::Cookies

=head1 DESCRIPTION

This package overrides the C<load()> and C<save()> methods of
L<HTTP::Cookies> so it can work with Mozilla cookie files. These might
be stored in the user profile directory as F<cookies>. On macOS,for
instance, that's F<~/Application Support/Firefox/*/cookies.sqlite>.

This module should be able to work with all Mozilla derived browsers
(FireBird, Camino, et alia).

Note that as of FireFox, version 3, the cookie file format changed
from plain text files to SQLite databases, so you will need to have
either L<DBI>/L<DBD::SQLite>, or the B<sqlite3> executable somewhere
in the path. Neither one has been put as explicit dependency, anyway,
so you'll get an exception if you try to use this module with a new
style file but without having any of them:

   neither DBI nor pipe to sqlite3 worked (%s), install either one

If your command-line B<sqlite3> is not in the C<$ENV{PATH}>, you can
set C<$HTTP::Cookies::Mozilla::SQLITE> to point to the actual program
to be used, e.g.:

   use HTTP::Cookies::Mozilla;
   $HTTP::Cookies::Mozilla::SQLITE = '/path/to/sqlite3';

Usage of the external program is supported under perl 5.8 onwards only,
because previous perl versions do not support L<perlfunc/open> with
more than three arguments, which are safer. If you are still sticking
to perl 5.6, you'll have to install L<DBI>/L<DBD::SQLite> to make
FireFox 3 cookies work.

=head2 SQLite access notes

SQLite allows a connection to lock the database for exclusive use, and
Firefox does this. If a browser is running, it probably has an
exclusive lock on the database file.

If you want to add cookies that the browser will see, you need to add
the cookies to the file that the browser would use. You can't add to
that while the browser is running because the database is locked, but
if you copy the file and try to replace it, you can miss updates that
the browser makes when it closes. You have to coordinate that yourself.

If you just want to read it, you may have to copy the file to another
location then use that.

=head2 Privacy settings

Firefox has a setting to erase all cookie and session data on quit.
With this set, all of your cookies will disappear, even if the expiry
times are in the future. Look in settings under "Privacy & Security"

=head2 Cookie data

Firefox tracks more information than L<HTTP::Cookies> tracks. So far
this module tracks host, path, name, value, and expiry because these are
the columns common among the different modules:

=over 4

=item * id (no support) - primary key row

=item * originAttributes (no support) - something about containers

=item * name (supported)

=item * value (supported)

=item * host (supported)

=item * path (supported)

=item * expiry (supported)

=item * lastAccessed (no support)

=item * creationTime (no support)

=item * isSecure (supported)

=item * isHttpOnly (no support)

=item * isBrowserElement (no support)

=item * sameSite (no support)

=item * rawSameSite (no support)

=item * rawSameSite (no support)

=back

=head1 SEE ALSO

=over 4

=item * L<HTTP::Cookies>.

=back

=head1 SOURCE AVAILABILITY

The source is in GitHub:

	https://github.com/briandfoy/http-cookies-mozilla

=head1 AUTHOR

Derived from Gisle Aas's HTTP::Cookies::Netscape package with very
few material changes.

Flavio Poletti added the SQLite support.

Maintained by brian d foy, C<< <briandfoy@pobox.com> >>

=head1 COPYRIGHT AND LICENSE

Parts Copyright 1997-1999 Gisle Aas.

Other parts Copyright 2018-2025 by brian d foy, C<< <briandfoy@pobox.com> >>

This library is free software; you can redistribute it and/or modify
it under the terms of the Artistic License 2.0.

=cut

use base qw( HTTP::Cookies );
use vars qw( $VERSION $SQLITE );

use Carp qw(carp);
use DBD::SQLite::Constants qw/:file_open/;

use constant TRUE  => 'TRUE';
use constant FALSE => 'FALSE';

$VERSION = '3.002';
$SQLITE = 'sqlite3';

sub _load_ff3 {
	my ($self, $file) = @_;
	my $cookies;
	my $query = 'SELECT host, path, name, value, isSecure, expiry FROM moz_cookies';

	eval {
		require DBI;
		my $dbh = DBI->connect('dbi:SQLite:dbname=' . $file, '', '', { RaiseError => 1, } );

		$cookies = $dbh->selectall_arrayref($query);
		$dbh->disconnect();
		1;
		}
	or eval {
		open my $fh, '-|', $SQLITE, $file, $query or die $!;
		$cookies = [ map { [ split /\|/ ] } <$fh> ];
		1;
		}
	or do {
		carp "neither DBI nor pipe to sqlite3 worked ($@), install either one";
		return;
		};

	for my $cookie ( @$cookies ) {
		my( $domain, $path, $key, $val, $secure, $expires ) = @$cookie;

		$self->set_cookie( undef, $key, $val, $path, $domain, undef,
		   0, $secure, $expires - _now(), 0 );
		}

	return 1;
}

sub load {
	my( $self, $file ) = @_;

	$file ||= $self->{'file'} || do {
		carp "load() did not get a filename!";
		return;
		};

	return $self->_load_ff3($file) if $file =~ m{\.sqlite}i;

	local $_;
	local $/ = "\n";  # make sure we got standard record separator

	my $fh;
	unless( open $fh, '<:utf8', $file ) {
		carp "Could not open file [$file]: $!";
		return;
		}

	my $magic = <$fh>;

	unless( $magic =~ /^\# HTTP Cookie File/ ) {
		carp "$file does not look like a Mozilla cookies file";
		close $fh;
		return;
		}

	while( <$fh> ) {
		next if /^\s*\#/;
		next if /^\s*$/;
		tr/\n\r//d;

		my( $domain, $bool1, $path, $secure, $expires, $key, $val )
		   = split /\t/;

		$secure = ( $secure eq TRUE );

		# The cookie format is an absolute time in epoch seconds, so
		# we subtract the current time (with appropriate offsets) to
		# get the max_age for the second-to-last argument.
		$self->set_cookie( undef, $key, $val, $path, $domain, undef,
		    0, $secure, $expires - _now(), 0 );
		}

	close $fh;

	1;
	}

BEGIN {
	my $EPOCH_OFFSET = $^O eq "MacOS" ? 21600 : 0;  # difference from Unix epoch
	sub _epoch_offset { $EPOCH_OFFSET }
	}

sub _now { time() - _epoch_offset() };

sub _scansub_maker {  # Encapsulate checks logic during cookie scan
	my ($self, $coresub) = @_;

	return sub {
		my( $version, $key, $val, $path, $domain, $port,
		    $path_spec, $secure, $expires, $discard, $rest ) = @_;

		return if $discard && not $self->{ignore_discard};

		$expires = $expires ? $expires - _epoch_offset() : 0;
		return if defined $expires && _now() > $expires;

		return $coresub->($domain, $path, $key, $val, $secure, $expires);
		};
	}

sub _save_ff3 {
	my ($self, $file) = @_;

	my @fnames = qw( host path name value isSecure expiry );
	my $fnames = join ', ', @fnames;

	eval {
		require DBI;
		my $dbh = DBI->connect('dbi:SQLite:dbname=' . $file, '', '',
		   {RaiseError => 1, AutoCommit => 0});

		$dbh->do('DROP TABLE IF EXISTS moz_cookies;');

		$dbh->do(<<'SQL');
CREATE TABLE moz_cookies (
	id INTEGER PRIMARY KEY,
	originAttributes TEXT NOT NULL DEFAULT '',
	name TEXT,
	value TEXT,
	host TEXT,
	path TEXT,
	expiry INTEGER,
	lastAccessed INTEGER,
	creationTime INTEGER,
	isSecure INTEGER,
	isHttpOnly INTEGER,
	inBrowserElement INTEGER DEFAULT 0,
	sameSite INTEGER DEFAULT 0,
	rawSameSite INTEGER DEFAULT 0,
	schemeMap INTEGER DEFAULT 0,
	isPartitionedAttributeSet INTEGER DEFAULT 0,
CONSTRAINT moz_uniqueid UNIQUE (
	name,
	host,
	path,
	originAttributes
))
SQL
		{ # restrict scope for $sth
		my $pholds = join ', ', ('?') x @fnames;
		my $sth = $dbh->prepare(
		    "INSERT INTO moz_cookies($fnames) VALUES ($pholds)");
		$self->scan($self->_scansub_maker(
			sub {
				my( $domain, $path, $key, $val, $secure, $expires ) = @_;
				$secure = $secure ? 1 : 0;
				$sth->execute($domain, $path, $key, $val, $secure, $expires);
				}
				)
			);
		$sth->finish();
		}

		$dbh->commit();
		$dbh->disconnect();
		1;
		}
	or eval {
		open my $fh, '|-', $SQLITE, $file or die $!;
		print {$fh} <<'INCIPIT';
BEGIN TRANSACTION;

DROP TABLE IF EXISTS moz_cookies;
CREATE TABLE moz_cookies (
	id INTEGER PRIMARY KEY,
	originAttributes TEXT NOT NULL DEFAULT '',
	name TEXT,
	value TEXT,
	host TEXT,
	path TEXT,
	expiry INTEGER,
	lastAccessed INTEGER,
	creationTime INTEGER,
	isSecure INTEGER,
	isHttpOnly INTEGER,
	inBrowserElement INTEGER DEFAULT 0,
	sameSite INTEGER DEFAULT 0,
	rawSameSite INTEGER DEFAULT 0,
	schemeMap INTEGER DEFAULT 0,
	isPartitionedAttributeSet INTEGER DEFAULT 0,
CONSTRAINT moz_uniqueid UNIQUE (
	name,
	host,
	path,
	originAttributes
));
INCIPIT

		$self->scan( $self->_scansub_maker(
			sub {
				my( $domain, $path, $key, $val, $secure, $expires ) = @_;
				$secure = $secure ? 1 : 0;
				my $values = join ', ',
					map {  # Encode all params as hex, a bit overkill
					my $hex = unpack 'H*', $_;
					"X'$hex'";
					} ( $domain, $path, $key, $val, $secure, $expires );
				print {$fh}
					"INSERT INTO moz_cookies( $fnames ) VALUES ( $values );\n";
				}
			)
		);

		print {$fh} <<'EPILOGUE';

UPDATE moz_cookies SET lastAccessed = id;
END TRANSACTION;

EPILOGUE
	1;
	}
	or do {
		carp "neither DBI nor pipe to sqlite3 worked ($@), install either one";
		return;
	};

	return 1;
}

sub save {
	my( $self, $file ) = @_;

	$file ||= $self->{'file'} || do {
		carp "save() did not get a filename!";
		return;
		};

	return $self->_save_ff3($file) if $file =~ m{\. sqlite}imsx;

	local $_;

	my $fh;
	unless( open $fh, '>:utf8', $file ) {
		carp "Could not open file [$file]: $!";
		return;
		}

	print $fh <<'EOT';
# HTTP Cookie File
# http://www.netscape.com/newsref/std/cookie_spec.html
# This is a generated file!  Do not edit.
# To delete cookies, use the Cookie Manager.

EOT

	$self->scan($self->_scansub_maker(
		sub {
			my( $domain, $path, $key, $val, $secure, $expires ) = @_;
			$secure = $secure ? TRUE : FALSE;
			my $bool = $domain =~ /^\./ ? TRUE : FALSE;
			print $fh join( "\t", $domain, $bool, $path, $secure,
				$expires, $key, $val ), "\n";
			}
			)
		);

	close $fh;

	1;
	}

1;

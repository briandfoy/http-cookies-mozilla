# $Id$
package HTTP::Cookies::Mozilla;
use strict;

use warnings;
no warnings;

=head1 NAME

HTTP::Cookies::Mozilla - Cookie storage and management for Mozilla

=head1 SYNOPSIS

	use HTTP::Cookies::Mozilla;

	$cookie_jar = HTTP::Cookies::Mozilla->new;

	# otherwise same as HTTP::Cookies

=head1 DESCRIPTION

This package overrides the load() and save() methods of HTTP::Cookies
so it can work with Mozilla cookie files.

This module should be able to work with all Mozilla derived browsers
(FireBird, Camino, et alia).

See L<HTTP::Cookies>.

=head1 SOURCE AVAILABILITY

This source is part of a SourceForge project which always has the
latest sources in CVS, as well as all of the previous releases.

	http://sourceforge.net/projects/brian-d-foy/

If, for some reason, I disappear from the world, one of the other
members of the project can shepherd this module appropriately.

=head1 AUTHOR

Derived from Gisle Aas's HTTP::Cookies::Netscape package with very
few material changes.

maintained by brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright 1997-1999 Gisle Aas

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

use base qw( HTTP::Cookies );
use vars qw( $VERSION $SQLITE );

use Carp qw(carp);

use constant TRUE  => 'TRUE';
use constant FALSE => 'FALSE';

$VERSION = 1.13;
$SQLITE = 'sqlite3';

my $EPOCH_OFFSET = $^O eq "MacOS" ? 21600 : 0;  # difference from Unix epoch

sub _load_ff3 {
   my ($self, $file) = @_;
   my $cookies;
   my $query = 'SELECT host, path, name, value, isSecure, expiry '
      . ' FROM moz_cookies';
   eval {
      require DBI;
      my $dbh = DBI->connect('dbi:SQLite:dbname=' . $file, '', '',
         {RaiseError => 1});
      $cookies = $dbh->selectall_arrayref($query);
      $dbh->disconnect();
      1;
   } or eval {
      open my $fh, '-|', $SQLITE, $file, $query or die $!;
      $cookies = [ map { [ split /\|/ ] } <$fh> ];
      1;
   } or do {
      carp "neither DBI nor pipe to sqlite3 worked ($@), install either one";
      return;
   };

	my $now = time() - $EPOCH_OFFSET;

	for my $cookie ( @$cookies )
		{
		my( $domain, $path, $key, $val, $secure, $expires )
         = @$cookie;

		$self->set_cookie( undef, $key, $val, $path, $domain, undef,
			0, $secure, $expires - $now, 0 );
		}

   return 1;
}

sub load
	{
	my( $self, $file ) = @_;

	$file ||= $self->{'file'} || return;

   return $self->_load_ff3($file) if $file =~ m{\. sqlite}imsx;

	local $_;
	local $/ = "\n";  # make sure we got standard record separator

	my $fh;
    unless( open $fh, $file )
		{
		carp "Could not open file [$file]: $!";
		return;
		}

    my $magic = <$fh>;

	unless( $magic =~ /^\# HTTP Cookie File/ )
		{
		carp "$file does not look like a Mozilla cookies file";
		close $fh;
		return;
		}

	my $now = time() - $EPOCH_OFFSET;

	while( <$fh> )
		{
		next if /^\s*\#/;
		next if /^\s*$/;
		tr/\n\r//d;

		my( $domain, $bool1, $path, $secure, $expires, $key, $val )
			= split /\t/;

		$secure = ( $secure eq TRUE );

		$self->set_cookie( undef, $key, $val, $path, $domain, undef,
			0, $secure, $expires - $now, 0 );
		}

	close $fh;

	1;
	}

sub _scansub_maker {  # Encapsulate checks logic during cookie scan
   my ($self, $coresub) = @_;

	my $now = time - $EPOCH_OFFSET;

   return sub {
      my( $version, $key, $val, $path, $domain, $port,
         $path_spec, $secure, $expires, $discard, $rest ) = @_;

      return if $discard && not $self->{ignore_discard};

      $expires = $expires ? $expires - $EPOCH_OFFSET : 0;
      return if defined $expires && $now > $expires;

      return $coresub->($domain, $path, $key, $val, $secure, $expires);
   }
}

sub _save_ff3 {
   my ($self, $file) = @_;

	my $now = time - $EPOCH_OFFSET;
   my @fnames = qw( host path name value isSecure expiry );
   my $fnames = join ', ', @fnames;

   eval {
      require DBI;
      my $dbh = DBI->connect('dbi:SQLite:dbname=' . $file, '', '',
         {RaiseError => 1, AutoCommit => 0});

      $dbh->do('DROP TABLE IF EXISTS moz_cookies;');
   
      $dbh->do('CREATE TABLE moz_cookies '
         . ' (id INTEGER PRIMARY KEY, name TEXT, value TEXT, host TEXT,'
         . '  path TEXT,expiry INTEGER, lastAccessed INTEGER, '
         . '  isSecure INTEGER, isHttpOnly INTEGER);');

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
   } or eval {
      open my $fh, '|-', $SQLITE, $file or die $!;
      print {$fh} <<'INCIPIT';

BEGIN TRANSACTION;

DROP TABLE IF EXISTS moz_cookies;
CREATE TABLE moz_cookies 
   (id INTEGER PRIMARY KEY, name TEXT, value TEXT, host TEXT,
    path TEXT,expiry INTEGER, lastAccessed INTEGER, 
    isSecure INTEGER, isHttpOnly INTEGER);

INCIPIT

      $self->scan($self->_scansub_maker(
            sub {
               my( $domain, $path, $key, $val, $secure, $expires ) = @_;

               $secure = $secure ? 1 : 0;

               my $values = join ', ',
                  map {  # Encode all params as hex, a bit overkill
                     my $hex = unpack 'H*', $_;
                     "X'$hex'"; 
                  } $domain, $path, $key, $val, $secure, $expires;

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
   } or do {
      carp "neither DBI nor pipe to sqlite3 worked ($@), install either one";
      return;
   };

   return 1;
}

sub save
	{
	my( $self, $file ) = @_;

	$file ||= $self->{'file'} || return;

   return $self->_save_ff3($file) if $file =~ m{\. sqlite}imsx;

	local $_;

	my $fh;
	unless( open $fh, "> $file" )
		{
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

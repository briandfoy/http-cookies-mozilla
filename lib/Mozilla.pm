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
use vars qw( $VERSION );

use Carp qw(carp);

use constant TRUE  => 'TRUE';
use constant FALSE => 'FALSE';

$VERSION = 1.12;

my $EPOCH_OFFSET = $^O eq "MacOS" ? 21600 : 0;  # difference from Unix epoch

sub load
	{
	my( $self, $file ) = @_;

	$file ||= $self->{'file'} || return;

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

sub save
	{
	my( $self, $file ) = @_;

	$file ||= $self->{'file'} || return;

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

	my $now = time - $EPOCH_OFFSET;

	$self->scan(
		sub {
			my( $version, $key, $val, $path, $domain, $port,
				$path_spec, $secure, $expires, $discard, $rest ) = @_;

			return if $discard && not $self->{ignore_discard};

			$expires = $expires ? $expires - $EPOCH_OFFSET : 0;

			return if defined $expires && $now > $expires;

			$secure = $secure ? TRUE : FALSE;

			my $bool = $domain =~ /^\./ ? TRUE : FALSE;

			print $fh join( "\t", $domain, $bool, $path, $secure,
				$expires, $key, $val ), "\n";
			}
		);

	close $fh;

	1;
	}

1;

# $Id$

use Test::More tests => 5;

use HTTP::Cookies::Mozilla;
use Data::Dumper;

my %Domains = qw( .ebay.com 2 .usatoday.com 3 );

my $jar = HTTP::Cookies::Mozilla->new( File => 't/cookies.txt' );
isa_ok( $jar, 'HTTP::Cookies::Mozilla' );

my $hash = $jar->{COOKIES};

my $domain_count = keys %$hash;
is( $domain_count, 2, 'Count of cookies' );

foreach my $domain ( keys %Domains )
	{
	my $domain_hash  = $hash->{ $domain }{ '/' };
	my $count        = keys %$domain_hash;
	is( $count, $Domains{$domain}, "$domain has $count cookies" ); 	
	}

is( $hash->{'.ebay.com'}{'/'}{'lucky9'}[1], '88341', 'Cookie has right value' );
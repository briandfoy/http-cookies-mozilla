use Test::More 0.98;

foreach my $class ( "HTTP::Cookies::Mozilla" ) {
	BAIL_OUT( "$class did not compile" ) unless use_ok( $class );
	}

done_testing();

# $Id$
use ExtUtils::MakeMaker;

sub ExtUtils::MM_Any::test_via_harness
		{
		my($self, $perl, $tests) = @_;

		return qq|\t$perl "-MTest::Manifest" | .
			qq|"-e" "run_t_manifest(\$(TEST_VERBOSE), '\$(INST_LIB)', | .
			qq|'\$(INST_ARCHLIB)')"\n|;
		}

WriteMakefile
        (
        'NAME'           => 'HTTP::Cookies::Mozilla',
        'VERSION_FROM'   => 'lib/Mozilla.pm',
 		'PREREQ_PM'      => {
 			'File::Find::Rule'      => '0',
 			'HTTP::Cookies'         => '1.25',
 			'Test::Manifest'        => '0.9',
 			'Test::More'            => '0',
 			'Test::Pod'             => '0.72',
 			'Test::Prereq'          => '0.18',
 			'Text::Diff'            => '0',
 			},
        'PM'             => {
            'lib/Mozilla.pm' => '$(INST_LIBDIR)/Mozilla.pm',
            },
		'MAN3PODS'		 => {
			'lib/Mozilla.pm' => '$(INST_MAN3DIR)/HTTP::Cookies::Mozilla.3',
			},

		clean => { FILES => 'HTTP-Cookies-Mozilla-*' },
        );


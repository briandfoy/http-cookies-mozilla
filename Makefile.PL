# $Id$
use ExtUtils::MakeMaker;

require 5.006;

eval "use Test::Manifest 1.14";
	
WriteMakefile
	(
	'NAME'           => 'HTTP::Cookies::Mozilla',
	'ABSTRACT'       => 'Cookie storage and management for Mozilla',
	'VERSION_FROM'   => 'lib/Mozilla.pm',
	'LICENSE'        => 'perl',
	'AUTHOR'		 => 'brian d foy <bdfoy@cpan.org>',
	
	'PREREQ_PM'      => {
		'HTTP::Cookies'         => '1.25',
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


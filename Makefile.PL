# $Id: Makefile.PL,v 1.8 2001/06/27 16:10:19 wsnyder Exp $
# DESCRIPTION: Perl ExtUtils: Type 'perl Makefile.PL' to create a Makefile for this package

use ExtUtils::MakeMaker;
use Carp;

sub MY::postamble {
"
README: readme.texi
	-rm \$@
	makeinfo \$< --output \$@ --no-headers --no-validate

maintainer-clean: distclean
	-rm README Makefile

dist: distcheck README

install::
	echo \"MANUALLY: cp vregs-mode.el YOUR_SITE_LISP_PATH\"

install-local: manifypods
	cp -R blib/man* /usr/local/common/man
	cp vregs-mode.el /usr/local/common/site-lisp

tag:
	cvs tag -F \$(DISTNAME)_\$(VERSION_SYM) .
";
}

WriteMakefile(
	      NAME      => 'SystemC::Vregs',
	      AUTHOR	=> 'Wilson Snyder <wsnyder@wsnyder.org>',
	      ABSTRACT  => 'Extract C++/Verilog Enum and Classes from html documents',
	      VERSION_FROM  => 'Vregs.pm',
	      EXE_FILES => [qw( vregs )],
	      PREREQ_PM => {'HTML::TableExtract' => 0,
			    'Bit::Vector' => 0,
			    'Verilog::Language' => 1.12,
			},
	      'clean'	=> {FILES => qw ( ),},
	      'dist'    => {COMPRESS => 'gzip -9f',
			    SUFFIX   => '.gz', 
			    DIST_DEFAULT => 'README all tardist',
			},
	      );


# $Revision: #16 $$Date: 2004/01/27 $$Author: wsnyder $
# DESCRIPTION: Perl ExtUtils: Type 'perl Makefile.PL' to create a Makefile for this package
#
# Copyright 2001-2004 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.

use ExtUtils::MakeMaker;
use Carp;

sub MY::postamble {
"
README: readme.texi
	-rm \$@
	makeinfo \$< --output \$@ --no-headers --no-validate

dist: distcheck README

install::
	echo \"MANUALLY: cp vregs-mode.el YOUR_SITE_LISP_PATH\"

install-local: manifypods
	cp -R blib/man* /usr/local/common/man
	cp vregs-mode.el /usr/local/common/site-lisp

clean::
	-rm -rf test_dir

## Maintainer use:
tag:
	p4 label -d     \$(DISTNAME)_\$(VERSION_SYM) || true
	p4 label        \$(DISTNAME)_\$(VERSION_SYM)
	p4 labelsync -l \$(DISTNAME)_\$(VERSION_SYM) ...
#	cvs tag -F \$(DISTNAME)_\$(VERSION_SYM) .

maintainer-clean: distclean
	-rm README Makefile

maintainer-dist: dist tag
	cp \$(DISTVNAME).tar.gz \$(HOME)/src/kits
	mv \$(DISTVNAME).tar.gz \$(HOME)/backpack

";
}

WriteMakefile(
	      NAME      => 'SystemC::Vregs',
	      AUTHOR	=> 'Wilson Snyder <wsnyder@wsnyder.org>',
	      ABSTRACT  => 'Extract C++/Verilog Enum and Classes from html documents',
	      VERSION_FROM  => 'Vregs.pm',
	      EXE_FILES => [qw( vreg )],
	      PREREQ_PM => {'HTML::TableExtract' => 0,
			    'HTML::Parser' => 0,   # Also needed by TableExtract
			    'Bit::Vector' => 0,
			    'Verilog::Language' => 1.12,
			},
	      'clean'	=> {FILES => qw ( ),},
	      'dist'    => {COMPRESS => 'gzip -9f',
			    SUFFIX   => '.gz', 
			    DIST_DEFAULT => 'README all tardist',
			},
	      );


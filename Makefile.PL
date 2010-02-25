# DESCRIPTION: Perl ExtUtils: Type 'perl Makefile.PL' to create a Makefile for this package
#
# Copyright 2001-2010 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License Version 3 or the Perl Artistic License Version 2.0.

use ExtUtils::MakeMaker;
use Carp;

sub MY::postamble {
q{
README: readme.texi
	-$(RM_RF) $@
	makeinfo $< --output $@ --no-headers --no-validate

dist: distcheck README

install::
	echo "MANUALLY: cp vregs-mode.el YOUR_SITE_LISP_PATH"

install-local: manifypods
	cp -R blib/man*  $(DIRPROJECT_PREFIX)/man
	cp vregs-mode.el $(DIRPROJECT_PREFIX)/site-lisp

clean::
	-$(RM_RF) test_dir

## Maintainer use:
preexist:
	svnorcvs nexists $(DISTNAME)_$(VERSION_SYM)
	test -s README

tag:
	svnorcvs tag  $(DISTNAME)_$(VERSION_SYM)

maintainer-diff:
	svnorcvs diff $(DISTNAME)_$(VERSION_SYM)

maintainer-clean: distclean
	-$(RM_RF) README Makefile

maintainer-dist: preexist dist tag
	svnorcvs release $(DISTVNAME).tar.gz
};
}

WriteMakefile(
	      NAME      => 'SystemC::Vregs',
	      AUTHOR	=> 'Wilson Snyder <wsnyder@wsnyder.org>',
	      ABSTRACT  => 'Extract C++/Verilog Enum and Classes from html documents',
	      VERSION_FROM  => 'Vregs.pm',
	      NO_META	=> 1,
	      EXE_FILES => [qw( vreg vreg_latex2html )],
	      PREREQ_PM => {'HTML::TableExtract' => 0,
			    'HTML::Parser' => 0,   # Also needed by TableExtract
			    'Bit::Vector' => 0,
			    'Pod::Usage' => 1.34,
			    'Verilog::Language' => 2.100,
			},
	      'clean'	=> {FILES => qw ( ),},
	      'dist'    => {COMPRESS => 'gzip -9f',
			    SUFFIX   => '.gz',
			    DIST_DEFAULT => 'README all tardist',
			},
	      );


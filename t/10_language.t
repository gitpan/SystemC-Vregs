#!/usr/bin/perl -w
# $Id: 10_language.t 29376 2007-01-02 14:50:38Z wsnyder $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2007 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.

use strict;
use Test;

BEGIN { plan tests => 10 }
BEGIN { require "t/test_utils.pl"; }

use SystemC::Vregs::Language;
ok(1);

test_common (filename=>"test_dir/foo.c",
	     language=>'C',
	     );
test_common (filename=>"test_dir/foo.cpp",
	     language=>'CPP',
	     );
test_common (filename=>"test_dir/foo.s",
	     language=>'Assembler',
	     );
test_common (filename=>"test_dir/foo.gas",
	     language=>'Gas',
	     );
test_common (filename=>"test_dir/foo.v",
	     language=>'Verilog',
	     );
test_common (filename=>"test_dir/foo.pl",
	     language=>'Perl',
	     );
test_common (filename=>"test_dir/foo.tcl",
	     language=>'Tcl',
	     );
test_common (filename=>"test_dir/foo.xml",
	     language=>'XML',
	     );
test_common (filename=>"test_dir/foo.lisp",
	     language=>'Lisp',
	     );

sub test_common {
    my $fh = SystemC::Vregs::Language->new
	(@_);
    print "Dumping ",$fh->language(),"\n";
    $fh->include_guard ("foo.c");
    $fh->comment ("This is a single comment line\n");
    $fh->comment ("This is a 3\nline\ncomment\n");
    $fh->define ("foo","bar","comment");
    $fh->print ("Normal code");
    $fh->close();
    ok(-r $fh->{filename});
}

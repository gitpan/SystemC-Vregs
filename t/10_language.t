#!/usr/bin/perl -w
# $Revision: 1.10 $$Date: 2004/12/04 20:13:30 $$Author: wsnyder $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2004 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.

use strict;
use Test;

BEGIN { plan tests => 7 }
BEGIN { require "t/test_utils.pl"; }

use SystemC::Vregs::Language;
ok(1);

test_common (filename=>"test_dir/foo.c",
	     language=>'C',
	     );
test_common (filename=>"test_dir/foo.s",
	     language=>'Assembler',
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

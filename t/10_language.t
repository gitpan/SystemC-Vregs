#!/usr/local/bin/perl -w
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package

use strict;
use Test;

BEGIN { plan tests => 6 }

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

sub test_common {
    my $fh = SystemC::Vregs::Language->new
	(@_);
    print "Dumping ",$fh->language(),"\n";
    $fh->include_guard ("foo.c");
    $fh->comment ("This is commented out\n");
    $fh->define ("foo","bar","comment");
    $fh->print ("Normal code");
    $fh->close();
    ok(-r $fh->{filename});
}

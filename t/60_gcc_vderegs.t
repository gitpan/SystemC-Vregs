#!/usr/bin/perl -w
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2010 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License Version 3 or the Perl Artistic License Version 2.0.

use strict;
use Test;

BEGIN { plan tests => 3 }
BEGIN { require "t/test_utils.pl"; }

print "Prep\n";
run_system ("cp t/60_gcc_vderegs.cpp test_dir/60_gcc_vderegs.cpp");
ok(1);

print "Compiling\n";
system ("cd test_dir && ${GCC} 60_gcc_vderegs.cpp -lreadline -lncurses -o vderegs");
if ($?) {
    skip("Compile problem with vderegs; vderegs won't be available.");
    skip("Compile problem with vderegs; vderegs won't be available.");
} else {
    ok(1);

    print "Running\n";
    run_system ("cd test_dir && echo 'q' | ./vderegs");
    ok(1);
}

#======================================================================
# Local Variables:
# compile-command: "cd .. ; t/60_gcc_vderegs.t"
# End:

#!/usr/bin/perl -w
# $Id: 60_gcc_vderegs.t 4305 2005-08-02 13:21:57Z wsnyder $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2005 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.

use strict;
use Test;

BEGIN { plan tests => 3 }
BEGIN { require "t/test_utils.pl"; }

print "Prep\n";
run_system ("cp t/60_gcc_vderegs.cpp test_dir/60_gcc_vderegs.cpp");
ok(1);

print "Compiling\n";
run_system ("cd test_dir && ${GCC} 60_gcc_vderegs.cpp -lreadline -o vderegs");
ok(1);

print "Running\n";
run_system ("cd test_dir && echo 'q' | ./vderegs");
ok(1);

#======================================================================
# Local Variables:
# compile-command: "cd .. ; t/60_gcc_vderegs.t"
# End:

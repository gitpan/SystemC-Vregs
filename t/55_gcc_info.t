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
run_system ("cp t/55_gcc_info.cpp test_dir/55_gcc_info.cpp");
ok(1);

print "Compiling\n";
run_system ("cd test_dir && ${GCC} 55_gcc_info.cpp -o 55_gcc_info");
ok(1);

print "Running\n";
run_system ("cd test_dir && ./55_gcc_info");
ok(1);

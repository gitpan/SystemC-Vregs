#!/usr/bin/perl -w
# $Id: 50_gcc_hdr.t 15289 2006-03-06 15:45:36Z wsnyder $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2006 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.

use strict;
use Test;

BEGIN { plan tests => 3 }
BEGIN { require "t/test_utils.pl"; }

print "Prep\n";
run_system ("cp t/50_gcc_hdr.cpp test_dir/50_gcc_hdr.cpp");
ok(1);

print "Compiling\n";
run_system ("cd test_dir && ${GCC} 50_gcc_hdr.cpp -o 50_gcc_hdr");
ok(1);

print "Running\n";
run_system ("cd test_dir && ./50_gcc_hdr");
ok(1);

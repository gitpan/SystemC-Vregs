#!/usr/local/bin/perl -w
# $Revision: #5 $$Date: 2002/07/16 $$Author: wsnyder $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package

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

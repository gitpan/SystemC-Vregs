#!/usr/local/bin/perl -w
# $Id: 55_gcc_info.t,v 1.3 2002/03/11 14:07:22 wsnyder Exp $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package

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

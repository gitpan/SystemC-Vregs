#!/usr/bin/perl -w
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2009 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License Version 3 or the Perl Artistic License Version 2.0.

use strict;
use Test;

BEGIN { plan tests => 3 }
BEGIN { require "t/test_utils.pl"; }

print "Prep\n";
run_system ("cp t/51_gcc_str.c test_dir/51_gcc_str.c");
ok(1);

print "Compiling\n";
run_system ("cd test_dir && ${GCCC} -Dbool=char 51_gcc_str.c -o 51_gcc_str");
ok(1);

print "Running\n";
run_system ("cd test_dir && ./51_gcc_str");
ok(1);

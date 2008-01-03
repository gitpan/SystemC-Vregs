#!/usr/bin/perl -w
# $Id: 51_gcc_str.t 49231 2008-01-03 16:53:43Z wsnyder $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2008 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.

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

#!/usr/local/bin/perl -w
# $Revision: #1 $$Date: 2002/09/16 $$Author: lab $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package

use strict;
use Test;

BEGIN { plan tests => 3 }
BEGIN { require "t/test_utils.pl"; }

use SystemC::Vregs;
ok(1);

print "Checking vregs...\n";
run_system ("${PERL} ./vreg --rm --headers"
	    ." --package vregs_spec"
	    ." --rules vregs_spec__rules.pl"
	    ." --output test_dir");
ok(1);

eval "require 'test_dir/vregs_spec_defs.pm';1;";
ok(!$@);

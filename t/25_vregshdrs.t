#!/usr/local/bin/perl -w
# $Id: 25_vregshdrs.t,v 1.5 2002/03/11 14:07:22 wsnyder Exp $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package

use strict;
use Test;

BEGIN { plan tests => 3 }
BEGIN { require "t/test_utils.pl"; }

use SystemC::Vregs;
ok(1);

print "Checking vregs...\n";
run_system ("${PERL} ./vregs --rm --headers"
	    ." --package vregs_spec"
	    ." --rules vregs_spec__rules.pl"
	    ." --output test_dir");
ok(1);

eval "require 'test_dir/vregs_spec_defs.pm';1;";
ok(!$@);

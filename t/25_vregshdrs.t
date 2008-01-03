#!/usr/bin/perl -w
# $Id: 25_vregshdrs.t 49231 2008-01-03 16:53:43Z wsnyder $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2008 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.

use strict;
use Test;
use Config;

BEGIN { plan tests => 3 }
BEGIN { require "t/test_utils.pl"; }

use SystemC::Vregs;
ok(1);

print "Checking vregs...\n";
run_system ("${PERL} ./vreg --rm --headers"
	    ." --package vregs_spec"
	    ." --rules vregs_spec__rules.pl"
	    ." --v2k"
	    ." --output test_dir");
ok(1);

if (!$Config{use64bitint}
    || $Config{use64bitint} eq 'undef') {
    skip("not a 64 bit Perl, no vregs.pm check (harmless)",1);
} else {
    eval "require 'test_dir/vregs_spec_defs.pm';1;";
    ok(!$@);
}

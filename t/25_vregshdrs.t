#!/usr/bin/perl -w
# $Id: 25_vregshdrs.t 29376 2007-01-02 14:50:38Z wsnyder $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2007 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.

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
	    ." --v2k"
	    ." --output test_dir");
ok(1);

eval "require 'test_dir/vregs_spec_defs.pm';1;";
ok(!$@);

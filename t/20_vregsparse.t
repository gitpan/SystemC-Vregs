#!/usr/bin/perl -w
# $Revision: 1.10 $$Date: 2004-12-04 15:13:30 -0500 (Sat, 04 Dec 2004) $$Author: wsnyder $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2004 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.

use strict;
use Test;

BEGIN { plan tests => 2 }
BEGIN { require "t/test_utils.pl"; }

use SystemC::Vregs;
ok(1);

print "Checking vregs...\n";
run_system ("${PERL} ./vreg --rm --html vregs_spec.htm"
	    ." --noheaders --package vregs_spec --output test_dir");
ok(1);

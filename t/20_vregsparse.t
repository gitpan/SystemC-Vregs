#!/usr/local/bin/perl -w
# $Id: 20_vregsparse.t,v 1.4 2002/03/11 14:07:22 wsnyder Exp $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package

use strict;
use Test;

BEGIN { plan tests => 2 }
BEGIN { require "t/test_utils.pl"; }

use SystemC::Vregs;
ok(1);

print "Checking vregs...\n";
run_system ("${PERL} ./vregs --rm --html vregs_spec.htm"
	    ." --noheaders --package vregs_spec --output test_dir");
ok(1);

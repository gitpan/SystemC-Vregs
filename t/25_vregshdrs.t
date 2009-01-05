#!/usr/bin/perl -w
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2009 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License or the Perl Artistic License.

use strict;
use Test;
use Config;

BEGIN { plan tests => 15 }
BEGIN { require "t/test_utils.pl"; }

use SystemC::Vregs;
ok(1);

print "Checking vregs...\n";
run_system ("${PERL} ./vreg --rm --files --headers"
	    ." --package vregs_spec"
	    ." --rules vregs_spec__rules.pl"
	    ." --v2k"
	    ." --output test_dir");
ok(1);

ok (-f "test_dir/vregs_spec_defs.v");
ok (-f "test_dir/vregs_spec_defs.h");
ok (-f "test_dir/vregs_spec_defs.pm");
ok (-f "test_dir/vregs_spec_asm.h");
ok (-f "test_dir/vregs_spec_hash.pm");
ok (-f "test_dir/vregs_spec_param.v");
ok (-f "test_dir/vregs_spec_info.cpp");
ok (-f "test_dir/vregs_spec_info.h");
ok (-f "test_dir/vregs_spec_class.h");
ok (-f "test_dir/vregs_spec_class.cpp");
ok (-f "test_dir/vregs_spec_struct.h");
ok (-f "test_dir/vregs_spec_latex.tex");

if (!$Config{use64bitint}
    || $Config{use64bitint} eq 'undef') {
    skip("not a 64 bit Perl, no vregs.pm check (harmless)",1);
} else {
    eval "require 'test_dir/vregs_spec_defs.pm';1;";
    ok(!$@);
}

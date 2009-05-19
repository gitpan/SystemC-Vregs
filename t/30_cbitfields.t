#!/usr/bin/perl -w
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2009 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License Version 3 or the Perl Artistic License Version 2.0.

use strict;
use Test;

BEGIN { plan tests => 5 }
BEGIN { require "t/test_utils.pl"; }

use SystemC::Vregs;
use SystemC::Vregs::Output::CBitFields;
ok(1);

my $vr = new SystemC::Vregs (address_bits=>36,);
ok($vr);

$vr->regs_read("test_dir/vregs_spec.vregs");
ok(1);
$vr->check();
ok(1);

SystemC::Vregs::Output::CBitFields->new()->write
    (pack=>$vr,
     filename=>"test_dir/chip_all_spec_bitfields.h",
     keep_timestamp=>1, verbose=>1,);
ok(-r "test_dir/chip_all_spec_bitfields.h");

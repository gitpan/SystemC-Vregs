#!/usr/bin/perl -w
# $Id: 05_number.t 4305 2005-08-02 13:21:57Z wsnyder $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2004 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.

use strict;
use Test;

BEGIN { plan tests => 6 }
BEGIN { require "t/test_utils.pl"; }

use SystemC::Vregs::Number;
use Bit::Vector::Overload;
ok(1);

TEST_text_to_vec (32, "12",
		  Bit::Vector->new_Dec(32, 12));
TEST_text_to_vec (20, "0x10",
		  Bit::Vector->new_Dec(20, 16));
TEST_text_to_vec (45, "0x1234_5678_9123",
		  Bit::Vector->new_Hex(45, "123456789123"));
TEST_text_to_vec (45, "32'h995678_9123",
		  Bit::Vector->new_Hex(32, "56789123"));
TEST_text_to_vec (45, "10'b1111",
		  Bit::Vector->new_Hex(10, "f"));

sub TEST_text_to_vec {
    my $bits = shift;
    my $text = shift;
    my $expect = shift;

    my $bv = SystemC::Vregs::Number::text_to_vec ($bits, $text);
    print "text_to_vec($text,$bits) = $bv\n";
    ok ($bv && $bv == $expect);
}

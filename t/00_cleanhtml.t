#!/usr/local/bin/perl -w
# $Revision: #1 $$Date: 2002/09/16 $$Author: lab $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package

use strict;
use Test;

BEGIN { plan tests => 2 }
BEGIN { require "t/test_utils.pl"; }

use SystemC::Vregs::TableExtract;
ok(1);

SystemC::Vregs::TableExtract::clean_html_file
    ("vregs_spec.htm");
ok(1);

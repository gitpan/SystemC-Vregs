#!/usr/local/bin/perl -w
# $Id: 00_cleanhtml.t,v 1.3 2002/03/11 14:07:22 wsnyder Exp $
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

#!/usr/bin/perl -w
# $Id: 00_cleanhtml.t 29376 2007-01-02 14:50:38Z wsnyder $
# DESCRIPTION: Perl ExtUtils: Type 'make test' to test this package
#
# Copyright 2001-2007 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.

use strict;
use Test;

BEGIN { plan tests => 2 }
BEGIN { require "t/test_utils.pl"; }

use SystemC::Vregs::TableExtract;
ok(1);

SystemC::Vregs::TableExtract::clean_html_file
    ("vregs_spec.htm");
ok(1);

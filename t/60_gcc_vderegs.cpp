// -*- C++ -*-
// $Revision: 1.9 $$Date: 2005-06-17 14:45:25 -0400 (Fri, 17 Jun 2005) $$Author: wsnyder $
// DESCRIPTION: C++ file compiled as part of test suite
//
// Copyright 2001-2005 by Wilson Snyder.  This program is free software;
// you can redistribute it and/or modify it under the terms of either the GNU
// General Public License or the Perl Artistic License.

#include "gcc_common.h"
#include "VregsRegInfo.h"

// *** HACK ***  SO we don't need to compile multiple objects together...
#include "VregsRegInfo.cpp"
#include "vderegs.cpp"
#include "vregs_spec_info.cpp"
#include "vregs_spec_class.cpp"

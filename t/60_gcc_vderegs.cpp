// -*- C++ -*-
// $Id: 60_gcc_vderegs.cpp 29378 2007-01-02 15:01:29Z wsnyder $
// DESCRIPTION: C++ file compiled as part of test suite
//
// Copyright 2001-2007 by Wilson Snyder.  This program is free software;
// you can redistribute it and/or modify it under the terms of either the GNU
// General Public License or the Perl Artistic License.

#include "gcc_common.h"
#include "VregsRegInfo.h"

// *** HACK ***  So we don't need to link multiple objects together...
#include "VregsRegInfo.cpp"
#include "vderegs.cpp"
#include "vregs_spec_info.cpp"
#include "vregs_spec_class.cpp"

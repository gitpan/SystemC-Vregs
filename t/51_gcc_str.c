// -*- C++ -*-
// $Id: 51_gcc_str.c 5416 2005-08-25 12:47:15Z wsnyder $
// DESCRIPTION: C file compiled as part of test suite
//
// Copyright 2005-2005 by Wilson Snyder.  This program is free software;
// you can redistribute it and/or modify it under the terms of either the GNU
// General Public License or the Perl Artistic License.

#include "gcc_common.h"

#include "vregs_spec_struct.h"
// Check include guard works
#include "vregs_spec_struct.h"

// Just enough so we know it compiles and run!
int main() {
    ExClassOne clOne;
    ExClassOne_fieldsZero(&clOne);
    ExClassOne_cmd_set(&clOne, ExEnum_ONE);
    ExClassOne_address_set(&clOne, 0x1234);
    return (0);
}

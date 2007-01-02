// -*- C++ -*-
// $Id: 51_gcc_str.c 29376 2007-01-02 14:50:38Z wsnyder $
// DESCRIPTION: C file compiled as part of test suite
//
// Copyright 2005-2007 by Wilson Snyder.  This program is free software;
// you can redistribute it and/or modify it under the terms of either the GNU
// General Public License or the Perl Artistic License.

#include "gcc_common.h"

#include "vregs_spec_struct.h"
// Check include guard works
#include "vregs_spec_struct.h"

// Just enough so we know it compiles and run!
int main() {
    ExClassOne clOne;
    exClassOne_fieldsZero (&clOne);
    exClassOne_cmd_set    (&clOne, ExEnum_ONE);
    exClassOne_address_set(&clOne, 0x1234);
    return (0);
}

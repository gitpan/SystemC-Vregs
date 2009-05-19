// -*- C++ -*-
// DESCRIPTION: C file compiled as part of test suite
//
// Copyright 2005-2009 by Wilson Snyder.  This program is free software;
// you can redistribute it and/or modify it under the terms of either the GNU
// Lesser General Public License Version 3 or the Perl Artistic License Version 2.0.

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

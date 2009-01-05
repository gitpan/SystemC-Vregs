// -*- C++ -*-
// DESCRIPTION: C++ file compiled as part of test suite
//
// Copyright 2001-2009 by Wilson Snyder.  This program is free software;
// you can redistribute it and/or modify it under the terms of either the GNU
// Lesser General Public License or the Perl Artistic License.

#include "gcc_common.h"

#include "vregs_spec_defs.h"
#include "vregs_spec_class.h"
// Check include guard works
#include "vregs_spec_class.h"

// Lazyness so don't need to link multiple objects:
#include "vregs_spec_class.cpp"

#ifndef INSERTED__before_file_body
#error MISSING  INSERTED__before_file_body
#endif
#ifndef INSERTED__ENUM
#error MISSING  INSERTED__ENUM
#endif
#ifndef INSERTED__before_class_top__ExBase
#error MISSING  INSERTED__before_class_top__ExBase
#endif
#ifndef INSERTED__after_class_top__ExBase
#error MISSING  INSERTED__after_class_top__ExBase
#endif
#ifndef INSERTED__before_class_end__ExBase
#error MISSING  INSERTED__before_class_end__ExBase
#endif
#ifndef INSERTED__after_class_end__ExBase
#error MISSING  INSERTED__after_class_end__ExBase
#endif
#ifndef INSERTED__before_class_top__R_ExReg1
#error MISSING  INSERTED__before_class_top__R_ExReg1
#endif
#ifndef INSERTED__after_class_top__R_ExReg1
#error MISSING  INSERTED__after_class_top__R_ExReg1
#endif
#ifndef INSERTED__before_class_end__R_ExReg1
#error MISSING  INSERTED__before_class_end__R_ExReg1
#endif
#ifndef INSERTED__after_class_end__R_ExReg1
#error MISSING  INSERTED__after_class_end__R_ExReg1
#endif
#ifndef INSERTED__before_class_top__R_ExRegTwo
#error MISSING  INSERTED__before_class_top__R_ExRegTwo
#endif
#ifndef INSERTED__after_class_top__R_ExRegTwo
#error MISSING  INSERTED__after_class_top__R_ExRegTwo
#endif
#ifndef INSERTED__before_class_end__R_ExRegTwo
#error MISSING  INSERTED__before_class_end__R_ExRegTwo
#endif
#ifndef INSERTED__after_class_end__R_ExRegTwo
#error MISSING  INSERTED__after_class_end__R_ExRegTwo
#endif
#ifndef INSERTED__before_class_top__ExClassOne
#error MISSING  INSERTED__before_class_top__ExClassOne
#endif
#ifndef INSERTED__after_class_top__ExClassOne
#error MISSING  INSERTED__after_class_top__ExClassOne
#endif
#ifndef INSERTED__before_class_end__ExClassOne
#error MISSING  INSERTED__before_class_end__ExClassOne
#endif
#ifndef INSERTED__after_class_end__ExClassOne
#error MISSING  INSERTED__after_class_end__ExClassOne
#endif
#ifndef INSERTED__before_class_top__ExClassTwo
#error MISSING  INSERTED__before_class_top__ExClassTwo
#endif
#ifndef INSERTED__after_class_top__ExClassTwo
#error MISSING  INSERTED__after_class_top__ExClassTwo
#endif
#ifndef INSERTED__before_class_end__ExClassTwo
#error MISSING  INSERTED__before_class_end__ExClassTwo
#endif
#ifndef INSERTED__after_class_end__ExClassTwo
#error MISSING  INSERTED__after_class_end__ExClassTwo
#endif
#ifndef INSERTED__before_class_cpp__ExClassTwo
#error MISSING  INSERTED__before_class_cpp__ExClassTwo
#endif
#ifndef INSERTED__after_class_cpp__ExClassTwo
#error MISSING  INSERTED__after_class_cpp__ExClassTwo
#endif

// Just enough so we know it compiles and run!
int main() {
    ExClassOne clOne;
    clOne.fieldsZero();
    clOne.cmd(ExEnum::ONE);
    clOne.address(0x1234);

    // Size check
    if (sizeof(ExBase) != ExBase::SIZE) {
	COUT << "%Error: Base Has Wrong Size: "<<sizeof(ExBase)<<" "<<ExBase::SIZE<<endl;
	exit(10);
    }
    if (sizeof(ExClassOne) != ExClassOne::SIZE) {
	COUT << "%Error: ClassOne Has Wrong Size: "<<sizeof(ExBase)<<" "<<ExClassOne::SIZE<<endl;
	exit(10);
    }
    if (sizeof(ExClassTwo) != ExClassTwo::SIZE) {
	COUT << "%Error: ClassTwo Has Wrong Size: "<<sizeof(ExBase)<<" "<<ExClassTwo::SIZE<<endl;
	exit(10);
    }

    // Define check
    if (FREE_DOUBLE != -1.2345) {
	COUT << "%Error: FREE_DOUBLE Has Wrong Value\n";
	exit(10);
    }

    // Dumping a enum
    COUT << "Cmd = "<<clOne.cmd()<< " Desc="<<clOne.cmd().description()<<endl;

    // Dumping class
    COUT << "ClassOne =\t" <<hex << clOne.dump() << endl;

    // Check subclassing worked
    ExSuperEnum sen (ExSuperEnum::A_FIVE);
    COUT << "SuperEnum Description = "<<sen.description()<<endl;

    return (0);
}

// -*- C++ -*-
// $Revision: 1.19 $$Date: 2004-12-17 13:03:41 -0500 (Fri, 17 Dec 2004) $$Author: wsnyder $
// DESCRIPTION: C++ file compiled as part of test suite
//
// Copyright 2001-2004 by Wilson Snyder.  This program is free software;
// you can redistribute it and/or modify it under the terms of either the GNU
// General Public License or the Perl Artistic License.

#include <stdlib.h>
typedef unsigned int uint32_t;
#if defined(__WORDSIZE) && (__WORDSIZE == 64)
typedef unsigned long int uint64_t;
typedef unsigned long int Address;
#else
typedef unsigned long long uint64_t;
typedef unsigned long long Address;
#endif

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

    // Dumping a enum
    COUT << "Cmd = "<<clOne.cmd()<< " Desc="<<clOne.cmd().description()<<endl;

    // Dumping class
    COUT << "ClassOne =\t" <<hex << clOne.dump() << endl;

    // Check subclassing worked
    ExSuperEnum sen (ExSuperEnum::A__FIVE);
    COUT << "SuperEnum Desciption = "<<sen.description()<<endl;

    return (0);
}

// -*- C++ -*-
// $Id: 50_gcc_hdr.cpp,v 1.11 2002/03/11 14:07:22 wsnyder Exp $
// DESCRIPTION: C++ file compiled as part of test suite

#include <stdlib.h>
typedef unsigned int uint32_t ;
typedef unsigned long long uint64_t ;
typedef unsigned long long Address ;

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
    ExClassTwo clTwo;
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
    if ((char*)&clTwo != (char*)&(clTwo.m_w[0])) {
	COUT << "%Error: Data doesn't start at base\n";
	exit(10);
    }

    // Dumping a enum
    COUT << "Cmd = "<<clOne.cmd()<<endl;

    // Dumping class
    COUT << "ClassOne =\t" <<hex << clOne.dump() << endl;

    return (0);
}

// -*- C++ -*-
// DESCRIPTION: C++ file compiled as part of test suite

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

// Just enough so we know it compiles and run!
int main() {
    ExClassOne base;
    base.fieldsZero();
    base.cmd(ExEnum::ONE);
    base.address(0x1234);

    // Dumping a enum
    cout << "Cmd = "<<base.cmd()<<endl;

    // Dumping class
    cout << "Base =\t" <<hex << base.dump() << endl;

    return (0);
}

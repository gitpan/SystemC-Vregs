// -*- C++ -*-
// DESCRIPTION: C++ file compiled as part of test suite
//
// Copyright 2001-2009 by Wilson Snyder.  This program is free software;
// you can redistribute it and/or modify it under the terms of either the GNU
// Lesser General Public License Version 3 or the Perl Artistic License Version 2.0.

#include "gcc_common.h"
#include "VregsRegInfo.h"

// *** HACK ***  So we don't need to link multiple objects together...
#include "VregsRegInfo.cpp"
#include "vregs_spec_info.cpp"
#include "vregs_spec_class.cpp"

//======================================================================

class vregs_HACK_info {
public:
    static void addRegisters(VregsRegInfo* reginfop);
};

void vregs_HACK_info::addRegisters(VregsRegInfo* reginfop) {
    COUT << "vregs_spec_RegInfo Init\n";

    reginfop->add_register (0x1010, 4, "Reg_at_0x1010");
    reginfop->add_register (0x1040, 4, "Reg_at_0x1040");
    reginfop->add_register (0x1004, 4, "Reg_at_0x1004");
    reginfop->add_register (0x3000, 4, "RegRam_at_0x3000", 4, 0, 0x0f);
    reginfop->add_register (0x2000, 4, "RegRam_at_0x1000", 0x10, 0, 0x0f);
}

//======================================================================

int main() {
    char buf[1000];

    VregsRegInfo* reginfop = new VregsRegInfo;
    vregs_HACK_info::addRegisters (reginfop);
    vregs_spec_info.addRegisters (reginfop);
    reginfop->dump();

    VregsRegEntry* entp = reginfop->find_by_addr(0x1040);
    if (!entp) { COUT << "find_by_addr failed\n"; return (10); }

    //reginfop->print_at_addr (0x1040);
    COUT << "address 0010 is: " << reginfop->addr_name(0x0010, buf,1000) << endl;
    COUT << "address 1010 is: " << reginfop->addr_name(0x1010, buf,1000) << endl;
    COUT << "address 1040 is: " << reginfop->addr_name(0x1040, buf,1000) << endl;
    COUT << "address 2013 is: " << reginfop->addr_name(0x2013, buf,1000) << endl;
    COUT << "address 3013 is: " << reginfop->addr_name(0x3013, buf,1000) << endl;

    COUT << "ExSuperEnum values:";
    for (ExSuperEnum::iterator it=ExSuperEnum::begin(); it!=ExSuperEnum::end(); ++it) {
	COUT << " "<<*it;
	COUT << "(0x"<<hex<<(int)(*it)<<")";
    }
    COUT << endl;

    return (0);
}

// Local Variables:
// compile-command: "cd .. ; t/55_gcc_info.t"
// End:

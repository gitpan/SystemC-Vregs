// $Revision: 1.18 $$Date: 2005-06-17 14:45:25 -0400 (Fri, 17 Jun 2005) $$Author: wsnyder $ -*- C++ -*-
//======================================================================
//
// Copyright 2001-2005 by Wilson Snyder <wsnyder@wsnyder.org>.  This
// program is free software; you can redistribute it and/or modify it under
// the terms of either the GNU Lesser General Public License or the Perl
// Artistic License.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
//======================================================================
///
/// \file
/// \brief Vregs: VregsRegEntry and VregsRegInfo classes
///
/// AUTHOR:  Wilson Snyder
///
//======================================================================

#include <sstream>

#include "VregsRegInfo.h"

//======================================================================
// Statics

VregsSpecsInfo::ByNameMap  VregsSpecsInfo::s_byName;

//======================================================================
// VregsRegEntry

void VregsRegEntry::dump () const {
    COUT << "  REnt: Address "
	 << hex << address() << " - " << (address() + size() - 1)
	 << "  Reg " << name();
    if (isRanged()) {
	COUT << "[" << hex << lowEntNum() << "]";
    }
    COUT << "  Size " << size() << endl;
}

//======================================================================
// VregsRegInfo

void VregsRegInfo::add_register (VregsRegEntry* regentp) {
    m_byAddr.insert(std::make_pair(regentp->address(), regentp));
}

void VregsRegInfo::add_register (
    address_t addr, size64_t size, const char* name,
    uint32_t spacing, uint32_t rangeLow, uint32_t rangeHigh,
    uint32_t rdMask, uint32_t wrMask,
    uint32_t rstVal, uint32_t rstMask, uint32_t flags)
{
    if (spacing == 0) {
	// Single register
	add_register (new VregsRegEntry (addr, size, name, 0, 0,
					 rdMask,wrMask,rstVal,rstMask,
					 flags));
    } else if (spacing == size) {
	// The registers abut one another, so just add them to the range.
	add_register (new VregsRegEntry (addr, (rangeHigh-rangeLow)*size,
					 name, spacing, rangeLow,
					 rdMask,wrMask,rstVal,rstMask,
					 flags));
    } else {
	for (uint32_t ent=0; ent < (rangeHigh-rangeLow); ent++) {
	    // Mark the register for test if it's a small region,
	    // or it's the first, last, or a power-of-two register
	    bool test = (ent==0 || ent==(rangeHigh-rangeLow-1)
			 || ((rangeHigh-rangeLow)<=16));
	    for (int bit=0; bit<64; bit++) { if (ent==(1ULL<<bit)) test=true; }
	    add_register (new VregsRegEntry (addr + ent*spacing, size,
					     name, size, ent+rangeLow,
					     rdMask,wrMask,rstVal,rstMask,
					     flags | (test?0:VregsRegEntry::REGFL_NOBIGTEST)));
	}
    }
}

void VregsRegInfo::dump() {
    COUT << "VregsRegInfo dump\n";

    for (VregsRegInfo::iterator iter = begin(); iter != end(); ++iter) {
	const VregsRegEntry* rep = iter;
	rep->dump();
    }
}

VregsRegEntry* VregsRegInfo::find_by_next_addr (address_t addr) {
    // Return register at given address, or the next register at slightly greater address
    ByAddrMap::iterator iter = m_byAddr.lower_bound(addr);
    if (iter == m_byAddr.end()) return NULL;
    VregsRegEntry* re1p = iter->second;
    if (!re1p) {
	iter = m_byAddr.end();
	--iter;
	re1p = iter->second;
    }
    if (!re1p) return NULL;
    if (iter != m_byAddr.begin() && re1p->address() > addr) --iter;
    VregsRegEntry *rep = iter->second;
    if (addr >= rep->address() && addr < rep->addressEnd() ) {
	return rep;
    }
    iter++;
    if (iter != m_byAddr.end()) {
	return iter->second;
    }
    return NULL;
}

VregsRegEntry* VregsRegInfo::find_by_addr (address_t addr) {
    // Return register at given address, or NULL
    VregsRegEntry* rep = find_by_next_addr(addr);
    if (rep && addr >= rep->address() && addr < rep->addressEnd() ) {
	return rep;
    }
    return NULL;
}

string VregsRegInfo::addr_name (address_t addr) {
    // If there is a register at this address, return string representing it.
    VregsRegEntry* rep = find_by_addr (addr);
    if (!rep) {
	// No register here.
	return "";
    }

    ostringstream os;
    if (rep->isRanged()) {
	long thisent = (long)((addr - rep->address()) / rep->entSize());
	os <<rep->name()<<"["<<hex<<thisent + rep->lowEntNum()<<"]";
	addr -= thisent * rep->entSize();
    } else {
	os <<rep->name();
    }

    if (addr != rep->address()) {
	os <<"+"<<hex<<(unsigned long long)(addr - rep->address());
    }
    return os.str();
}

const char* VregsRegInfo::addr_name (address_t addr, char* buffer, size64_t length) {
    // If there is a register at this address, return string representing it.
    // Else, return ""
    snprintf (buffer, length, "%s", addr_name(addr).c_str());
    return buffer;
}

// $Id: VregsRegInfo.cpp 60052 2008-09-03 15:23:07Z wsnyder $ -*- C++ -*-
//======================================================================
//
// Copyright 2001-2008 by Wilson Snyder <wsnyder@wsnyder.org>.  This
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
#include <stdlib.h>

#include "VregsRegInfo.h"

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

/// Value of an attribute; return default if not defined.
uint64_t VregsRegEntry::attribute_value(const char* attr, uint64_t defValue) const {
    const char* searchp = attributes();
    while (searchp && NULL != (searchp = strchr(searchp, '-'))) {
	searchp++;
	if (0==strncmp(searchp, attr, strlen(attr))) {   // Prefix matches
	    searchp += strlen(attr);
	    if (!*searchp || *searchp==' ') { // Attribute set to one
		return 1;
	    }
	    else if (*searchp=='=') {
		searchp++;
		if (!searchp) return 1;
		return strtoll(searchp, NULL, 10);
	    }
	    // else it's only a partial match, ie "foobar"!="foo".
	}
    }
    return defValue;
}

bool VregsRegEntry::addressHit(uint64_t addr) const {
    if (addr < address() || addr >= addressEnd()) return false;
    if (!entSpacing()) {
	if (addr != address()) return false;
    } else {
	uint64_t offset = addr - address();
	if ((offset % entSpacing()) != 0) return false;  // Inside a "hole"
    }
    return true;
}

//======================================================================
// VregsRegInfo

void VregsRegInfo::add_register (VregsRegEntry* regentp) {
    m_byAddr.insert(std::make_pair(regentp->address(), regentp));
}

void VregsRegInfo::add_register (
    address_t addr, size64_t size, const char* name,
    uint64_t spacing, uint64_t rangeLow, uint64_t rangeHigh,
    uint64_t rdMask, uint64_t wrMask,
    uint64_t rstVal, uint64_t rstMask,
    uint32_t flags, const char* attrs)
{
    if (spacing == 0) {
	// Single register
	add_register (new VregsRegEntry (addr, size, name,
					 0, 0, 0,
					 rdMask,wrMask,rstVal,rstMask,
					 flags, attrs));
    } else if (spacing == size || (flags & VregsRegEntry::REGFL_PACKHOLES)) {
	// The registers abut one another, so just add them to the range.
	add_register (new VregsRegEntry (addr, (rangeHigh-rangeLow)*spacing, name,
					 size, spacing, rangeLow,
					 rdMask,wrMask,rstVal,rstMask,
					 flags, attrs));
    } else {
	for (uint32_t ent=0; ent < (rangeHigh-rangeLow); ent++) {
	    // Mark the register for test if it's a small region,
	    // or it's the first, last, or a power-of-two register
	    bool test = (ent==0 || ent==(rangeHigh-rangeLow-1)
			 || ((rangeHigh-rangeLow)<=16));
	    for (int bit=0; bit<64; bit++) { if (ent==(VREGS_ULL(1)<<bit)) test=true; }
	    add_register (new VregsRegEntry (addr + ent*spacing, size, name,
					     size, spacing, ent+rangeLow,
					     rdMask,wrMask,rstVal,rstMask,
					     flags | (test?0:VregsRegEntry::REGFL_NOBIGTEST),
					     attrs));
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
    VregsRegEntry* rep = iter->second;
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
    if (rep && rep->addressHit(addr)) {
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
	long thisent = (long)((addr - rep->address()) / rep->entSpacing());
	os <<rep->name()<<"["<<hex<<thisent + rep->lowEntNum()<<"]";
	addr -= thisent * rep->entSpacing();
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

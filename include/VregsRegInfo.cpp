// $Revision: #2 $$Date: 2002/10/04 $$Author: lab $ -*- C++ -*-
//======================================================================
//
// This program is Copyright 2001 by Wilson Snyder.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of either the GNU General Public License or the
// Perl Artistic License.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the Perl Artistic License
// along with this module; see the file COPYING.  If not, see
// www.cpan.org
//									     
//======================================================================
// DESCRIPTION: Vregs: VregsRegEntry and VregsRegInfo classes
//======================================================================

#include "VregsRegInfo.h"

//======================================================================
// VregsRegEntry

void VregsRegEntry::dump () const
{
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

void VregsRegInfo::add_register (VregsRegEntry* regentp)
{
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

void VregsRegInfo::dump()
{
    COUT << "VregsRegInfo dump\n";
    
    for (VregsRegInfo::iterator iter = begin(); iter != end(); ++iter) {
	const VregsRegEntry* rep = iter;
	rep->dump();
    }
}

VregsRegEntry* VregsRegInfo::find_by_next_addr (address_t addr)
{
    // Return register at given address, or the next register at slightly greater address
    ByAddrMap::iterator iter = m_byAddr.lower_bound(addr);
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

VregsRegEntry* VregsRegInfo::find_by_addr (address_t addr)
{
    // Return register at given address, or NULL
    VregsRegEntry* rep = find_by_next_addr(addr);
    if (addr >= rep->address() && addr < rep->addressEnd() ) {
	return rep;
    }
    return NULL;
}

const char* VregsRegInfo::addr_name (
    address_t addr, char* buffer, size64_t length)
    // If there is a register at this address, return string representing it.
    // Returns buffer.
{
    char* bufp = buffer;

    *bufp = '\0';
    VregsRegEntry* rep = find_by_addr (addr);
    if (!rep) {
	// No register here.
	return bufp;
    }

    int strsize = 0;
    if (rep->isRanged()) {
	long thisent = (long)((addr - rep->address()) / rep->entSize());
	strsize = snprintf (bufp, length, "%s[%lx]", rep->name(), thisent + rep->lowEntNum());
	addr -= thisent * rep->entSize();
    } else {
	strsize = snprintf (bufp, length, "%s", rep->name());
    }
    bufp += strsize; length -= strsize;
    if (addr != rep->address()) {
	snprintf (bufp, length, "+%llx", (uint64_t)(addr - rep->address()));
    }
    return buffer;
}

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

#ifndef _VREGS_REG_INFO_H_
#define _VREGS_REG_INFO_H_

#include <stdint.h>
#include <stdio.h>
#include <iostream>
#include <map>
#include <algorithm>

#include "VregsClass.h"

class VregsRegInfo;

//======================================================================
// VregsRegEntry
// Each register has one of these entries, which is a member of VregsRegInfo

class VregsRegEntry {
private:
    address_t		m_address;	// Address of entry 0, word 0 of register
    size64_t		m_size;		// Size in bytes of the register
    const char*		m_name;		// Ascii name of the register
    size64_t		m_entSize;	// Size of a single entry
    long		m_lowEntNum;	// Low entry number (for RAMs)
    void*		m_userinfo;	// Reserved for users (not used here)

    uint32_t		m_rdMask;	// Readable mask (1 in bit indicates is readable)
    uint32_t		m_wrMask;	// Writeable mask (1 in bit indicates is writable)
    uint32_t		m_rstVal;	// Reset value (for 32 bit reg tests)
    uint32_t		m_rstMask;	// Reset mask (1 in bit indicates is reset)
    uint32_t		m_flags;	// Flags (side effects, testing)

    // Function to return 'name' of address, NULL = default
    // Function to print data, NULL = default

public:
//protected:
    // CREATORS
    friend class VregsRegInfo;
    VregsRegEntry(address_t addr, size64_t size,
		  const char* name, size64_t entSize, long lowEntNum,
		  uint32_t rdMask, uint32_t wrMask,
		  uint32_t rstVal, uint32_t rstMask, uint32_t flags)
	: m_address(addr), m_size(size), m_name(name)
	, m_entSize(entSize), m_lowEntNum(lowEntNum)
	, m_userinfo(NULL), m_rdMask(rdMask), m_wrMask(wrMask)
	, m_rstVal(rstVal), m_rstMask(rstMask), m_flags(flags) {};
    ~VregsRegEntry() {}

public:
    // CONSTANTS
    static const uint32_t REGFL_RDSIDE	= 0x1;	// Register has read side effects
    static const uint32_t REGFL_WRSIDE	= 0x2;	// Register has write side effects
    static const uint32_t REGFL_NOBIGTEST = 0x4;	// Register should be extensively tested
    static const uint32_t REGFL_NOREGTEST = 0x8;	// Register should not be tested
    static const uint32_t REGFL_NOREGDUMP = 0x10;	// Register should not be dumped

    // MANIPULATORS
    void 		userinfo (void* userinfo) { m_userinfo = userinfo; }
    void		dump() const;

    // ACCESSORS
    address_t		address () const { return m_address; }
    const char* 	name () const { return m_name; }
    size64_t	 	size () const { return m_size; }
    size64_t	 	entSize () const { return m_entSize; }
    long 		lowEntNum () const { return m_lowEntNum; }
    void* 		userinfo () const { return m_userinfo; }

    // We don't allow visibility to the uint that gives the value of these fields
    // This allows us to have other then 32 bit registers in the future
    bool		rdMask(int bit) const { return ((m_rdMask & (1UL<<(bit)))!=0); }
    bool		wrMask(int bit) const { return ((m_wrMask & (1UL<<(bit)))!=0); }
    bool		rstVal(int bit) const { return ((m_rstVal & (1UL<<(bit)))!=0); }
    bool		rstMask(int bit) const { return ((m_rstMask & (1UL<<(bit)))!=0); }
    uint32_t		rdMask() const { return (m_rdMask); }
    uint32_t		wrMask() const { return (m_wrMask); }
    uint32_t		rstVal() const { return (m_rstVal); }
    uint32_t		rstMask() const { return (m_rstMask); }
    bool		isRdMask() const { return (m_rdMask!=0); }
    bool		isWrMask() const { return (m_wrMask!=0); }
    bool		isRstMask() const { return (m_rstMask!=0); }
    bool		isRdSide() const { return ((m_flags & REGFL_RDSIDE)!=0); }
    bool		isWrSide() const { return ((m_flags & REGFL_WRSIDE)!=0); }
    bool		isRegTest() const { return ((m_flags & REGFL_NOREGTEST)==0); }
    bool		isRegDump() const { return ((m_flags & REGFL_NOREGDUMP)==0); }
    bool		isBigTest() const { return ((m_flags & REGFL_NOBIGTEST)==0); }

    // ACCESSORS - Derrived from above functions
    // True if this is a entry of a multiple entry structure
    bool		isRanged() const { return entSize() != 0; }
    size64_t		entries() const {
				if (!isRanged()) return lowEntNum()+1;
				return (max ((long)(size()/entSize()), lowEntNum())+1); }
    address_t		addressEnd() const { return address() + size(); }
};

//======================================================================
// VregsRegInfo
// There is generally one global VregsRegInfo, which has info about registers

class VregsRegInfo {
private:
    typedef std::map<address_t,VregsRegEntry*> ByAddrMap;

    ByAddrMap m_byAddr;		// Address sorted reg info

public:
    // CREATORS
    VregsRegInfo() {};
    ~VregsRegInfo() {};

    // MANIPULATORS
    void	add_register (VregsRegEntry* regentp);
    void	add_register (address_t addr, size64_t size, const char* name,
			      uint32_t spacing, uint32_t rangelow, uint32_t rangehigh,
			      uint32_t rdMask, uint32_t wrMask,
			      uint32_t rstVal, uint32_t rstMask, uint32_t flags);
    void	add_register (address_t addr, size64_t size, const char* name,
			      uint32_t rdMask, uint32_t wrMask,
			      uint32_t rstVal, uint32_t rstMask, uint32_t flags) {
	add_register (addr, size, name, 0, 0, 0,
		      rdMask,wrMask,rstVal,rstMask,flags); }
    void	add_register (address_t addr, size64_t size, const char* name) {
	add_register (addr, size, name, 0, 0, 0,
		      ~0,~0,0,0,0); }
    void	add_register (address_t addr, size64_t size, const char* name,
			      uint32_t spacing, uint32_t rangelow, uint32_t rangehigh
			      ) {
	add_register (addr, size, name, spacing, rangelow, rangehigh,
		      ~0,~0,0,0,0); }
    void	lookup();
    void	dump();

    // MANIPULATORS - Lookups
    VregsRegEntry* find_by_addr (address_t addr);
    VregsRegEntry* find_by_next_addr (address_t addr);
    const char*	addr_name (address_t addr, char* buffer, size64_t length); // Return "name" of address

    // MANIPULATORS - Iterating through all registers.
    class iterator {
	ByAddrMap::iterator   m_addrIt;
    public:
	iterator(ByAddrMap::iterator addrIt) : m_addrIt(addrIt) {};
	inline iterator operator++() {++m_addrIt; return *this;};	// prefix
	inline operator VregsRegEntry* () const { return (m_addrIt->second); };
    };
    iterator	begin() { return m_byAddr.begin(); }
    iterator	end()   { return m_byAddr.end(); }

    // ACCESSORS
};

#endif

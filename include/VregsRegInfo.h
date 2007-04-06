// $Id: VregsRegInfo.h 35449 2007-04-06 13:21:40Z wsnyder $ -*- C++ -*-
//======================================================================
//
// Copyright 2001-2007 by Wilson Snyder <wsnyder@wsnyder.org>.  This
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

#ifndef _VREGS_REG_INFO_H_
#define _VREGS_REG_INFO_H_

#include <stdint.h>
#include <stdio.h>
#include <iostream>
#include <map>
#include <algorithm>
#include <string>

#include "VregsDefs.h"
#include "VregsClass.h"

class VregsRegInfo;

//======================================================================
// VregsRegEntry
/// Each register has one of these entries, which is a member of VregsRegInfo

class VregsRegEntry {
private:
    address_t		m_address;	///< Address of entry 0, word 0 of register
    size64_t		m_size;		///< Size in bytes of the register
    const char*		m_name;		///< Ascii name of the register
    size64_t		m_entSize;	///< Size of a single entry
    uint64_t		m_lowEntNum;	///< Low entry number (for RAMs)
    void*		m_userinfo;	///< Reserved for users (not used here)

    uint64_t		m_rdMask;	///< Readable mask (1 in bit indicates is readable)
    uint64_t		m_wrMask;	///< Writeable mask (1 in bit indicates is writable)
    uint64_t		m_rstVal;	///< Reset value (for 32 bit reg tests)
    uint64_t		m_rstMask;	///< Reset mask (1 in bit indicates is reset)
    uint32_t		m_flags;	///< Flags (side effects, testing)

public:
//protected:
    // CREATORS
    friend class VregsRegInfo;
    // Create new register, called by vregs generated headers
    VregsRegEntry(address_t addr, size64_t size,
		  const char* name, size64_t entSize, uint64_t lowEntNum,
		  uint64_t rdMask, uint64_t wrMask,
		  uint64_t rstVal, uint64_t rstMask, uint32_t flags)
	: m_address(addr), m_size(size), m_name(name)
	, m_entSize(entSize), m_lowEntNum(lowEntNum)
	, m_userinfo(NULL), m_rdMask(rdMask), m_wrMask(wrMask)
	, m_rstVal(rstVal), m_rstMask(rstMask), m_flags(flags) {};
    ~VregsRegEntry() {}

public:
    // CONSTANTS
    static const uint32_t REGFL_RDSIDE	= 0x1;	///< Register has read side effects
    static const uint32_t REGFL_WRSIDE	= 0x2;	///< Register has write side effects
    static const uint32_t REGFL_NOBIGTEST = 0x4;	///< Register should be extensively tested
    static const uint32_t REGFL_NOREGTEST = 0x8;	///< Register should not be tested
    static const uint32_t REGFL_NOREGDUMP = 0x10;	///< Register should not be dumped

    // MANIPULATORS
    void 		userinfo (void* userinfo) { m_userinfo = userinfo; }
    void		dump() const;	///< Dump all information on registers

    // ACCESSORS
    address_t		address () const { return m_address; }	///< Starting address
    const char* 	name () const { return m_name; }	///< Register name
    size64_t	 	size () const { return m_size; }	///< Total size in bytes
    size64_t	 	entSize () const { return m_entSize; }	///< One array entry in bytes
    size64_t		accessSize() const { return isRanged() ? entSize() : size(); }
    uint64_t 		lowEntNum () const { return m_lowEntNum; }	///< Low bound of array
    void* 		userinfo () const { return m_userinfo; }	///< Userdata

    // We don't allow visibility to the uint that gives the value of these fields
    // This allows us to have other then 32 bit registers in the future
    bool		rdMask(int bit) const { return ((m_rdMask & (VREGS_ULL(1)<<(bit)))!=0); } ///< Is this bit readable
    bool		wrMask(int bit) const { return ((m_wrMask & (VREGS_ULL(1)<<(bit)))!=0); } ///< Is this bit writable
    bool		rstMask(int bit) const { return ((m_rstMask & (VREGS_ULL(1)<<(bit)))!=0); } ///< Is this bit reset
    bool		rstVal(int bit) const { return ((m_rstVal & (VREGS_ULL(1)<<(bit)))!=0); } ///< Reset value of this bit
    uint64_t		rdMask() const { return (m_rdMask); }	///< Bits that are readable
    uint64_t		wrMask() const { return (m_wrMask); }	///< Bits that are writable
    uint64_t		rstMask() const { return (m_rstMask); }	///< Bits that are reset
    uint64_t		rstVal() const { return (m_rstVal); }	///< Reset value
    bool		isRdMask() const { return (m_rdMask!=0); }	///< Readable
    bool		isWrMask() const { return (m_wrMask!=0); }	///< Writable
    bool		isRstMask() const { return (m_rstMask!=0); }	///< Reset non zero
    bool		isRdSide() const { return ((m_flags & REGFL_RDSIDE)!=0); }	///< Has read side effects
    bool		isWrSide() const { return ((m_flags & REGFL_WRSIDE)!=0); }	///< Has write side effects
    bool		isRegTest() const { return ((m_flags & REGFL_NOREGTEST)==0); }	///< Register is testable
    bool		isRegDump() const { return ((m_flags & REGFL_NOREGDUMP)==0); }	///< Register should be dumped
    bool		isBigTest() const { return ((m_flags & REGFL_NOBIGTEST)!=0); }	///< Register too big for testing

    // ACCESSORS - Derived from above functions
    // True if this is a entry of a multiple entry structure
    bool		isRanged() const { return entSize() != 0; }	///< Has a range
    /// Return number of entries (array elements)
    size64_t		entries() const {
				if (!isRanged()) return lowEntNum()+1;
				return (max ((uint64_t)(size()/entSize()), lowEntNum())+1); }
    /// Ending address of the register + 1
    address_t		addressEnd() const { return address() + size(); }
};

//======================================================================
// VregsRegInfo
/// There is generally one global VregsRegInfo, which has info about all registers

class VregsRegInfo {
private:
    typedef std::map<address_t,VregsRegEntry*> ByAddrMap;

    ByAddrMap m_byAddr;		///< Address sorted reg info

public:
    // CREATORS
    VregsRegInfo() {};
    ~VregsRegInfo() {};

    // MANIPULATORS
    /// Add a new register, called by vregs classes
    void	add_register (VregsRegEntry* regentp);
    void	add_register (address_t addr, size64_t size, const char* name,
			      uint64_t spacing, uint64_t rangelow, uint64_t rangehigh,
			      uint64_t rdMask, uint64_t wrMask,
			      uint64_t rstVal, uint64_t rstMask, uint32_t flags);
    void	add_register (address_t addr, size64_t size, const char* name,
			      uint64_t rdMask, uint64_t wrMask,
			      uint64_t rstVal, uint64_t rstMask, uint32_t flags) {
	add_register (addr, size, name, 0, 0, 0,
		      rdMask,wrMask,rstVal,rstMask,flags); }
    void	add_register (address_t addr, size64_t size, const char* name) {
	add_register (addr, size, name, 0, 0, 0,
		      ~0,~0,0,0,0); }
    void	add_register (address_t addr, size64_t size, const char* name,
			      uint64_t spacing, uint64_t rangelow, uint64_t rangehigh
			      ) {
	add_register (addr, size, name, spacing, rangelow, rangehigh,
		      ~0,~0,0,0,0); }
    void	lookup();
    void	dump();

    uint64_t    size() { return m_byAddr.size(); }

    // MANIPULATORS - Lookups
    VregsRegEntry* find_by_addr (address_t addr);	///< Return register given address
    VregsRegEntry* find_by_next_addr (address_t addr);	///< Return register after address
    /// Return textual "name" of address
    string	addr_name (address_t addr);
    const char*	addr_name (address_t addr, char* buffer, size64_t length);

    // MANIPULATORS
    /// Iterate across VregsRegInfo's.
    class iterator {
	ByAddrMap::iterator   m_addrIt;
    public:
	iterator(ByAddrMap::iterator addrIt) : m_addrIt(addrIt) {};
	inline iterator operator++() {++m_addrIt; return *this;};	///< prefix
	inline operator VregsRegEntry* () const { return (m_addrIt->second); };
    };
    iterator	begin() { return m_byAddr.begin(); }	///< Begin iterator across all registers
    iterator	end()   { return m_byAddr.end(); }	///< End iterator across all registers

    // ACCESSORS
};

//======================================================================
// VregsSpecInfo
/// Information on a single class name
///  This is a subclass of each specification's _info class.

class VregsSpecInfo {
public:
    // CONSTRUCTORS
    VregsSpecInfo() {}
    virtual ~VregsSpecInfo() {}
    // METHODS
    /// Name of the spec
    virtual const char* name() = 0;
    /// Add all defined registers to the global list
    virtual void   addRegisters(VregsRegInfo* reginfop) = 0;
    /// Is there a class by this name?
    virtual bool   isClassName(const char* className) = 0;
    /// How many class names?
    virtual int    numClassNames() = 0;
    /// Array of all class names
    virtual const char** classNames() = 0;
    /// Given a class name, dump in that format
    virtual void   dumpClass(const char* className, void* datap,
			     OStream& ost=COUT, const char* pf="\n\t") = 0;
};

//======================================================================
// VregsSpecsInfo
/// General information on all specs

class VregsSpecsInfo {
private:
    typedef std::map<string,VregsSpecInfo*> ByNameMap;

    static ByNameMap& sByName() {	///< Each specification sorted by its name
	static ByNameMap singleton; return singleton;
    };
public:
    // MANIPULATORS
    /// Add a new specification, called at init time
    static void	addSpec (const char* name, VregsSpecInfo* specp) {
	sByName().insert(make_pair(string(name),specp));
    }

    // MANIPULATORS
    /// Iterate across all VregsSpecInfo's.
    class iterator {
	ByNameMap::iterator   s_nameIt;
    public:
	iterator(ByNameMap::iterator nameIt) : s_nameIt(nameIt) {};
	inline iterator operator++() {++s_nameIt; return *this;};	///< prefix
	inline operator VregsSpecInfo* () const { return (s_nameIt->second); };
    };
    static iterator	specsBegin() { return sByName().begin(); }	///< Begin iterator across all specs
    static iterator	specsEnd()   { return sByName().end(); }		///< End iterator across all specs
    // ACCESSORS
};

#endif

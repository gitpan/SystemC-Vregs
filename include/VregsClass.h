// $Id: VregsClass.h 49231 2008-01-03 16:53:43Z wsnyder $ -*- C++ -*-
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
/// \brief Vregs: Common classes used by all _class.h files
///
/// AUTHOR:  Wilson Snyder
///
//======================================================================

#ifndef _VREGSCLASS_H_
#define _VREGSCLASS_H_

#include "VregsDefs.h"

#ifdef __cplusplus
#include <iostream>
using namespace std;
#endif

//======================================================================
// Standard types

#ifndef _NINT32_T_
#define _NINT32_T_ 1
typedef void     nvoid_t;   ///< Pointer to data stored in network order
typedef uint8_t  nint8_t;   ///< Uint stored in network order, bytes are always identical
typedef uint16_t nint16_t;  ///< Uint stored in network order
typedef uint32_t nint32_t;  ///< Uint stored in network order
typedef uint64_t nint64_t;  ///< Uint stored in network order
#endif

#ifndef _ADDRESS_T
typedef uint64_t address_t; ///< Register address
//typedef uint32_t address_t;
#endif

#ifndef	_SIZE64_T
typedef address_t size64_t; ///< Size of register in bytes
#define _SIZE64_T
#endif

//======================================================================
// Macros to control compile-time debugging options

#ifndef VREGS_ENUM_DEF_INITTER
/// Initialize a enumeration value
# define VREGS_ENUM_DEF_INITTER(invalidValue)
//	: m_e(invalidValue)
#endif

#ifndef VREGS_WORDIDX_CHK
/// Check a word index is within bounds
# define VREGS_WORDIDX_CHK(TypeName, numWords, idx)
//	{ if (idx >= numWords)
//	   cerr <<"Setter " #TypeName ".w(" <<idx <<", val) arg1 is beyond "
//		<<numWords <<"-word struct.\n"; }
#endif

#ifndef VREGS_SETFIELD_CHK
/// Check a field index is within bounds
# define VREGS_SETFIELD_CHK(identStr, value, u_maxVal)
//	{ assert(value <= u_maxVal); } // identStr is "Structname.fieldName"
#endif

#ifndef VREGS_STRUCT_DEF_CTOR
/// Initialize a structure member
# define VREGS_STRUCT_DEF_CTOR(TypeName, numWords)
//	TypeName () { for (int i=0; i<numWords; i++) w(i, 0xdeadbeef); }
#endif

//======================================================================

#ifndef COUT
#define COUT cout
#endif
#ifndef OStream
#define OStream ostream
#endif

//======================================================================
// VregsOstream
/// Vregs Output Stream for dumping of structures in << operators.
////
/// This class is used so we can do:
///	COUT << "structure= " << vregs_object.dump() << " etc...";
/// To get the dump() to work, the dump() function should return a VregsOstream object
/// templated to the type of the vregs_object.  However, that causes compile times
/// to explode, so we just store a void* and cast in the vregs output.
/// We then define a operator to take the VregsOstream object and put it out.

#ifdef __cplusplus
template <class T>
class VregsOstream {
    const void*	m_obj;		///< Object to dump
    const char*	m_prefix;	///< Text to place in front of new lines
public:
    inline VregsOstream(const void* obj, const char* prefix)
	: m_obj(obj), m_prefix(prefix) {};
    inline const void* obj() const { return m_obj; }
    inline const char* prefix() const { return m_prefix; }
};
#endif

#endif //guard

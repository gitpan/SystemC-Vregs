// $Id: VregsClass.h,v 1.5 2001/09/19 15:12:46 wsnyder Exp $ -*- C++ -*-
//======================================================================
//
// This program is Copyright 2001 by Wilson Snyder.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of either the GNU General Public License or the
// Perl Artistic License, with the exception that it cannot be placed
// on a CD-ROM or similar media for commercial distribution without the
// prior approval of the author.
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
// DESCRIPTION: Vregs: Common classes used by all _class.h files
//======================================================================

#ifndef _VREGSCLASS_H_
#define _VREGSCLASS_H_

#include <iostream>

//======================================================================
// Standard types

#ifndef _NINT32_T_
#define _NINT32_T_ 1
typedef void     nvoid_t;   // Pointer to data stored in network order
typedef uint8_t  nint8_t;   // Always identical
typedef uint16_t nint16_t;  // Uint stored in network order
typedef uint32_t nint32_t;  // Uint stored in network order
typedef uint64_t nint64_t;  // Uint stored in network order
#endif

#ifndef _ADDRESS_T
//typedef uint64_t address_t;
typedef uint32_t address_t;
#endif

//======================================================================
// VregsOstream

#ifndef COUT
#define COUT cout
#endif
#ifndef OStream
#define OStream ostream
#endif

// This class is used so we can do:
//	COUT << "structure= " << vregs_object.dump() << " etc...";
// To get the dump() to work, the dump() function should return a VregsOstream object
// templated to the type of the vregs_object.  However, that causes compile times
// to explode, so we just store a void* and cast in the vregs output.
// We then define a operator to take the VregsOstream object and put it out.
template <class T>
class VregsOstream {
    const void*	m_obj;
    const char*	m_prefix;
public:
    inline VregsOstream(const void* obj, const char* prefix)
	: m_obj(obj), m_prefix(prefix) {};
    inline const void* obj() const { return m_obj; }
    inline const char* prefix() const { return m_prefix; }
};

#endif //guard

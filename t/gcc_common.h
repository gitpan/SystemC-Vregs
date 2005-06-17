// -*- C++ -*-
// $Revision: 1.19 $$Date: 2005-06-17 14:45:25 -0400 (Fri, 17 Jun 2005) $$Author: wsnyder $
// DESCRIPTION: C++ file compiled as part of test suite
//
// Copyright 2001-2005 by Wilson Snyder.  This program is free software;
// you can redistribute it and/or modify it under the terms of either the GNU
// General Public License or the Perl Artistic License.

#include <stdlib.h>
typedef unsigned int uint32_t;
#if defined(__WORDSIZE) && (__WORDSIZE == 64)
typedef unsigned long int uint64_t;
typedef unsigned long int Address;
#else
typedef unsigned long long uint64_t;
typedef unsigned long long Address;
#endif

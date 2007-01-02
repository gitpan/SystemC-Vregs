// -*- C++ -*-
// $Id: gcc_common.h 29376 2007-01-02 14:50:38Z wsnyder $
// DESCRIPTION: C++ file compiled as part of test suite
//
// Copyright 2001-2007 by Wilson Snyder.  This program is free software;
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

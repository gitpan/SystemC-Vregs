// $Id: vderegs.cpp 49231 2008-01-03 16:53:43Z wsnyder $  -*- C++ -*-
//====================================================================
//
// Copyright 2002-2008 by Wilson Snyder <wsnyder@wsnyder.org>.  This
// program is free software; you can redistribute it and/or modify it under
// the terms of either the GNU Lesser General Public License or the Perl
// Artistic License.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//                                                                           
//====================================================================
///
/// \file
/// \brief Vregs Utility: Dump vregs structures from hex info 
///
/// AUTHOR:  Wilson Snyder
///
//====================================================================

#include <stdio.h>
#include <unistd.h>
#include <getopt.h>
#include <string>
#include <sstream>
#include <iomanip>
#include <netinet/in.h>  //ntoh
#include <readline/readline.h>
#include <readline/history.h>

#include "VregsRegInfo.h"

//======================================================================

/// Look across all specifications for specified information

class VregsAllSpecInfo {
private:
    static int s_col;
    // METHODS
    static void firstCol(const char* show) {
	if (s_col) COUT<<endl;
	s_col = 0;
	COUT<<show;
    }
    static void showName(const char* className) {
	if (s_col==3) firstCol("");
	if (s_col==0) COUT<<"    "; 
	++s_col;
	COUT<<setw(25)<<left<<setfill(' ')<<className;
    }
public:
    static void dumpClassNames() {
	for (VregsSpecsInfo::iterator iter = VregsSpecsInfo::specsBegin();
	     iter != VregsSpecsInfo::specsEnd(); ++iter) {
	    VregsSpecInfo* specp = iter;
	    firstCol(specp->name()); COUT<<":"<<endl;

	    for (int i=0; i<specp->numClassNames(); i++) { 
		showName(specp->classNames()[i]);
	    }
	}
    }

    static const char* getSpecName(const char* className) {
	for (VregsSpecsInfo::iterator iter = VregsSpecsInfo::specsBegin();
	     iter != VregsSpecsInfo::specsEnd(); ++iter) {
	    VregsSpecInfo* specp = iter;
	    if (specp->isClassName(className)) return specp->name();
	}
	return NULL;
    }

    static bool isClassName(const char* className) {
	return getSpecName(className)!=NULL;
    }

    static void   dumpClass(const char* className, void* datap,
		     OStream& ost=COUT, const char* pf="\n\t") {
	for (VregsSpecsInfo::iterator iter = VregsSpecsInfo::specsBegin();
	     iter != VregsSpecsInfo::specsEnd(); ++iter) {
	    VregsSpecInfo* specp = iter;
	    if (specp->isClassName(className)) {
		specp->dumpClass(className, datap, ost, pf);
	    }
	}
    }
};

int VregsAllSpecInfo::s_col = 0;

//======================================================================

struct VDeregs {
    static const unsigned MAX_WORDS = 1000;

    size_t	m_words;
    size_t	m_structWords;
    string	m_structName;
    bool	m_attrNetOrder;
    bool	m_opt_multiMode;
    bool	m_opt_prettyForm;
    uint32_t	m_w [MAX_WORDS];

    VDeregs() {
	m_words = 0;
	m_structWords	= MAX_WORDS;  // Varsize
	m_structName	= "Message";
	m_attrNetOrder	= true;
	m_opt_multiMode	= false;
	m_opt_prettyForm = false;
    };
    // METHODS
    void getOptions(int argc, char* argv[]);
    bool chooseStruct();
    bool chooseWords();
    void dumpStruct();
    void setWord(unsigned w, uint32_t val) {
	if (m_attrNetOrder) m_w[w] = htonl(val);
	else m_w[w] = val;
    }
    uint32_t word(unsigned w) {
	return (m_attrNetOrder ? ntohl(m_w[w]) : m_w[w]);
    }
    // PARSING
    string getLine(const char*);
    bool gotExit(string in) {
	return (in=="q" || in=="x" || in=="quit" || in=="exit");
    }
    bool gotHex(string& in, uint32_t& val) {
	while (in!="" && isspace(in[0])) in.erase(0,1);
	if (in[0]=='0' && (in[1]=='x' || in[1]=='X')) in.erase(0,2);
	if (in!="" && isxdigit(in[0])) {
	    in = "0x" + in;
	    char* endpt;
	    val = strtoul(in.c_str(),&endpt,16);
	    in = in.erase(0,(endpt-in.c_str()));
	    return true;
	}
	return false;
    }
};

string VDeregs::getLine(const char* prompt) {
    string edited;

    const char* in;
    while (1) {
	in = readline(prompt);
	if (in == NULL || gotExit(string(in))) {COUT<<endl; exit(0);}
	if (string(in)=="netorder") { m_attrNetOrder = true; }
	else if (string(in)=="hostorder") { m_attrNetOrder = false; }
	else break;
    }
    
    // Strip [anything_like_a_timestamp]
    const char* cp=in;
    while (isspace(*cp)) cp++;
    for (; *cp; cp++) {
	if (*cp == '[') {
	    while (*cp && *cp!=']') cp++;
	    if (*cp==']') cp++;
	    // For "[index]=data" format, skip one "=" too.
	    if (*cp=='=') cp++;
	}
	edited += *cp;
    }
    return edited;
}

bool VDeregs::chooseStruct() {
    if (! m_opt_multiMode) {
	COUT<<"Enter structure name.  ? for list.  q exits.\n";
    }
    while (1) {
	stringstream ss;
	if (! m_opt_multiMode) {
	    ss << "Str name ["<<m_structName<<"]: ";
	}

	string in = getLine(ss.str().c_str());
	if (in=="") break;
	else if (in=="?") {
	    VregsAllSpecInfo::dumpClassNames();
	    COUT<<endl;
	}
	else if (VregsAllSpecInfo::isClassName(in.c_str())) {
	    m_structName = in;
	    m_structWords = MAX_WORDS;
	    m_words = 0;
	    m_attrNetOrder = false;  // Should read it from class name
	    break;
	} else {
	    COUT<<"  What's \""<<in<<"\"?"<<endl;
	}
    }
    return true;
}

bool VDeregs::chooseWords() {
    if (! m_opt_multiMode) {
	COUT<<"  Enter each word of structure in hex.  Empty line or q when done.\n";
	COUT<<"  Multiple words may be separated by spaces.  Anything in [] are ignored.\n";
    }

    for (unsigned w=0; w<MAX_WORDS; w++) m_w[w] = 0;
    m_words=0;
    while (1) {
	stringstream ss;
	if (! m_opt_multiMode) {
	    ss <<"  "<<m_structName
	       <<".w"<<dec<<setw(2)<<setfill('0')<<m_words
	       <<" [LAST]: ";
	}
	string in = getLine(ss.str().c_str());
	uint32_t datum;
	if (in=="") {
	    if (m_words==0) return false;	// No data, take it as a "q"
	    else break;
	}
	else {
	    while (gotHex(in, datum)) {
		setWord(m_words, datum);
		m_words++;
		if (m_words == m_structWords) break;
	    }
	    while (in!="" && isspace(in[0])) in.erase(0,1);
	    if (in != "") {
		COUT<<"  What's \""<<in<<"\"?"<<endl;
	    }
	}
    }
    return true;
}

void VDeregs::dumpStruct() {
    if (! m_opt_multiMode) {
	COUT <<"------------------\n";
	COUT <<"  " <<m_structName <<" in HEX: ";
	COUT <<(m_attrNetOrder?"(Network order)\n":"(Host order)\n");
	for (unsigned w=0; w<m_words; w++) {
	    COUT<<"\tw"<<dec<<setw(2)<<setfill('0')<<w
		<<": 0x"<<hex<<setw(2)<<setfill('0')<<word(w)
		<<endl;
	}
    }

    if (! m_opt_multiMode)
	COUT <<"  " <<m_structName <<" dumped:\n";
    COUT <<"\t" <<hex;
    VregsAllSpecInfo::dumpClass(m_structName.c_str(),&m_w,COUT);
    COUT <<(m_opt_multiMode ? "\nEOM\n" : "\n\n");
}

//======================================================================
// MAIN

int main (int argc, char* argv[]) {
    VDeregs dregs;
    dregs.getOptions(argc, argv);

    while (dregs.chooseStruct()) {
	while (dregs.chooseWords()) {
	    dregs.dumpStruct();
	    if (dregs.m_opt_multiMode) break;
	}
    }
}

static struct option long_options[] = {
    { "help",		no_argument,	NULL, 'h' },
    { "multi",		no_argument, 	NULL, 'M'|0x80 },
    { "pretty",		no_argument, 	NULL, 'P'|0x80 },
    { "version",	no_argument,	NULL, 'v' },
    { NULL,		0,		NULL, 0 },
};

static void version() {
    COUT <<"vderegs: #$Id: vderegs.cpp 49231 2008-01-03 16:53:43Z wsnyder $" <<endl;
}

static void usage() {
    version();
    COUT <<endl;
    COUT <<"vderegs is part of SystemC::Vregs, available from http://www.veripool.com/\n" <<endl;
    COUT << "Usage: dedfa [OPTION]...\n"
	 << "--multi     \tPrint \"EOM\\n\" to frame each response (for piped I/O)\n"
	 << "--pretty    \tJust print the message's ostream operator\n"
	 << "--version   \tDisplay program version\n"
	 << "-h|--help   \tDisplay this usage summary\n"
	 << endl;
    COUT << "Vregs command line options\n"
	 << "  q        \tQuit\n"
	 << "  netorder \tChange to network order for hex entry\n"
	 << "  hostorder \tChange to host order for hex entry\n"
	 << endl;
    exit(1);
}

void VDeregs::getOptions(int argc, char* argv[]) {
    int c = 0;
    while (( c = getopt_long(argc, argv, "h", long_options, (int*)0) )
	   != EOF) {
	switch (c) {
	case 'M'|0x80:	m_opt_multiMode = true;
	    break;
	case 'P'|0x80:	m_opt_prettyForm = true;
	    break;
	case 'v':
	    version();
	    exit(1);
	    break;
	case 'h':
	case '?':
	default:
	    usage();
	    exit(1);
	    break;
	}
    }
}

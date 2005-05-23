# $Revision: 1.133 $$Date: 2005-05-23 10:23:27 -0400 (Mon, 23 May 2005) $$Author: wsnyder $
# Author: Wilson Snyder <wsnyder@wsnyder.org>
######################################################################
#
# Copyright 2001-2005 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
######################################################################

package SystemC::Vregs::Outputs;
use File::Basename;
use Carp;
use vars qw($VERSION);
$VERSION = '1.261';

use SystemC::Vregs::Number;
use SystemC::Vregs::Language;
use strict;

# We simply add to the existing package...
package SystemC::Vregs;

######################################################################
######################################################################
# Files
package SystemC::Vregs::File;
use File::Basename;
use vars qw(@ISA);
@ISA = qw(SystemC::Vregs::Language);
use strict;
use Carp;

sub open {
    my $class = shift;
    # General routine for opening output file and starting header

    my %params = @_;
    $params{language} or croak "%Error: No language=> specified,";

    my $self = $class->SUPER::new(verbose=>1,
				  %params);

    my ($name,$path,$suffix) = fileparse($self->{filename},'\..*');
    my $template_filename = $path.$name."__template".$suffix;
    print "Check Template File $template_filename\n" if $SystemC::Vregs::Debug;
    if (-r $template_filename) {
	#$self->{template}->read (filename=>$template_filename);
    }

    if (!$self->{noheader}) {
	$self->print("// -*- C++ -*-\n") if ($self->{C});
	$self->print("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n") if ($self->{XML});
	$self->comment("DO NOT EDIT -- Generated automatically by vregs\n");
	if ($self->{C}) {
	    $self->comment_pre("\\file\n");
	    $self->comment_pre("\\brief Register Information: Generated automatically by vregs\n");
	} else {
	    $self->comment("DESC"."RIPTION: Register Information: Generated automatically by vregs\n");
	}
	$self->comment_pre("\n");
    }

    if ($self->{rules}) {
	$self->{rules}->filehandle($self);
	foreach my $rfile ($self->{rules}->filenames()) {
	    $rfile = basename($rfile,"^");
	    $self->comment_pre("See SystemC::Vregs::Rules file: $rfile\n");
	}
	$self->comment_pre("\n");
    }

    $self->{rules}->execute_rule ('any_file_before', 'any_file', $self) if $self->{rules};

    return $self;
}

sub close {
    my $self = shift;
    # General routine for closing output file

    $self->close_prep();

    $self->{rules}->execute_rule ('any_file_after', 'any_file', $self) if $self->{rules};

    if (!$self->{noheader}) {
	$self->print("\n");
	$self->comment ("DO NOT EDIT -- Generated automatically by vregs\n");
    }

    $self->SUPER::close();
}

sub private_not_public {
    my $self = shift;
    my $private = shift;
    my $pack = shift;
    my $enabled = (defined $pack->{rules}{protect_rdwr_only}
		   ? $pack->{rules}{protect_rdwr_only}
		   : $pack->{protect_rdwr_only});
    $private = 0 if !$enabled;
    # Print public: or private: depending on desired state
    if ($private && !$self->{private}) {
	$self->print ("protected:\n");
    }
    if (!$private && $self->{private}) {
	$self->print ("public:\n");
    }
    $self->set_private($private);
}

sub set_private {
    my $self = shift;
    my $private = shift;
    $self->{private} = $private;
}

sub printf_tabify {
    my $self = shift;
    my $line = sprintf(shift,@_);
    $self->print($self->tabify($line));
}

sub tabify {
    my $self = shift;
    my $line = join('',@_);
    # Convert any space-tabs to just tabs
    my $out='';
    my $col=0;
    my $spaces=0;
    for (my $i=0; $i<length($line); $i++) {
	my $c = substr($line,$i,1);
	if ($c eq "\n") {
	    $out .= $c;
	    $col = 0;
	    $spaces = 0;
	} elsif ($c eq "\t") {
	    my $wantcol = int(($col+$spaces+8)/8)*8;
	    while ($wantcol > $col) {
		$col = int(($col+8)/8)*8;
		$out .= "\t";
	    }
	    $spaces = 0;
	} elsif ($c eq " ") {
	    $spaces++;
	} else {
	    if ($spaces) { $out .= ' 'x$spaces; $col+=$spaces; $spaces=0; }
	    $out .= $c;
	    $col++;
	}
    }
    return $out;
}

# Pass throughs to SystemC::Vregs
# Called by user templates, so no self
#sub write_enum { enum_write ($self, $fl); }

package SystemC::Vregs;

######################################################################
######################################################################
######################################################################
######################################################################

sub SystemC::Vregs::Enum::enum_write {
    my $self = shift;
    my $pack = shift;
    my $fl = shift;

    my $clname = $self->{name} || "x";
    $pack->{rules}->execute_rule ('enum_begin_before', $clname, $self);
    $fl->print ("class $clname {\n");
    $fl->print ("public:\n");
    $pack->{rules}->execute_rule ('enum_begin_after', $clname, $self);
    
    $fl->print ("    enum en {\n");
    foreach my $fieldref ($self->fields_sorted()) {
	$fl->printf ("\t%-13s = 0x%x,"
		     ,$fieldref->{name},$fieldref->{rst_val});
	if ($pack->{comments}) {
	    $fl->printf ("\t");
	    $fl->comment_post ($fieldref->{desc});
	}
	$fl->printf ("\n");
    }
    # Perhaps this should just be added to the data structures?
    # note no comma to make C happy
    $fl->printf("\t%-13s = 0x%x\t","MAX", (1<<$self->{bits}));
    $fl->comment_post ("MAXIMUM+1");
    $fl->print ("\n    };\n");
    $pack->{rules}->execute_rule ('enum_end_before', $clname, $self);
    $fl->print ("  };\n");
    $pack->{rules}->execute_rule ('enum_end_after', $clname, $self);
    $fl->print ("\n");
}

sub SystemC::Vregs::Enum::enum_cpp_write {
    my $self = shift;
    my $pack = shift;
    my $fl = shift;

    my $clname = $self->{name} || "x";

    $fl->print("//${clname}\n",);
    $pack->{rules}->execute_rule ('enum_cpp_before', $clname, $self);

    for my $desc (0..1) {
	next if $desc && !$self->{attributes}{descfunc};

	$fl->printf ("const char* ${clname}::%s () const {\n",
		     ($desc ? 'description':'ascii'));
	$fl->print ("    switch (m_e) {\n");
	my %did_values;
	foreach my $fieldref ($self->fields_sorted()) {
	    next if $fieldref->{omit_description};
	    if ($did_values{$fieldref->{rst_val}}) {
		$fl->printf ("\t//DUPLICATE: ");
	    } else {
		$fl->printf ("\t");
	    }
	    $fl->printf ("case %s: return(\"%s\");\n"
			 ,$fieldref->{name}
			 ,($desc ? $fieldref->{desc} : $fieldref->{name}));
	    $did_values{$fieldref->{rst_val}} = 1;
	}
	$fl->print ("  default: return (\"?E\");\n");
	$fl->print ("  }\n");
	$fl->print ("}\n\n");
    }

    $pack->{rules}->execute_rule ('enum_cpp_after', $clname, $self);
}

######################################################################
######################################################################
######################################################################
#### Saving

sub attribute_value {
    my $pack = shift;
    my $regref = shift;
    my $attr = shift;
    return $regref->{attributes}{$attr} if defined $regref->{attributes}{$attr};
    return $regref->{inherits_typeref}{attributes}{$attr}
        if (defined $regref->{inherits_typeref}
	    && defined $regref->{inherits_typeref}{attributes}{$attr});
    return $pack->{attributes}{$attr} if defined $pack->{attributes}{$attr};
    return undef;
}

sub SystemC::Vregs::Type::_class_h_write {
    my $self = shift;
    my $pack = shift;
    my $fl = shift;
    my $clname = $self->{name} || "x";

    my $netorder = attribute_value($pack, $self, 'netorder') || 0;
    my $stretchable = attribute_value($pack, $self, 'stretchable') || 0;
    my $ntohl = ($netorder ? "ntohl" : "");
    my $htonl = ($netorder ? "htonl" : "");
    my $uint  = ($netorder ? "nint32_t" : "uint32_t");
    my $uchar = ($netorder ? "nint8_t" : "uint8_t");
    my $toBytePtr = ($netorder ? "castNBytep" : "castHBytep");

    my $inh = "";
    $inh = " : $self->{inherits}" if $self->{inherits};
    my $words = $self->{words};

    $pack->{rules}->execute_rule ('class_begin_before', $clname, $self);
    $fl->print("struct $clname$inh {\n");
    $fl->set_private(0);	# struct implies public:
    $pack->{rules}->execute_rule ('class_begin_after', $clname, $self);

    if ($inh ne "") {
	my $inhType = $self->{inherits_typeref} or
	    die "%Error: Missing typeref for inherits${inh}.\n";
	# Verify same byte ordering.
	my $inh_netorder = attribute_value($inhType->{pack}, $inhType, 'netorder') || 0;
	if ($inh_netorder ne $netorder) {
	    die ("%Error: $clname netorder=$netorder doesn't match $inh_netorder"
		 ." inherited from $inhType->{name}.\n");
	}
	$fl->print("    // w() and $toBytePtr() inherited from $self->{inherits}::\n");
	# Correct for any size difference
	(defined $inhType->{words}) or die "%Error: Missed words compute()\n";
	if (($self->{words}||0) > $inhType->{words}) {
	    # Ensure the parent type disabled array bounds checking.
	    my $inh_stretchable =
		attribute_value($inhType->{pack}, $inhType, 'stretchable') || 0;
	    if (! $inh_stretchable) {
		die sprintf("%%Error: Base class %s (%d words) needs '-stretchable'"
			    ." since %s has %d words.\n",
			    $inhType->{name}, $inhType->{words},
			    $clname, $self->{words});
	    }
	    $fl->printf("  protected: uint32_t m_wStretch[%d];   // Bring base size up\n"
			."  public:\n",
			$self->{words} - $self->{inherits_typeref}->{words});
	}
    } else {
	$fl->print("  protected: ${uint} m_w[${words}];"
		   .($stretchable ? "  // Attr '-stretchable'\n" : "\n")
		   ."  public:\n"
		   ."    inline uint32_t w(int b) const { return (${ntohl}(m_w[b])); }\n"
		   ."    inline void w(int b, uint32_t val) {");
	if (! $stretchable) {
	    $fl->print(" VREGS_WORDIDX_CHK($clname, $words, b)\n"
		       ."\t\t\t\t\t");
	}
	$fl->print(" m_w[b] = ${htonl}(val); }\n");
	$fl->print("    inline ${uchar}* ${toBytePtr}() {\n"
		   ."\treturn reinterpret_cast<${uchar}*>(&m_w[0]); }\n"
		   ."    inline const ${uchar}* ${toBytePtr}() const {\n"
		   ."\treturn reinterpret_cast<const ${uchar}*>(&m_w[0]); }\n");
    }
    if ($clname =~ /^R_/) {
	# Write only those bits that are marked access writable
	my @wr_masks;
	for (my $word=0; $word<$self->{words}; $word++) {
	    $wr_masks[$word] = 0;
	    for (my $bit=$word*$self->{pack}->{data_bits};
		 $bit<(($word+1)*$self->{pack}->{data_bits});
		 $bit++) {
		my $bitent = $self->{bitarray}[$bit];
		next if !$bitent;
		$wr_masks[$word] |= (1<<$bit) if ($bitent->{write});
	    }
	}
	if ($self->{words}<2) {
	    $fl->printf("    static const uint32_t BITMASK_WRITABLE = 0x%08x;\n", $wr_masks[0]);
	    $fl->printf("    inline void wWritable(int b, uint32_t val) {"
			." w(b,(val&BITMASK_WRITABLE)|(w(b)&~BITMASK_WRITABLE)); };\n");
	} else {
	    # Idiots at Greenhills Compilers don't allow
	    # static const uint32_t BITMASK_WRITABLE[] = {...};
	    $fl->printf("    inline uint32_t wBitMaskWritable(int b) {\n");
	    for (my $word=0; $word<$self->{words}; $word++) {
		$fl->printf("\tif (b==$word) return 0x%08x;\n", $wr_masks[$word]);
	    }
	    $fl->printf("\treturn 0; }\n");
	    $fl->printf("    inline void wWritable(int b, uint32_t val) {"
			." w(b,(val&wBitMaskWritable(b))|(w(b)&~wBitMaskWritable(b))); };\n");
	}
    }

    my @resets=();
    push @resets, sprintf("\t%s::fieldsReset();\n", $self->{inherits}) if $self->{inherits};
    my @dumps = ();
    $fl->printf("\n");

    foreach my $bitref ($self->fields_sorted()) {
	next if $bitref->ignore;
	(my $lc_mnem = $bitref->{name}) =~ s/^(.)/lc $1/xe;
	my $typecast = "";
	$typecast = $bitref->{type} if $bitref->{cast_needed};
	$typecast = "(void*)" if $bitref->{type} eq 'void*';	# Damn C++
	my $L = ($bitref->{numbits}>32)?'LL':'';

        my $extract = "";
        my $deposit = "";
	if ($bitref->{numbits} < 32 && $bitref->{numbits} > 1) {
	    # Don't bother adding code to check boolean fields.
	    $deposit .=
		sprintf(" VREGS_SETFIELD_CHK%s(\"%s.%s\", b, 0x%xU)\n\t\t\t\t\t\t",
			($L ? "_$L" : ""), $clname, $lc_mnem,
			(1 << $bitref->{numbits})-1);
	}
        foreach my $bitrange (@{$bitref->{bitlist_range_32}}) {
	    my ($msb,$lsb,$nbits,$srcbit) = @{$bitrange};
	    my $low_mod = $lsb % 32;
	    my $high_mod = $msb % 32;
	    my $word = int($lsb/32);
	    (int($msb/32)==$word) or die "%Error: One _range cannot span two words\n";
	    my $deposit_mask = (1<<$nbits)-1;
	    $deposit_mask = 0xffffffff if $nbits==32;
	    my $mask = $deposit_mask << $low_mod;
	    $mask = 0xffffffff if $high_mod==31 && $low_mod==0;
	    
	    $extract .= " |" if $extract ne "";
	    if ($high_mod==31 && $low_mod==0 && $srcbit==0) {
		# Whole word, skip the B.S.
		$extract .= " w(${word})";
		$deposit .= " w(${word}, (uint32_t)(b));";
	    } else {
		my $tobit = "<<$srcbit)";
		$tobit = "" if $srcbit==0;
		my $frombit = ">>$srcbit)";
		$frombit = "" if $srcbit==0;
		$extract .= sprintf " %s(w(${word})>>${low_mod} & 0x%x$L)$tobit"
		    , ($tobit?"(":""), $deposit_mask;
		$deposit .= sprintf " w(${word}, (w(${word})&0x%08x$L) | ((%sb$frombit&0x%x$L)<<${low_mod}));"
		    , (~$mask&0xffffffff), ($frombit?"(":""), $deposit_mask;
	    }
	}

	if ($bitref->{rst} ne 'X') {
	    my $rst = $bitref->{rst};
	    $rst = 0 if ($rst =~ /^FW-?0$/);
	    if ($rst =~ /^[a-z]/i && $bitref->{type}) {	# Probably a enum value
		$rst = "$bitref->{type}::$rst";
	    }
	    #$fl->printf("\tstatic const %s %s = %s;\n", $bitref->{type},
	    #		uc($lc_mnem)."_RST", $rst);
	    push @resets, sprintf("\t%s(%s);\n", $lc_mnem, $rst);
	}

	# Mask after shifting on reads, so the mask is a smaller constant.
	$fl->private_not_public ($bitref->{access} !~ /R/, $pack);
	my $typEnd = 11 + length $bitref->{type};
	$fl->printf("    inline %s%s%-13s () const ",
		    $bitref->{type}, ($typEnd < 16 ? "\t\t" : $typEnd < 24 ? "\t" : " "),
		    $lc_mnem);
	$fl->print("{ return ${typecast}(${extract} ); }");
	#printf $fl "\t//%s", $bitref->{desc};
	$fl->printf("\n");

	$fl->private_not_public ($bitref->{access} !~ /W/, $pack);
	$fl->printf("    inline void\t\t%-13s (%s b) ", $lc_mnem, $bitref->{type});
	$fl->print("{${deposit} }");
	#printf $fl "\t//%s", $bitref->{desc};
	$fl->printf("\n");

	push @dumps, "\"$bitref->{name}=\"<<$lc_mnem()"
    }

    $fl->printf("\n");
    $fl->private_not_public (0, $pack);
    $fl->printf("    VREGS_STRUCT_DEF_CTOR(%s, %s)\t// (typeName, numWords)\n",
		$clname, $words);
    $fl->print("    void fieldsZero () {\n");
    if ($words>=8) {
	$fl->print("\tfor (int i=0; i<${words}; i++) w(i,0);\n");
    } else {
	$fl->print("\t");
	for (my $i=0; $i<$words; $i++) { $fl->print("w($i,0); "); }
	$fl->print("\n");
    }
    $fl->print("    };\n");
    $fl->print("    void fieldsReset () {\n",
	       "\tfieldsZero();\n",
	       @resets,
	       "    };\n");
    $fl->print("    inline bool operator== (const ${clname}& rhs) const {\n",
	       "\tfor (int i=0; i<${words}; i++) { if (m_w[i]!=rhs.m_w[i]) return false; }\n",
	       "\treturn true;\n",
	       "    };\n");
    # The dump functions are in a .cpp file (no inline), as there was too much code
    # bloat, and it was taking a lot of compile time.
    $fl->print("    typedef VregsOstream<${clname}> DumpOstream;\n",
	       "    DumpOstream dump(const char* prefix=\"\\n\\t\") const;\n",
	       "    OStream& _dump(OStream& lhs, const char* pf) const;\n",
	       "    void dumpCout() const; // For GDB\n",);
    
    # Put const's last to avoid GDB stupidity
    $fl->private_not_public (0, $pack);
    $fl->printf("    static const size_t SIZE = %d;\n", $words*4);

    $pack->{rules}->execute_rule ('class_end_before', $clname, $self);
    $fl->print("};\n");
    $pack->{rules}->execute_rule ('class_end_after', $clname, $self);

    $fl->print("  OStream& operator<< (OStream& lhs, const ${clname}::DumpOstream rhs);\n",);

    $fl->print("\n");
}

sub class_h_write {
    # Dump type definitions
    my $self = shift;

    my $fl = SystemC::Vregs::File->open(rules => $self->{rules},
					language=>'C', @_);

    $fl->include_guard();
    $fl->print("\n");
    $fl->comment("package $self->{name}\n");
    $fl->print("\n");

    $self->{rules}->execute_rule ('file_body_before', 'file_body', $self);

    $fl->print("// Vregs library Files:\n");
    foreach my $packref (@{$self->{libraries}}) {
	$fl->print("#include \"$packref->{name}_class.h\"\n");
    }

    $fl->print("\n\n");

    foreach my $classref ($self->enums_sorted) {
	$classref->enum_write ($self, $fl);
    }

    $fl->print("\n\n");
    # Bitbashing done verbosely to avoid slow preprocess time
    # We could use bit structures, but they don't work on non-contiguous fields

    # Sorted first does base classes, then children
    foreach my $typeref ($self->types_sorted) {
	$typeref->_class_h_write($self, $fl);
    }

    $self->{rules}->execute_rule ('file_body_after', 'file_body', $self);

    $fl->close();
}

######################################################################
######################################################################
######################################################################

sub SystemC::Vregs::Type::_class_cpp_write {
    my $self = shift;
    my $pack = shift;
    my $fl = shift;
    my $clname = $self->{name} || "x";

    my @dumps = ();

    my $fields_lcFirst = $self->{attributes}{lcfirst} || 0;
    foreach my $bitref ($self->fields_sorted()) {
	next if $bitref->ignore;
	(my $lc_mnem = $bitref->{name}) =~ s/^(.)/lc $1/xe;
	if ($self->{inherits_typeref}
	    && $self->{inherits_typeref}->find_bit($bitref->{name})) {
	    # It's printed by the base class.
	} elsif ($fields_lcFirst) {
	    push @dumps, "\"$lc_mnem=\"<<$lc_mnem()";
	} else {
	    push @dumps, "\"$bitref->{name}=\"<<$lc_mnem()";
	}
    }

    $fl->print("//${clname}\n",);
    $pack->{rules}->execute_rule ('class_cpp_before', $clname, $self);
    my $dumpName = $SystemC::Vregs::Dump_Routine_Name || "_dump";
    $fl->print("${clname}::DumpOstream ${clname}::dump(const char* prefix) const {\n",
	       "    return DumpOstream(this,prefix);\n",
	       "}\n");
    $fl->print("OStream& operator<< (OStream& lhs, const ${clname}::DumpOstream rhs) {\n",
	       "    return ((${clname}*)rhs.obj())->${dumpName}(lhs,rhs.prefix());\n",
	       "}\n");

    $SystemC::Vregs::Do_Dump = 0;
    $pack->{rules}->execute_rule ('class_dump_before', $clname, $self);
    if ($SystemC::Vregs::Do_Dump) {
	$fl->printf("OStream& ${clname}::_dump (OStream& lhs, const char*%s) const {\n",
		    ((($#dumps>0) || $self->{inherits}) ? ' pf':''));
	$pack->{rules}->execute_rule ('class_dump_after', $clname, $self, \@dumps);
	$fl->print("    return lhs;\n"
		   ."}\n");
    }

    # For usage in GDB
    $fl->print("void ${clname}::dumpCout () const { COUT<<this->dump(\"\\n\\t\")<<endl; }\n",);
    $pack->{rules}->execute_rule ('class_cpp_after', $clname, $self);
    
    $fl->print("\n");
}

sub class_cpp_write {
    # Dump type definitions
    my $self = shift;

    my $fl = SystemC::Vregs::File->open(rules => $self->{rules},
					language=>'C', @_);

    $fl->print("\n");
    $fl->print("#include \"$self->{name}_class.h\"\n");
    $fl->print("\n");

    $self->{rules}->execute_rule ('class_cpp_file_before', 'file_body', $self);

    foreach my $classref ($self->enums_sorted) {
	$classref->enum_cpp_write ($self, $fl);
    }

    # Sorted first does base classes, then children
    foreach my $typeref ($self->types_sorted) {
	$typeref->_class_cpp_write($self, $fl);
    }

    $fl->close();
}

######################################################################
######################################################################
######################################################################

sub defs_write {
    my $self = shift;
    # Dump general register definitions

    $self->create_defines(1);
    my $fl = SystemC::Vregs::File->open(rules => $self->{rules},
					@_);
    $fl->comment_pre("\n");
    $fl->comment_pre("package $self->{name}\n");
    $fl->comment_pre("\n");

    $fl->comment_pre
	(("*"x70)."\n"
	 ."   General convention:\n"
	 ."     RA_{regname}     Register beginning address\n"
	 ."     RAE_{regname}    Register ending address + 1\n"
	 ."     RAC_{regname}    Number of entries in register\n"
	 ."     RAM_{regname}    Register region address mask\n"
	 ."     RRP_{regname}    Register RANGE spacing in bytes, if arrayed\n"
	 ."     RRS_{regname}    Register RANGE size, if arrayed\n"
	 ."\n"
	 ."     RBASEA_{regs}    Register common-prefix starting address\n"
	 ."     RBASEAE_{regs}   Register common-prefix ending address + 1\n"
	 ."     RBASEAM_{regs}   Register common-prefix bit mask\n"
	 ."\n"
	 ."     E_{enum}_{alias}           Value of enumeration encoding\n"
	 ."\n"
	 ."     CM{w}_{class}_WRITABLE     Mask of all writable bits\n"
	 ."     CB{w}_{class}_{field}_{f}  Class field starting bit\n"
	 ."     CE{w}_{class}_{field}_{f}  Class field ending bit\n"
	 ."     CR{w}_{class}_{field}_{f}  Class field range\n"
	 ."          {w}=32=bit word number,  {f}=field number if discontinuous\n"
	 );
    $fl->print("\n");

    $fl->include_guard();
    $fl->print("\n");

    $fl->print ("//Verilint  34 off //WARNING: Unused macro\n") if $fl->{Verilog};
    $fl->print("\n");

    my $firstauto = 1;
    foreach my $defref ($self->defines_sorted) {
	if ($firstauto && !$defref->{is_manual}) {
	    $fl->print("\n\n");
	    $fl->comment("Automatic Defines\n");
	    $firstauto = 0;
	}

	my $define  = $defref->{name};
	my $value   = $defref->{rst_val};
	my $comment = $defref->{desc};
	if ($fl->{C} && $define =~ /^C[BER][0-9]/) {
	    next;  # Skip for Perl/C++, not much point as we have structs
	}
	$value = $fl->sprint_hex_value_add0 ($value,$defref->{bits}) if (defined $defref->{bits});
	if ($fl->{Perl} && ($defref->{bits}||0) > 32) {
	    $fl->print ("#");
	    $comment .= " (TOO LARGE FOR PERL)";
	}
	if (($defref->{is_verilog} && $fl->{Verilog})
	    || ($defref->{is_perl} && $fl->{Perl})
	    || (!$defref->{is_verilog} && !$defref->{is_perl})) {
	    $fl->define ($define, $value, ($self->{comments}?$comment:""));
	}
    }

    $fl->close();
}

######################################################################

use vars qw($_Param_Write_Value_Bit32);

sub _param_write_value {
    my $self = shift;
    my $fl = shift;
    my $tohex = shift;

    # Create max value that fits in 32 bits, just once for speed
    $_Param_Write_Value_Bit32 ||= $self->{pack}->addr_const_vec(0xffffffff);  
    my $bit32 = $_Param_Write_Value_Bit32;

    my $rst_val = $self->{rst_val};
    $rst_val = sprintf("%X",$rst_val) if !ref $rst_val && $tohex;
    my $value   = $self->{val};
    my $bits    = $self->{bits};
    if (defined $bits && defined $value && ref $value) {
	$bits = 32 if ($bits==32
		       || $self->{pack}{param_always_32bits}
		       || ($value->Lexicompare($bit32)<=0));  # value<32 bits
	$value = Bit::Vector->new_Hex($bits, $value->to_Hex);
	$rst_val = $value->to_Hex;
    }
    return $fl->sprint_hex_value_add0 ($rst_val,$bits);
}

sub param_write {
    my $self = shift;
    # Dump general register definitions

    $self->create_defines(1);
    my $fl = SystemC::Vregs::File->open(language=>'Verilog',
					rules => $self->{rules},
					@_);

    #$fl->include_guard();  #no guards-- it may be used in multiple modules

    $fl->comment_pre
	(("*"x70)."\n"
	 ."\tRAP_{regname}           Register address as a parameter\n"
	 ."\tCMP_{regname}_WRITABLE  Register RdWr bit-mask as a parameter\n"
	 ."\n"
	 ."\tThis is useful in Verilog to allow extraction of bit\n"
	 ."\tranges, for example:\n"
	 ."\t\tif (myaddr == RAP_SOMEREG[31:15]) ...\n"
	 ."\n");

    $fl->print ("\n"
		."`ifdef NOTDEFINED\n"
		."module just_for_proper_indentation ();\n"
		."`endif\n"
		."\n"
		."//Verilint 175 off //WARNING: Unused parameter\n\n");

    foreach my $defref ($self->defines_sorted) {
	my $define  = $defref->{name};
	my $value   = $defref->{val};
	my $comment = $defref->{desc};
	    
	my $cmt = "";
	$cmt = "\t// ${comment}" if $self->{comments};

	if ($define =~ s/^(RA|CM)_/${1}P_/) {
	    my $prt_val = _param_write_value($defref, $fl);
	    $fl->printf ("   %s %-26s %13s%s\n",
			 ($self->{attributes}{v2k} ? 'localparam':'parameter'),
			 $define . " =", $prt_val.";",
			 $cmt
			 );
	}
    }

    foreach my $classref ($self->enums_sorted) {
	my @fields = ($classref->fields_sorted());
	my $i=0;
	foreach my $fieldref (@fields) {
	    if ($i==0) {
		$fl->printf ("   %s %s\n",
			     ($self->{attributes}{v2k} ? 'localparam':'parameter'),
			     "// synopsys enum En_$classref->{name}"
			     );
	    }
	    my $prt_val = _param_write_value($fieldref, $fl, 'tohex');
	    $fl->printf ("\t     %-26s %13s\n",
			 "EP_" . $classref->{name} . "_" . $fieldref->{name}." =",
			 $prt_val.(($i==$#fields) ? ";" : ","),
			 );
	    $i++;
	}
    }

    $fl->close();
}

######################################################################

sub hash_write {
    my $self = shift;
    # Dump hashes for perl

    my $fl = SystemC::Vregs::File->open(@_);
    $fl->include_guard();
    $fl->print("\n");
    $fl->print("package $self->{name};\n");
    $fl->print("\n");

    foreach my $eref ($self->enums_sorted) {
	$fl->print ('%'.$eref->{name}." = (\n");
	foreach my $fieldref ($eref->fields_sorted()) {
	    my $cmt = "";
	    $cmt = "\t# $fieldref->{desc}" if $self->{comments};
	    $fl->printf ("  0x%-4x => '%-20s%s\n"
			 ,$fieldref->{rst_val}
			 ,$fieldref->{name}."',"
			 ,$cmt);
	}
	$fl->print ("  );\n\n");
    }

    $fl->close();
}

######################################################################

sub info_h_write {
    my $self = shift;
    # Dump headers for pli routines

    my $fl = SystemC::Vregs::File->open(language=>'C',
					rules => $self->{rules},
					@_);
    $fl->include_guard();
    $fl->print ("\n"
		."class VregsRegInfo;\n"
		."\n");

    $fl->print ("class $self->{name}_info {\n"
		,"public:\n"
		,"    static void add_registers(VregsRegInfo* reginfop);\n"
	        ,"};\n\n");

    $fl->close();
}

sub info_cpp_write {
    my $self = shift;
    # Dump c pli routines

    $self->create_defines(1);
    my $fl = SystemC::Vregs::File->open(rules => $self->{rules},
					language=>'C', @_);

    $fl->print ("// Not for direct use -- VregsRegInfo.h provides all accessors\n"
		."\n");

    $self->{rules}->execute_rule ('info_cpp_file_before', 'file_body', $self);

    $fl->print ("#include \"VregsRegInfo.h\"\n"
		."#include \"$self->{name}_info.h\"\n"
	        ."\n");
		
    $fl->print ("//".('='x68)."\n\n");

    $fl->print ("void $self->{name}_info::add_registers(VregsRegInfo* rip)\n"
		,"{\n");

    $fl->printf ("    // Shorten the register info lines\n");
    $fl->printf ("#   define RFRDSIDE  VregsRegEntry::REGFL_RDSIDE\n");
    $fl->printf ("#   define RFWRSIDE  VregsRegEntry::REGFL_WRSIDE\n");
    $fl->printf ("#   define RFNORTEST VregsRegEntry::REGFL_NOREGTEST\n");
    $fl->printf ("#   define RFNORDUMP VregsRegEntry::REGFL_NOREGDUMP\n");
    $fl->printf ("    //rip->add_register( address,       size,   name,     spacing, rangeLow, rangeHi,\n");
    $fl->printf ("    //  rdMask,     wrMask,     rstVal,     rstMask,    flags);\n");

    foreach my $regref ($self->regs_sorted()) {
	my $size = $self->addr_const_vec($regref->{typeref}{words}*4);
	my $noarray =  attribute_value($self,$regref->{typeref},'noarray');
	my $noregtest = attribute_value($self,$regref->{typeref}, 'noregtest');
	my $noregdump = attribute_value($self,$regref->{typeref}, 'noregdump');
	if ($noarray) {
	    # User wants to treat it as a bulk region without [] subscripts in info
	    # This munging should probably be done in Register instead.
	    $size->subtract ($regref->{addr_end}, $regref->{addr}, 0);
	}
	$fl->printf ("    rip->add_register (%s, %s, \"%s\"",
		     $fl->sprint_hex_value_add0 ($regref->{addr}, $self->{address_bits}),
		     $fl->sprint_hex_value_drop0 ($size, $self->{address_bits}),
		     $regref->{name});
	if ($regref->{range} && ! $noarray) {
	    $fl->printf (", %s, %s, %s,\n",
			 $fl->sprint_hex_value_drop0 ($regref->{spacing},32),
			 $fl->sprint_hex_value_drop0 ($regref->{range_low},32),
			 $fl->sprint_hex_value_drop0 ($regref->{range_high_p1},32));
	} else {
	    $fl->print (",\n");
	}

	my $rd_mask = 0;
	my $wr_mask = 0;
	my $rd_side = 0;
	my $wr_side = 0;
	my $rst_val = 0;
	my $rst_mask = 0;
	my $typeref = $regref->{typeref};
	for (my $bit=0; $bit<$self->{data_bits}; $bit++) {
	    my $bitent = $typeref->{bitarray}[$bit];
	    next if !$bitent;
	    $rd_mask  |= (1<<$bit) if ($bitent->{read});
	    $wr_mask  |= (1<<$bit) if ($bitent->{write});
	    $rd_side   =  1 if ($bitent->{read_side});
	    $wr_side   =  1 if ($bitent->{write_side});
	    if (defined $bitent->{rstvec}) {
		$rst_mask |= (1<<$bit);
		$rst_val  |= (1<<$bit) if ($bitent->{rstvec});
	    }
	}
	$fl->printf ("\t0x%08lx, 0x%08lx, 0x%08lx, 0x%08lx, 0",
		     $rd_mask, $wr_mask, $rst_val, $rst_mask);
	$fl->printf ("|RFRDSIDE") if $rd_side;
	$fl->printf ("|RFWRSIDE") if $wr_side;
	$fl->printf ("|RFNORTEST") if $noregtest;
	$fl->printf ("|RFNORDUMP") if $noregdump;
	$fl->printf (");\n",);
    }

    $fl->printf ("#   undef RFRDSIDE\n");
    $fl->printf ("#   undef RFWRSIDE\n");
    $fl->printf ("#   undef RFNORTEST\n");
    $fl->printf ("#   undef RFNORDUMP\n");
    $fl->print ("};\n\n");

    $self->{rules}->execute_rule ('info_cpp_file_after', 'file_body', $self);

    $fl->close();
}

######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::Outputs - Outputting Vregs Code

=head1 SYNOPSIS

    use SystemC::Vregs;

=head1 DESCRIPTION

This package contains additional SystemC::Vregs methods.  These methods
are used to output various types of files.

=head1 METHODS

=over 4

=item class_h_write

Creates a C++ header file with class definitions.

=item defs_write

Creates a C++, Verilog, or Perl header file with defines.  The language
parameter is used along with SystemC::Vregs::Language to produce the
definitions in a language appropriate way.

=item param_write

Creates a Verilog header file with parameters in place of defines.

=item info_h_write

Creates a header file for use with c_info_write.

=item info_cpp_write

Creates a C++ file with information on each register.  The information is
then added to a map which may be used during runtime to decode register
addresses into names.

=back

=head1 DISTRIBUTION

The latest version is available from CPAN and from L<http://www.veripool.com/>.

Copyright 2001-2005 by Wilson Snyder.  This package is free software; you
can redistribute it and/or modify it under the terms of either the GNU
Lesser General Public License or the Perl Artistic License.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=head1 SEE ALSO

L<SystemC::Vregs>

=cut

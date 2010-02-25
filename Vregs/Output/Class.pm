# See copyright, etc in below POD section.
######################################################################

package SystemC::Vregs::Output::Class;
use SystemC::Vregs::File;
use SystemC::Vregs::Number;
use SystemC::Vregs::Language;
use Carp;
use strict;
use vars qw($VERSION);

$VERSION = '1.464';

######################################################################
# CONSTRUCTOR

sub new {
    my $class = shift;
    my $self = {@_};
    bless $self, $class;
    return $self;
}

######################################################################
######################################################################
######################################################################
######################################################################

sub enum_write {
    my $self = shift;
    my $typeref = shift;
    my $pack = shift;
    my $fl = shift;

    my $clname = $typeref->{name} || "x";
    $pack->{rules}->execute_rule ('enum_begin_before', $clname, $typeref);
    $fl->print ("class $clname {\n");
    $fl->print ("public:\n");
    $pack->{rules}->execute_rule ('enum_begin_after', $clname, $typeref);

    $fl->print ("    enum en {\n");
    $self->_enum_write_center($typeref,$pack,$fl);
    $fl->print ("    };\n");
    $pack->{rules}->execute_rule ('enum_end_before', $clname, $typeref);
    $fl->print ("  };\n");
    $pack->{rules}->execute_rule ('enum_end_after', $clname, $typeref);
    $fl->print ("\n");
}

sub enum_struct_write {
    my $self = shift;
    my $typeref = shift;
    my $pack = shift;
    my $fl = shift;

    my $clname = $typeref->{typedef_name} || $typeref->{name} || "x";
    $fl->print ("typedef enum {\n");
    $self->_enum_write_center($typeref,$pack,$fl);
    $fl->print ("} $clname;\n");
    $fl->print ("\n");
}

sub _enum_write_center {
    my $self = shift;
    my $typeref = shift;
    my $pack = shift;
    my $fl = shift;

    my $c = $fl->{C};   # Not C++
    my $cClname = $c ? ($typeref->{typedef_name} || $typeref->{name})."_":"";

    my $width = 13;
    foreach my $fieldref ($typeref->fields_sorted()) {
	$width = length($fieldref->{name}) if length($fieldref->{name})>$width;
    }
    foreach my $fieldref ($typeref->fields_sorted()) {
	$fl->printf ("\t${cClname}%-${width}s = 0x%x,"
		     ,$fieldref->{name},$fieldref->{rst_val});
	if ($pack->{comments}) {
	    $fl->printf ("\t");
	    $fl->comment_post ($fieldref->{desc});
	}
	$fl->printf ("\n");
    }
    # Perhaps this should just be added to the data structures?
    # note no comma to make C happy
    if ($typeref->{bits}==32) {
	# Can't put out 1_0000_0000 or C won't fit it into a enum
	# We'll be weedy and subtract one.  We'll check no value of the users would collide
	# with our little lie.
	$fl->printf("\t${cClname}%-${width}s = 0x%x\t","MAX", ((1<<$typeref->{bits})-1));
	$fl->comment_post ("MAXIMUM (-1 adjusted so will fit in 32-bits)");
	foreach my $fieldref ($typeref->fields_sorted()) {
	    if ($fieldref->{rst_val} >= ((1<<$typeref->{bits})-1)) {
		$fieldref->warn ("0xffffffff isn't representable in 32-bit enum, as MAX won't fit.\n");
	    }
	}
    } else {
	$fl->printf("\t${cClname}%-${width}s = 0x%x\t","MAX", (1<<$typeref->{bits}));
	$fl->comment_post ("MAXIMUM+1");
    }
    $fl->print ("\n");
}

sub enum_cpp_write {
    my $self = shift;
    my $typeref = shift;
    my $pack = shift;
    my $fl = shift;

    my $clname = $typeref->{name} || "x";

    $fl->print("//${clname}\n",);
    $pack->{rules}->execute_rule ('enum_cpp_before', $clname, $typeref);

    for my $desc (0..1) {
	next if $desc && !$typeref->attribute_value('descfunc');

	$fl->printf ("const char* ${clname}::%s () const {\n",
		     ($desc ? 'description':'ascii'));
	$fl->print ("    switch (m_e) {\n");
	my %did_values;
	foreach my $fieldref ($typeref->fields_sorted()) {
	    next if $desc && $fieldref->{omit_description};
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
	$fl->print ("\tdefault: return (\"?E\");\n");
	$fl->print ("    }\n");
	$fl->print ("}\n\n");
    }

    {
	$fl->printf ("${clname}::iterator ${clname}::iterator::operator++() {\n");
	$fl->print ("    switch (m_e) {\n");
	my %next_values;
	my $last;
	foreach my $fieldref ($typeref->fields_sorted()) {
	    if (!defined $last || $fieldref->{rst_val} ne $last->{rst_val}) {
		if ($last) {
		    if ($fieldref->{rst_val} == $last->{rst_val}+1) {
			$next_values{inc}{$last->{name}} = "${clname}(m_e + 1)";
		    } else {
			$next_values{expr}{$last->{name}} = $fieldref->{name};
		    }
		}
		$last = $fieldref;
	    }
	}
	# Note final value isn't in next_values; the default will catch it.
	foreach my $inc ("inc", "expr") {
	    my @fields = (sort keys %{$next_values{$inc}});
	    for (my $i=0; $i<=$#fields; ++$i) {
		my $field = $fields[$i];
		my $next_field = $fields[$i+1];
		$fl->printf ("\tcase %s:",$field);
		if ($next_field && $next_values{$inc}{$field} eq $next_values{$inc}{$next_field}) {
		    $fl->printf (" /*FALLTHRU*/\n");
		} else {
		    $fl->printf (" m_e=%s; return *this;\n"
				 ,$next_values{$inc}{$field});
		}
	    }
	}
	$fl->print ("\tdefault: m_e=MAX; return *this;\n");
	$fl->print ("    }\n");
	$fl->print ("}\n\n");
    }

    $pack->{rules}->execute_rule ('enum_cpp_after', $clname, $typeref);
}

######################################################################
######################################################################
######################################################################
#### Saving

sub _class_h_write_dw {
    my $self = shift;
    my $typeref = shift;
    my $pack = shift;
    my $fl = shift;

    my $wget = $fl->call_str($typeref->{name},"","w(");
    my $wset = $fl->call_str($typeref->{name},"set","w(");

    if (($typeref->{words}||0) > 1) {
	# make full dw accessors if the type is >32 bits
	$fl->fn($typeref->{name},"","inline uint64_t dw(int b) const",
		,"{\n"
		."\tunion {uint64_t udw; uint32_t lw[2];} u;\n"
		."\tu.lw[0]=${wget}b*2+0); u.lw[1]=${wget}b*2+1); return u.udw; }\n");
	$fl->fn($typeref->{name},"set","inline void dw(int b, uint64_t val)"
		,"{\n"
		."\tunion {uint64_t udw; uint32_t lw[2];} u;\n"
		."\tu.udw=val; ${wset}b*2+0,u.lw[0]); ${wset}b*2+1,u.lw[1]); }\n");
    } else {
	# still make dw accessors, but don't read or write w[1] because
	# it doesn't exist.
	$fl->fn($typeref->{name},"","inline uint64_t dw(int b) const"
		,"{\n"
		."\tunion {uint64_t udw; uint32_t lw[2];} u;\n"
		."\tu.lw[0]=${wget}b*2+0); u.lw[1]=0; return u.udw; }\n");
	$fl->fn($typeref->{name},"set","inline void dw(int b, uint64_t val)"
		,"{\n"
		."\tunion {uint64_t udw; uint32_t lw[2];} u;\n"
		."\tu.udw=val; ${wset}b*2+0,u.lw[0]); }\n");
    }
}


sub _class_h_write {
    my $self = shift;
    my $typeref = shift;
    my $pack = shift;
    my $fl = shift;
    my $clname = $typeref->{name} || "x";

    my $c = $fl->{C};   # Not C++
    my $cClname = $c ? "${clname}_":"";
    my $cThis = $c ? "thisp->":"";
    my $cForInt = $c ? "int i; for (" : "for (int ";
    my $wget = $fl->call_str($clname,"","w(");
    my $wset = $fl->call_str($clname,"set","w(");

    my $netorder = $typeref->attribute_value('netorder') || 0;
    my $stretchable = $typeref->attribute_value('stretchable') || 0;
    my $ntohl = ($netorder ? "ntohl" : "");
    my $htonl = ($netorder ? "htonl" : "");
    my $uint   = ($netorder ? "nint32_t" : "uint32_t");
    my $uint64 = ($netorder ? "nint64_t" : "uint64_t");
    my $uchar = ($netorder ? "nint8_t" : "uint8_t");
    my $toBytePtr = ($netorder ? "castNBytep" : "castHBytep");

    my $inh = "";
    $inh = " : $typeref->{inherits}" if $typeref->{inherits};
    $inh = "" if $c;
    my $words = $typeref->{words};

    if ($c) {
	$fl->print("typedef struct {\n");
	$fl->print("    ${uint} m_w[${words}];"
		   .($stretchable ? "  // Attr '-stretchable'\n" : "\n")
		   ."} $clname;\n");
    } else {
	$pack->{rules}->execute_rule ('class_begin_before', $clname, $typeref);
	$fl->print("struct $clname$inh {\n");
	$fl->set_private(0);	# struct implies public:
	$pack->{rules}->execute_rule ('class_begin_after', $clname, $typeref);
    }
    $fl->set_private(0);	# struct implies public:

    if ($inh ne "") {
	my $inhType = $typeref->{inherits_typeref} or
	    die "%Error: Missing typeref for inherits${inh}.\n";
	# Verify same byte ordering.
	my $inh_netorder = $inhType->attribute_value('netorder') || 0;
	if ($inh_netorder ne $netorder) {
	    die ("%Error: $clname netorder=$netorder doesn't match $inh_netorder"
		 ." inherited from $inhType->{name}.\n");
	}
	$fl->print("    // w() and $toBytePtr() inherited from $typeref->{inherits}::\n");
	# Correct for any size difference
	(defined $inhType->{words}) or die "%Error: Missed words compute()\n";
	if (($typeref->{words}||0) > $inhType->{words}) {
	    # Ensure the parent type disabled array bounds checking.
	    my $inh_stretchable = $inhType->attribute_value('stretchable') || 0;
	    if (! $inh_stretchable) {
		die sprintf("%%Error: Base class %s (%d words) needs '-stretchable'"
			    ." since %s has %d words.\n",
			    $inhType->{name}, $inhType->{words},
			    $clname, $typeref->{words});
	    }
	    $fl->printf("  protected: uint32_t m_wStretch[%d];   // Bring base size up\n"
			."  public:\n",
			$typeref->{words} - $typeref->{inherits_typeref}->{words});
	}
    } else {
	if (!$c) {
	    $fl->print("  protected: ${uint} m_w[${words}];"
		       .($stretchable ? "  // Attr '-stretchable'\n" : "\n")
		       ."  public:\n");
	}
	$fl->fn($clname, "", "inline uint32_t w(int b) const"
		,"{ return (${ntohl}(${cThis}m_w[b])); }\n");
	$fl->fn($clname, "set", "inline void w(int b, uint32_t val)"
		,"{");
	if (! $stretchable) {
	    $fl->print(" VREGS_WORDIDX_CHK($clname, $words, b)\n"
		       ."\t\t\t\t\t");
	}
	$fl->print(" ${cThis}m_w[b] = ${htonl}(val); }\n");
	_class_h_write_dw($self,$typeref,$pack,$fl);

	if (!$c) {
	    $fl->fn($clname, "", "inline ${uchar}* ${toBytePtr}()"
		    ,"{\n"
		    ,"\treturn reinterpret_cast<${uchar}*>(&m_w[0]); }\n");
	    $fl->fn($clname, "", "inline const ${uchar}* ${toBytePtr}() const"
		    ,"{\n"
		    ,"\treturn reinterpret_cast<const ${uchar}*>(&m_w[0]); }\n");
	}
    }
    if ($clname =~ /^R_/) {
	# Write only those bits that are marked access writable
	my @wr_masks;
	for (my $word=0; $word<$typeref->{words}; $word++) {
	    $wr_masks[$word] = 0;
	    for (my $bit=$word*$typeref->{pack}->{word_bits};
		 $bit<(($word+1)*$typeref->{pack}->{word_bits});
		 $bit++) {
		my $bitent = $typeref->{bitarray}[$bit];
		next if !$bitent;
		$wr_masks[$word] |= (1<<($bit & ($typeref->{pack}->{word_bits}-1)))
		    if ($bitent->{write});
	    }
	}
	if ($typeref->{words}>0 && $typeref->{words}<2 && !$c) {
	    $fl->printf("    static const uint32_t BITMASK_WRITABLE = 0x%08x;\n", $wr_masks[0]);
	    $fl->fn($clname, "", "inline void wWritable(int b, uint32_t val)"
		    ,"{ ${wset}b,(val&BITMASK_WRITABLE)|(${wget}b)&~BITMASK_WRITABLE)); }\n");
	} else {
	    # Grrr, Greenhills Compilers don't allow
	    # static const uint32_t BITMASK_WRITABLE[] = {...};
	    $fl->fn($clname,"","inline uint32_t wBitMaskWritable(int b)"
		    ,"{\n");
	    for (my $word=0; $word<$typeref->{words}; $word++) {
		$fl->printf("\tif (b==$word) return 0x%08x;\n", $wr_masks[$word]);
	    }
	    $fl->printf("\treturn 0; }\n");
	    my $fwritable = $fl->call_str($clname,"","wBitMaskWritable(b)");
	    $fl->fn($clname,"","inline void wWritable(int b, uint32_t val)"
		    ,"{ ${wset}b,(val&${fwritable})|(${wget}b)&~${fwritable})); }\n");
	}
    }

    my @resets=();
    if ($typeref->{inherits}) {
	if ($c) {
	    my $call = $fl->call_str($typeref->{inherits},"","fieldsReset();\n");
	    $call =~ s/\(/(($typeref->{inherits}*)/;  # Need a cast
	    push @resets, "\t".$call;
	} else {
	    push @resets, "\t".$typeref->{inherits}."::fieldsReset();\n";
	}
    }
    my @dumps = ();
    $fl->printf("\n");

    my @fields = $c ? ($typeref->fields_sorted_inherited()) : ($typeref->fields_sorted());

    foreach my $bitref (@fields) {
	next if $bitref->ignore;
	(my $lc_mnem = $bitref->{name}) =~ s/^(.)/lc $1/xe;

	my $typecast = "";
	$typecast = $bitref->{type} if $bitref->{cast_needed};
	$typecast = "($typecast)" if $c && $typecast ne "";
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
		$extract .= " ${wget}${word})";
		$deposit .= " ${wset}${word}, (uint32_t)(b));";
	    } else {
		my $tobit = "<<$srcbit)";
		$tobit = "" if $srcbit==0;
		my $frombit = ">>$srcbit)";
		$frombit = "" if $srcbit==0;
		$extract .= sprintf " %s(${wget}${word})>>${low_mod} & 0x%x$L)$tobit"
		    , ($tobit?"(":""), $deposit_mask;
		my $b = "b";
		$b = "(".$b.$frombit if $frombit;
		$b = "((uint32_t)($b))" if $bitref->{type} ne 'uint32_t';
		$deposit .= sprintf " ${wset}${word}, (${wget}${word})&0x%08x$L)"
		    ." | ((%s&0x%x$L)<<${low_mod}));"
		    , (~$mask&0xffffffff),
		    , $b
		    , $deposit_mask;
	    }
	}

	# Mask after shifting on reads, so the mask is a smaller constant.
	$fl->private_not_public (!$bitref->{access_read}, $pack);
	my $typEnd = 11 + length $bitref->{type};
	$fl->fn($clname,"",sprintf("inline %s%s%-13s () const",
				   $bitref->{type}, ($typEnd < 16 ? "\t\t" : $typEnd < 24 ? "\t" : " "),
				   $lc_mnem)
		,"{ return ${typecast}(${extract} ); }\n");
	if ($typeref->attribute_value('public_rdwr_accessors') && $fl->{private} && $fl->{CPP}) {
	    $fl->private_not_public(0);
	    $fl->fn($clname,"",sprintf("inline %s%s%-13s () const",
				       $bitref->{type}, ($typEnd < 16 ? "\t\t" : $typEnd < 24 ? "\t" : " "),
				       $lc_mnem."_private")
		    ,"{ return $lc_mnem(); }\n");
	}

	$fl->private_not_public (!$bitref->{access_write}, $pack);
	$fl->fn($clname,"set",sprintf("inline void\t\t%-13s (%s b)", $lc_mnem, $bitref->{type})
		,"{${deposit} }\n");
	if ($typeref->attribute_value('public_rdwr_accessors') && $fl->{private} && $fl->{CPP}) {
	    $fl->private_not_public(0);
	    $fl->fn($clname,"set",sprintf("inline void\t\t%-13s (%s b)", $lc_mnem."_private", $bitref->{type})
		    ,"{ ${lc_mnem}(b); }\n");
	}

	push @dumps, "\"$bitref->{name}=\"<<$lc_mnem()";

	if ($bitref->{rst} ne 'X') {
	    my $rst = $bitref->{rst};
	    $rst = 0 if ($rst =~ /^FW-?0$/);
	    if ($rst =~ /^[a-z]/i && $bitref->{type}) {	# Probably a enum value
		if ($c) {
		    $rst = "$bitref->{type}_$rst";
		} else {
		    $rst = "$bitref->{type}::$rst";
		}
	    } elsif ($rst =~ /^0x([0-9a-f_]+)$/i) {  # May need ULLs added
		$rst = $fl->sprint_hex_value($1,$bitref->{numbits});
	    }
	    #$fl->printf("\tstatic const %s %s = %s;\n", $bitref->{type},
	    #		uc($lc_mnem)."_RST", $rst);
	    push @resets, $fl->call_str($clname,"set",sprintf("\t%s(%s);\n", $lc_mnem, $rst));
	}
    }

    $fl->printf("\n");
    $fl->private_not_public (0, $pack);
    if (!$c) {
	$fl->printf("    VREGS_STRUCT_DEF_CTOR(%s, %s)\t// (typeName, numWords)\n",
		    $clname, $words);
    }

    $fl->fn($clname,"","inline void fieldsZero()"
	    ,"{\n");
    if ($words>=8) {
	$fl->print("\t${cForInt}i=0; i<${words}; i++) ${wset}i,0);\n");
    } else {
	$fl->print("\t");
	for (my $i=0; $i<$words; $i++) {
	    $fl->print(" ") if $i!=0;
	    $fl->print("${wset}$i,0);");
	}
	$fl->print("\n");
    }
    $fl->print("    }\n");

    $fl->fn($clname,"","inline void fieldsReset()"
	    ,"{\n"
	    ,"\t",$fl->call_str($clname,"","fieldsZero();\n")
	    ,@resets
	    ,"    }\n");

    if (!$c) {
	$fl->fn($clname,"","inline bool operator== (const ${clname}& rhs) const"
		,"{\n"
		,"\t${cForInt}i=0; i<${words}; i++) { if (m_w[i]!=rhs.m_w[i]) return false; }\n"
		,"\treturn true;\n"
		,"    }\n");
	# The dump functions are in a .cpp file (no inline), as there was too much code
	# bloat, and it was taking a lot of compile time.
	$fl->print("    typedef VregsOstream<${clname}> DumpOstream;\n",
		   "    DumpOstream dump(const char* prefix=\"\\n\\t\") const;\n",
		   "    OStream& _dump(OStream& lhs, const char* pf) const;\n",
		   "    void dumpCout() const; // For GDB\n",);

	# Put const's last to avoid GDB stupidity
	$fl->private_not_public (0, $pack);
	$fl->printf("    static const size_t SIZE = %d;\n", $words*4);

	$pack->{rules}->execute_rule ('class_end_before', $clname, $typeref);
	$fl->print("};\n");
	$pack->{rules}->execute_rule ('class_end_after', $clname, $typeref);

	$fl->print("  OStream& operator<< (OStream& lhs, const ${clname}::DumpOstream rhs);\n",);
    }

    $fl->print("\n");
}

######################################################################
######################################################################
######################################################################

sub _class_cpp_write {
    my $self = shift;
    my $typeref = shift;
    my $pack = shift;
    my $fl = shift;
    my $clname = $typeref->{name} || "x";

    my @dumps = ();

    my $fields_lcFirst = $typeref->attribute_value('lcfirst') || 0;
    foreach my $bitref ($typeref->fields_sorted()) {
	next if $bitref->ignore;
	(my $lc_mnem = $bitref->{name}) =~ s/^(.)/lc $1/xe;
	if ($typeref->{inherits_typeref}
	    && $typeref->{inherits_typeref}->find_bit($bitref->{name})) {
	    # It's printed by the base class.
	} elsif ($fields_lcFirst) {
	    push @dumps, "\"$lc_mnem=\"<<$lc_mnem()";
	} else {
	    push @dumps, "\"$bitref->{name}=\"<<$lc_mnem()";
	}
    }

    $fl->print("//${clname}\n",);
    $pack->{rules}->execute_rule ('class_cpp_before', $clname, $typeref);
    my $dumpName = $SystemC::Vregs::Dump_Routine_Name || "_dump";
    $fl->print("${clname}::DumpOstream ${clname}::dump(const char* prefix) const {\n",
	       "    return DumpOstream(this,prefix);\n",
	       "}\n");
    $fl->print("OStream& operator<< (OStream& lhs, const ${clname}::DumpOstream rhs) {\n",
	       "    return ((${clname}*)rhs.obj())->${dumpName}(lhs,rhs.prefix());\n",
	       "}\n");

    $SystemC::Vregs::Do_Dump = 0;
    $pack->{rules}->execute_rule ('class_dump_before', $clname, $typeref);
    if ($SystemC::Vregs::Do_Dump) {
	$fl->printf("OStream& ${clname}::_dump (OStream& lhs, const char*%s) const {\n",
		    ((($#dumps>0) || $typeref->{inherits}) ? ' pf':''));
	$pack->{rules}->execute_rule ('class_dump_after', $clname, $typeref, \@dumps);
	$fl->print("    return lhs;\n"
		   ."}\n");
    }

    # For usage in GDB
    $fl->print("void ${clname}::dumpCout () const { COUT<<this->dump(\"\\n\\t\")<<endl; }\n",);
    $pack->{rules}->execute_rule ('class_cpp_after', $clname, $typeref);

    $fl->print("\n");
}

######################################################################
######################################################################
######################################################################

sub write_class_h {
    # Dump type definitions
    my $self = shift;
    my %params = (pack => $self->{pack},
		  @_);
    my $pack = $params{pack} or croak "%Error: No pack=> parameter passed,";

    my $fl = SystemC::Vregs::File->open(rules => $pack->{rules},
					language=>'CPP', @_);

    $fl->include_guard();
    $fl->print("\n");
    $fl->comment("package $pack->{name}\n");
    $fl->print("\n");

    $pack->{rules}->execute_rule ('file_body_before', 'file_body', $pack);

    $fl->print("// Vregs library Files:\n");
    foreach my $packref (@{$pack->{libraries}}) {
	$fl->print("#include \"$packref->{name}_class.h\"\n");
    }

    $fl->print("\n\n");

    foreach my $typeref ($pack->enums_sorted) {
	enum_write ($self, $typeref, $pack, $fl);
    }

    $fl->print("\n\n");
    # Bitbashing done verbosely to avoid slow preprocess time
    # We could use bit structures, but they don't work on non-contiguous fields

    # Sorted first does base classes, then children
    foreach my $typeref ($pack->types_sorted) {
	next if $typeref->attribute_value('nofielddefines');
	_class_h_write($self,$typeref,$pack, $fl);
    }

    $pack->{rules}->execute_rule ('file_body_after', 'file_body', $pack);

    $fl->close();
}

sub write_struct_h {
    # Dump type definitions
    my $self = shift;
    my %params = (pack => $self->{pack},
		  @_);
    my $pack = $params{pack} or croak "%Error: No pack=> parameter passed,";

    my $fl = SystemC::Vregs::File->open(rules => $pack->{rules},
					language=>'C', @_);

    $fl->include_guard();
    $fl->print("\n");
    $fl->comment("package $pack->{name}\n");
    $fl->print("\n");

    $pack->{rules}->execute_rule ('file_body_before', 'file_body', $pack);

    $fl->print("// Vregs library Files:\n");
    foreach my $packref (@{$pack->{libraries}}) {
	$fl->print("#include \"$packref->{name}_struct.h\"\n");
    }

    $fl->print("\n\n");

    foreach my $typeref ($pack->enums_sorted) {
	enum_struct_write ($self, $typeref, $pack, $fl);
    }

    $fl->print("\n\n");
    # Bitbashing done verbosely to avoid slow preprocess time
    # We could use bit structures, but they don't work on non-contiguous fields

    # Sorted first does base classes, then children
    foreach my $typeref ($pack->types_sorted) {
	next if $typeref->attribute_value('nofielddefines');
	_class_h_write($self,$typeref,$pack, $fl);
    }

    $pack->{rules}->execute_rule ('file_body_after', 'file_body', $pack);

    $fl->close();
}

sub write_class_cpp {
    my $self = shift;
    my %params = (pack => $self->{pack},
		  @_);
    my $pack = $params{pack} or croak "%Error: No pack=> parameter passed,";
    # Dump type definitions

    my $fl = SystemC::Vregs::File->open(rules => $pack->{rules},
					language=>'CPP', @_);

    $fl->print("\n");
    $fl->print("#include \"$pack->{name}_class.h\"\n");
    $fl->print("\n");

    $pack->{rules}->execute_rule ('class_cpp_file_before', 'file_body', $pack);

    foreach my $typeref ($pack->enums_sorted) {
	$self->enum_cpp_write ($typeref, $pack, $fl);
    }

    # Sorted first does base classes, then children
    foreach my $typeref ($pack->types_sorted) {
	next if $typeref->attribute_value('nofielddefines');
	$self->_class_cpp_write($typeref,$pack, $fl);
    }

    $fl->close();
}

######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::Output::Class - Outputting Vregs Code

=head1 SYNOPSIS

SystemC::Vregs::Output::Class->new->write_class_h(pack=>$VregsPackageObject, filename=>$fn);

=head1 DESCRIPTION

This package contains additional SystemC::Vregs methods.  These methods are
used to output various types of files.

=head1 METHODS

=over 4

=item write_class_h

Creates a C++ header file with class definitions.

=item write_class_cpp

Creates a C++ implementation file to correspond with write_class_h.

=item write_struct_h

Creates a C header file with structs for class definitions.

=back

=head1 DISTRIBUTION

Vregs is part of the L<http://www.veripool.org/> free Verilog software tool
suite.  The latest version is available from CPAN and from
L<http://www.veripool.org/vregs>.  /www.veripool.org/>.

Copyright 2001-2010 by Wilson Snyder.  This package is free software; you
can redistribute it and/or modify it under the terms of either the GNU
Lesser General Public License Version 3 or the Perl Artistic License Version 2.0.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=head1 SEE ALSO

L<vreg>,
L<SystemC::Vregs>

=cut

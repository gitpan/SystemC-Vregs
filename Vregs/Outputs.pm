# $Id: Outputs.pm 6461 2005-09-20 18:28:58Z wsnyder $
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
$VERSION = '1.310';

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
	$self->print("// -*- C++ -*-\n") if ($self->{CPP});
	$self->print("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n") if ($self->{XML});
	$self->comment("DO NOT EDIT -- Generated automatically by vregs\n");
	if ($self->{C} || $self->{CPP}) {
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
    # Print public: or private: depending on desired state

    my $enabled = (defined $pack->{rules}{protect_rdwr_only}
		   ? $pack->{rules}{protect_rdwr_only}
		   : $pack->{protect_rdwr_only});
    $private = 0 if !$enabled;
    if ($self->{CPP}) {
	if ($private && !$self->{private}) {
	    $self->print ("protected:\n");
	}
	if (!$private && $self->{private}) {
	    $self->print ("public:\n");
	}
    }
    $self->set_private($private);
}

sub set_private {
    my $self = shift;
    my $private = shift;
    $self->{private} = $private;
}

sub fn {
    my $self = shift;
    my $clname = shift;
    my $suffix = shift;
    my $proto = shift;
    # Declare a function with C++ semantics, mangle into C if necessary
    if ($self->{CPP}) {
	$self->print ("    $proto ",@_);
    } else {
	$suffix = "_".$suffix if $suffix;
	my $const = ($proto =~ s/const\s*$//) ? "const ":"";

	$proto =~ m/\s+(\S+)\s*\(/;
	my $fname = "${clname}_$1${suffix}";						 
	if ($self->{private}) {
	    $self->{func_private}{$fname} = $self->{private};
	    $fname .= "_private";
	}
	$proto =~ s/\s+(\S+)\s*\(/ ${fname}(/;

        $proto =~ s/\(/(${const}${clname}* thisp,/;
        $proto =~ s/,\s*\)/)/;
	$self->print ("$proto ",@_);
    }
}

sub call_str {
    my $self = shift;
    my $clname = shift;
    my $suffix = shift;
    my $func = shift;
    # Call a function with C++ semantics, mangle into C if necessary
    # return as *string*
    if ($self->{CPP}) {
	return join('',"$func",@_);
    } else {
	$suffix = "_".$suffix if $suffix;
	$func =~ s/(\S+)\s*\(/${clname}_$1${suffix}(/;
        $func =~ s/\(/(thisp,/ or croak "%Error: No args in func call '$func',";
        $func =~ s/,\s*\)/)/;
	return join('',$func,@_);
    }
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
    $self->_enum_write_center($pack,$fl);
    $fl->print ("    };\n");
    $pack->{rules}->execute_rule ('enum_end_before', $clname, $self);
    $fl->print ("  };\n");
    $pack->{rules}->execute_rule ('enum_end_after', $clname, $self);
    $fl->print ("\n");
}

sub SystemC::Vregs::Enum::enum_struct_write {
    my $self = shift;
    my $pack = shift;
    my $fl = shift;

    my $clname = $self->{name} || "x";
    $fl->print ("typedef enum {\n");
    $self->_enum_write_center($pack,$fl);
    $fl->print ("} $clname;\n");
    $fl->print ("\n");
}

sub SystemC::Vregs::Enum::_enum_write_center {
    my $self = shift;
    my $pack = shift;
    my $fl = shift;

    my $c = $fl->{C};   # Not C++
    my $cClname = $c ? $self->{name}."_":"";

    foreach my $fieldref ($self->fields_sorted()) {
	$fl->printf ("\t${cClname}%-13s = 0x%x,"
		     ,$fieldref->{name},$fieldref->{rst_val});
	if ($pack->{comments}) {
	    $fl->printf ("\t");
	    $fl->comment_post ($fieldref->{desc});
	}
	$fl->printf ("\n");
    }
    # Perhaps this should just be added to the data structures?
    # note no comma to make C happy
    $fl->printf("\t${cClname}%-13s = 0x%x\t","MAX", (1<<$self->{bits}));
    $fl->comment_post ("MAXIMUM+1");
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
	next if $desc && !$self->attribute_value('descfunc');

	$fl->printf ("const char* ${clname}::%s () const {\n",
		     ($desc ? 'description':'ascii'));
	$fl->print ("    switch (m_e) {\n");
	my %did_values;
	foreach my $fieldref ($self->fields_sorted()) {
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
	my %did_values;
	my %next_values;
	my $last;
	foreach my $fieldref ($self->fields_sorted()) {
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

    $pack->{rules}->execute_rule ('enum_cpp_after', $clname, $self);
}

######################################################################
######################################################################
######################################################################
#### Saving

sub SystemC::Vregs::Type::_class_h_write_dw {
    my $self = shift;
    my $pack = shift;
    my $fl = shift;

    my $wget = $fl->call_str($self->{name},"","w(");
    my $wset = $fl->call_str($self->{name},"set","w(");

    if (($self->{words}||0) > 1) {
	# make full dw accessors if the type is >32 bits
	$fl->fn($self->{name},"","inline uint64_t dw(int b) const",
		,"{\n"
		."\tunion {uint64_t udw; uint32_t lw[2];} u;\n"
		."\tu.lw[0]=${wget}b*2+0); u.lw[1]=${wget}b*2+1); return u.udw; }\n");
	$fl->fn($self->{name},"set","inline void dw(int b, uint64_t val)"
		,"{\n"
		."\tunion {uint64_t udw; uint32_t lw[2];} u;\n"
		."\tu.udw=val; ${wset}b*2+0,u.lw[0]); ${wset}b*2+1,u.lw[1]); }\n");
    } else {
	# still make dw accessors, but don't read or write w[1] because
	# it doesn't exist.
	$fl->fn($self->{name},"","inline uint64_t dw(int b) const"
		,"{\n"
		."\tunion {uint64_t udw; uint32_t lw[2];} u;\n"
		."\tu.lw[0]=${wget}b*2+0); u.lw[1]=0; return u.udw; }\n");
	$fl->fn($self->{name},"set","inline void dw(int b, uint64_t val)"
		,"{\n"
		."\tunion {uint64_t udw; uint32_t lw[2];} u;\n"
		."\tu.udw=val; ${wset}b*2+0,u.lw[0]); }\n");
    }
}


sub SystemC::Vregs::Type::_class_h_write {
    my $self = shift;
    my $pack = shift;
    my $fl = shift;
    my $clname = $self->{name} || "x";

    my $c = $fl->{C};   # Not C++
    my $cClname = $c ? "${clname}_":"";
    my $cThis = $c ? "thisp->":"";
    my $cForInt = $c ? "int i; for (" : "for (int ";
    my $wget = $fl->call_str($clname,"","w(");
    my $wset = $fl->call_str($clname,"set","w(");

    my $netorder = $self->attribute_value('netorder') || 0;
    my $stretchable = $self->attribute_value('stretchable') || 0;
    my $ntohl = ($netorder ? "ntohl" : "");
    my $htonl = ($netorder ? "htonl" : "");
    my $uint   = ($netorder ? "nint32_t" : "uint32_t");
    my $uint64 = ($netorder ? "nint64_t" : "uint64_t");
    my $uchar = ($netorder ? "nint8_t" : "uint8_t");
    my $toBytePtr = ($netorder ? "castNBytep" : "castHBytep");

    my $inh = "";
    $inh = " : $self->{inherits}" if $self->{inherits};
    $inh = "" if $c;
    my $words = $self->{words};

    if ($c) {
	$fl->print("typedef struct {\n");
	$fl->print("    ${uint} m_w[${words}];"
		   .($stretchable ? "  // Attr '-stretchable'\n" : "\n")
		   ."} $clname;\n");
    } else {
	$pack->{rules}->execute_rule ('class_begin_before', $clname, $self);
	$fl->print("struct $clname$inh {\n");
	$fl->set_private(0);	# struct implies public:
	$pack->{rules}->execute_rule ('class_begin_after', $clname, $self);
    }
    $fl->set_private(0);	# struct implies public:

    if ($inh ne "") {
	my $inhType = $self->{inherits_typeref} or
	    die "%Error: Missing typeref for inherits${inh}.\n";
	# Verify same byte ordering.
	my $inh_netorder = $inhType->attribute_value('netorder') || 0;
	if ($inh_netorder ne $netorder) {
	    die ("%Error: $clname netorder=$netorder doesn't match $inh_netorder"
		 ." inherited from $inhType->{name}.\n");
	}
	$fl->print("    // w() and $toBytePtr() inherited from $self->{inherits}::\n");
	# Correct for any size difference
	(defined $inhType->{words}) or die "%Error: Missed words compute()\n";
	if (($self->{words}||0) > $inhType->{words}) {
	    # Ensure the parent type disabled array bounds checking.
	    my $inh_stretchable = $inhType->attribute_value('stretchable') || 0;
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
	$self->_class_h_write_dw($pack,$fl);

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
	for (my $word=0; $word<$self->{words}; $word++) {
	    $wr_masks[$word] = 0;
	    for (my $bit=$word*$self->{pack}->{data_bits};
		 $bit<(($word+1)*$self->{pack}->{data_bits});
		 $bit++) {
		my $bitent = $self->{bitarray}[$bit];
		next if !$bitent;
		$wr_masks[$word] |= (1<<($bit & ($self->{pack}->{data_bits}-1)))
		    if ($bitent->{write});
	    }
	}
	if ($self->{words}<2 && !$c) {
	    $fl->printf("    static const uint32_t BITMASK_WRITABLE = 0x%08x;\n", $wr_masks[0]);
	    $fl->fn($clname, "", "inline void wWritable(int b, uint32_t val)"
		    ,"{ ${wset}b,(val&BITMASK_WRITABLE)|(${wget}b)&~BITMASK_WRITABLE)); };\n");
	} else {
	    # Grrr, Greenhills Compilers don't allow
	    # static const uint32_t BITMASK_WRITABLE[] = {...};
	    $fl->fn($clname,"","inline uint32_t wBitMaskWritable(int b)"
		    ,"{\n");
	    for (my $word=0; $word<$self->{words}; $word++) {
		$fl->printf("\tif (b==$word) return 0x%08x;\n", $wr_masks[$word]);
	    }
	    $fl->printf("\treturn 0; }\n");
	    my $fwritable = $fl->call_str($clname,"","wBitMaskWritable(b)");
	    $fl->fn($clname,"","inline void wWritable(int b, uint32_t val)"
		    ,"{ ${wset}b,(val&${fwritable})|(${wget}b)&~${fwritable})); };\n");
	}
    }

    my @resets=();
    if ($self->{inherits}) {
	if ($c) {
	    my $call = $fl->call_str($self->{inherits},"","fieldsReset();\n");
	    $call =~ s/\(/(($self->{inherits}*)/;  # Need a cast
	    push @resets, "\t".$call;
	} else {
	    push @resets, "\t".$self->{inherits}."::fieldsReset();\n";
	}
    }
    my @dumps = ();
    $fl->printf("\n");

    my @fields = $c ? ($self->fields_sorted_inherited()) : ($self->fields_sorted());
	
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
		$deposit .= sprintf " ${wset}${word}, (${wget}${word})&0x%08x$L) | ((%sb$frombit&0x%x$L)<<${low_mod}));"
		    , (~$mask&0xffffffff), ($frombit?"(":""), $deposit_mask;
	    }
	}

	if ($bitref->{rst} ne 'X') {
	    my $rst = $bitref->{rst};
	    $rst = 0 if ($rst =~ /^FW-?0$/);
	    if ($rst =~ /^[a-z]/i && $bitref->{type}) {	# Probably a enum value
		if ($c) {
		    $rst = "$bitref->{type}_$rst";
		} else {
		    $rst = "$bitref->{type}::$rst";
		}
	    }
	    #$fl->printf("\tstatic const %s %s = %s;\n", $bitref->{type},
	    #		uc($lc_mnem)."_RST", $rst);
	    push @resets, $fl->call_str($clname,"set",sprintf("\t%s(%s);\n", $lc_mnem, $rst));
	}

	# Mask after shifting on reads, so the mask is a smaller constant.
	$fl->private_not_public ($bitref->{access} !~ /R/, $pack);
	my $typEnd = 11 + length $bitref->{type};
	$fl->fn($clname,"",sprintf("inline %s%s%-13s () const",
				   $bitref->{type}, ($typEnd < 16 ? "\t\t" : $typEnd < 24 ? "\t" : " "),
				   $lc_mnem)
		,"{ return ${typecast}(${extract} ); }\n");

	$fl->private_not_public ($bitref->{access} !~ /W/, $pack);
	$fl->fn($clname,"set",sprintf("inline void\t\t%-13s (%s b)", $lc_mnem, $bitref->{type})
		,"{${deposit} }\n");

	push @dumps, "\"$bitref->{name}=\"<<$lc_mnem()"
    }

    $fl->printf("\n");
    $fl->private_not_public (0, $pack);
    if (!$c) {
	$fl->printf("    VREGS_STRUCT_DEF_CTOR(%s, %s)\t// (typeName, numWords)\n",
		    $clname, $words);
    }

    $fl->fn($clname,"","void fieldsZero()"
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
    $fl->print("    };\n");

    $fl->fn($clname,"","void fieldsReset()"
	    ,"{\n"
	    ,"\t",$fl->call_str($clname,"","fieldsZero();\n")
	    ,@resets
	    ,"    };\n");

    if (!$c) {
	$fl->fn($clname,"","inline bool operator== (const ${clname}& rhs) const"
		,"{\n"
		,"\t${cForInt}i=0; i<${words}; i++) { if (m_w[i]!=rhs.m_w[i]) return false; }\n"
		,"\treturn true;\n"
		,"    };\n");
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
    }

    $fl->print("\n");
}

######################################################################
######################################################################
######################################################################

sub class_h_write {
    # Dump type definitions
    my $self = shift;

    my $fl = SystemC::Vregs::File->open(rules => $self->{rules},
					language=>'CPP', @_);

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

sub struct_h_write {
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
	$fl->print("#include \"$packref->{name}_struct.h\"\n");
    }

    $fl->print("\n\n");

    foreach my $classref ($self->enums_sorted) {
	$classref->enum_struct_write ($self, $fl);
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

    my $fields_lcFirst = $self->attribute_value('lcfirst') || 0;
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
					language=>'CPP', @_);

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
	if (($fl->{C} || $fl->{CPP}) && $define =~ /^C[BER][0-9]/) {
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
	 ."\tP_{defname}             Define values as a parameter\n"
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

	if ($define =~ s/^(RA|CM)_/${1}P_/
	    || ($defref->{is_manual} && $define =~ s/^(.*)$/P_$1/)) {
	    my $prt_val = _param_write_value($defref, $fl);
	    $fl->printf ("   %s %-26s %13s%s\n",
			 ($self->attribute_value('v2k') ? 'localparam':'parameter'),
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
			     ($self->attribute_value('v2k') ? 'localparam':'parameter'),
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

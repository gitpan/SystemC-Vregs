# $Id: Outputs.pm,v 1.51 2001/06/27 16:10:22 wsnyder Exp $
# Author: Wilson Snyder <wsnyder@wsnyder.org>
######################################################################
#
# This program is Copyright 2001 by Wilson Snyder.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of either the GNU General Public License or the
# Perl Artistic License, with the exception that it cannot be placed
# on a CD-ROM or similar media for commercial distribution without the
# prior approval of the author.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# If you do not have a copy of the GNU General Public License write to
# the Free Software Foundation, Inc., 675 Mass Ave, Cambridge, 
# MA 02139, USA.
######################################################################

package SystemC::Vregs::Outputs;
use File::Basename;
use Carp;
use vars qw($VERSION);
$VERSION = '0.1';

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

    $self->print("// -*- C++ -*-\n") if ($self->{C});
    $self->comment("DO NOT EDIT -- Generated automatically by vregs\n");
    $self->comment("DESC"."RIPTION: Register Information: Generated automatically by vregs\n");
    $self->print("\n");

    if ($self->{rules}) {
	$self->{rules}->filehandle($self);
	foreach my $rfile ($self->{rules}->filenames()) {
	    $rfile = basename($rfile,"^");
	    $self->comment("See SystemC::Vregs::Rules file: $rfile\n");
	}
	$self->print("\n");
    }

    return $self;
}

sub close {
    my $self = shift;
    # General routine for closing output file

    $self->close_prep();
    $self->print("\n");
    $self->comment ("DO NOT EDIT -- Generated automatically by vregs\n");

    $self->SUPER::close();
}

sub private_not_public {
    my $self = shift;
    my $private = shift;
    # Print public: or private: depending on desired state
    if ($private && !$self->{private}) {
	$self->print ("private:\n");
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
	$fl->printf ("\t%-13s = 0x%x,\t/* %s */\n"
		     ,$fieldref->{name},$fieldref->{rst_val},$fieldref->{desc});
    }
    # Perhaps this should just be added to the data structures?
    # note no comma to make C happy
    $fl->printf("\t%-13s = 0x%x\t/* %s */\n"
		,"MAX", (1<<$self->{bits}), "MAXIMUM+1");
    $fl->print ("    };\n");
    $fl->print ("    enum en m_e;\n");
    $fl->print ("    inline ${clname} () {};\n");
    $fl->print ("    inline ${clname} (en _e) : m_e(_e) {};\n");
    $fl->print ("    explicit inline ${clname} (int _e) : m_e(static_cast<en>(_e)) {};\n");
    $fl->print ("    operator const char * (void) const { return ascii(); };\n");
    $fl->print ("    operator en (void) const { return m_e; };\n");
    $fl->print ("    const char * ascii (void) const {\n");
    $fl->print ("	switch (m_e) {\n");
    foreach my $fieldref ($self->fields_sorted()) {
	$fl->printf ("\tcase %s: return(\"%s\");\n"
		     ,$fieldref->{name},$fieldref->{name});
    }
    $fl->print ("	default: return (\"%E\");\n");
    $fl->print ("	}\n");
    $fl->print ("    };\n");
    
    $pack->{rules}->execute_rule ('enum_end_before', $clname, $self);
    $fl->print ("  };\n");
    $pack->{rules}->execute_rule ('enum_end_after', $clname, $self);
    
    #$fl->print ("  ostream& operator <<(ostream &o, ${clname} &en) {\n");
    #$fl->print ("    o << setiosflags(ios::left) << setw(5) << (const char*)en; return o;};\n");
    $fl->print ("  inline bool operator== (${clname} lhs, ${clname} rhs) { return (lhs.m_e == rhs.m_e); }\n",
		"  inline bool operator== (${clname} lhs, ${clname}::en rhs) { return (lhs.m_e == rhs); }\n",
		"  inline bool operator== (${clname}::en lhs, ${clname} rhs) { return (lhs == rhs.m_e); }\n",
		"  inline std::ostream& operator<< (std::ostream& lhs, const ${clname}& rhs) { return lhs << rhs.ascii(); }\n",
		"  inline bool operator< (${clname} lhs, ${clname} rhs) { return lhs.m_e < rhs.m_e; }\n",
		"\n",
		);
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
    return $pack->{attributes}{$attr} if defined $pack->{attributes}{$attr};
    return undef;
}

sub SystemC::Vregs::Type::_type_write {
    my $self = shift;
    my $pack = shift;
    my $fl = shift;
    my $clname = $self->{name} || "x";

    my $words = 0;
    my @fields = (values %{$self->{fields}});
    if ($self->{inherits_typeref}) {
	push @fields, (values %{$self->{inherits_typeref}->{fields}});
    }
    foreach my $bitref (@fields) {
	foreach my $bit (@{$bitref->{bitlist}}) {
	    $words = int($bit / 32)+1 if $words < int($bit / 32)+1;
	}
    }
    
    my $netorder = attribute_value($pack,$self,'netorder');
    my $ntohl = ($netorder ? "ntohl" : "");
    my $htonl = ($netorder ? "htonl" : "");
    my $uint  = ($netorder ? "nint32_t" : "uint32_t");

    my $inh = "";
    $inh = " : $self->{inherits}" if $self->{inherits};

    $pack->{rules}->execute_rule ('class_begin_before', $clname, $self);
    $fl->print("struct $clname$inh {\n");
    $fl->set_private(0);	# struct implies public:
    $pack->{rules}->execute_rule ('class_begin_after', $clname, $self);
    $fl->printf("    const static size_t SIZE = %d;\n", $words*4);

    if ($inh ne "") {
	$fl->print("    // w() inherited from $self->{inherits}::\n");
    } else {
	$fl->print("    ${uint} m_w[${words}];\n",
		   "    inline uint32_t w(int b) const { return (${ntohl}(m_w[b])); };\n",
		   "    inline void w(int b, uint32_t val) { m_w[b] = ${htonl}(val); };\n",);
    }

    my @resets=();
    push @resets, sprintf("\t%s::fieldsReset();\n",$self->{inherits}) if $self->{inherits};
    foreach my $bitref ($self->fields_sorted()) {
	my $lc_mnem = $bitref->{name};
	$lc_mnem =~ s/^(.)/lc $1/xe;
	my $typecast = "";
	$typecast = "($bitref->{type})" if $bitref->{cast_needed};
	$typecast = "(void*)" if $bitref->{type} eq 'void*';	# Damn C++
	my $L = ($bitref->{numbits}>32)?'LL':'';

        my $extract = "";
        my $deposit = "";
        foreach my $bitrange (@{$bitref->{bitlist_range}}) {
	    my ($msb,$lsb,$nbits,$srcbit) = @{$bitrange};
	    my $low_mod = $lsb % 32;
	    my $high_mod = $msb % 32;
	    my $word = int($lsb/32);
	    (int($msb/32)==$word) or die "%Error: One _range cannot span two words\n";
	    my $deposit_mask = (1<<$nbits)-1;
	    $deposit_mask = -1 if $nbits==32;
	    my $mask = $deposit_mask << $low_mod;
	    $mask = -1 if $high_mod==31 && $low_mod==0;
	    
	    $extract .= "|" if $extract ne "";
	    if ($high_mod==31 && $low_mod==0 && $srcbit==0) {
		# Whole word, skip the B.S.
		$extract .= "w(${word})";
		$deposit .= "w(${word}, (uint32_t)(b));";
	    } else {
		my $tobit = "<<$srcbit$L";
		$tobit = "" if $srcbit==0;
		my $frombit = ">>$srcbit$L";
		$frombit = "" if $srcbit==0;
		$extract .= sprintf " (((w(${word})>>${low_mod}$L)&0x%x$L)$tobit)"
		    , $deposit_mask;
		$deposit .= sprintf "w(${word}, (w(${word})&0x%08x$L) | (((b$frombit)&0x%x$L)<<${low_mod}));"
		    , ~$mask, $deposit_mask;
	    }
	}

	if ($bitref->{rst} ne 'X') {
	    my $rst = $bitref->{rst};
	    $rst = 0 if ($rst =~ /^FW-?0$/);
	    if ($rst =~ /^[a-z]/i && $bitref->{type}) {	# Probably a enum value
		$rst = "$bitref->{type}::$rst";
	    }
	    #$fl->printf("\tconst static %s %s = %s;\n", $bitref->{type},
	    #		uc($lc_mnem)."_RST", $rst);
	    push @resets, sprintf("\t%s(%s);\n", $lc_mnem, $rst);
	}

	# Mask after shifting on reads, so the mask is a smaller constant.
	$fl->private_not_public ($bitref->{access} !~ /R/);
	$fl->printf("\tinline %s\t%-13s (void) const ", $bitref->{type}, $lc_mnem);
	$fl->print("{ return (${typecast}(${extract})); };");
	#printf $fl "\t//%s", $bitref->{desc};
	$fl->printf("\n");

	$fl->private_not_public ($bitref->{access} !~ /W/);
	$fl->printf("\tinline void\t%-13s (%s b) ", $lc_mnem, $bitref->{type});
	$fl->print("{ ${deposit} };");
	#printf $fl "\t//%s", $bitref->{desc};
	$fl->printf("\n");
    }

    $fl->private_not_public (0);
    $fl->print("    void fieldsReset (void) {\n",
	       @resets,
	       "    };\n");
    $fl->print("    void fieldsZero (void) {\n",
	       "\tfor (int i=0; i<${words}; i++) w(i,0);\n",
	       "    };\n");

    $pack->{rules}->execute_rule ('class_end_before', $clname, $self);
    $fl->print("};\n");
    $pack->{rules}->execute_rule ('class_end_after', $clname, $self);
    $fl->print("\n");
}

sub type_write {
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

    $fl->print("// Types:\n",
	       "#ifndef _NINT32_T_\n",
	       "#define _NINT32_T_ 1\n",
	       "typedef uint8_t  nint8_t;   // Always identical\n",
	       "typedef uint16_t nint16_t;  // Uint stored in network order\n",
	       "typedef uint32_t nint32_t;  // Uint stored in network order\n",
	       "typedef uint64_t nint64_t;  // Uint stored in network order\n",
	       "#endif\n",
	       "\n",);

    $fl->print("\n\n");

    foreach my $classref ($self->enums_sorted) {
	$classref->enum_write ($self, $fl);
    }

    $fl->print("\n\n");
    # Bitbashing done verbosely to avoid slow preprocess time
    # We could use bit structures, but they don't work on non-contiguous fields

    # Sorted first does base classes, then children
    foreach my $typeref ($self->types_sorted) {
	$typeref->_type_write($self, $fl);
    }

    $self->{rules}->execute_rule ('file_body_after', 'file_body', $self);

    $fl->close();
}

######################################################################

sub header_write {
    my $self = shift;
    # Dump general register definitions

    $self->create_defines(1);
    my $fl = SystemC::Vregs::File->open(@_);
    $fl->include_guard();
    $fl->print("\n");
    $fl->comment("package $self->{name}\n");
    $fl->print("\n");

    $fl->comment(("*"x70)."\n"
		 ."   General convention:\n"
		 ."     RA_{regname}          Register address\n"
		 ."     RAE_{regname}         Register ending address + 1\n"
		 ."     RAC_{regname}         Number of entries in register\n"
		 ."     RAM_{regname}         Register region address mask\n"
		 ."     CB_{class}_{field}    Class field starting bit\n"
		 ."     CE_{class}_{field}    Class field ending bit\n"
		 ."     CR_{class}_{field}    Class field range\n"
		 );
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
	$value = $fl->sprint_hex_value ($value,$defref->{bits}) if (defined $defref->{bits});
	if ($fl->{Perl} && ($defref->{bits}||0) > 32) {
	    $fl->print ("#");
	    $comment .= " (TOO LARGE FOR PERL)";
	}
	if (!$defref->{is_verilog} || $fl->{Verilog}) {
	    $fl->define ($define, $value, $comment);
	}
    }

    $fl->close();
}

######################################################################

sub parameter_write {
    my $self = shift;
    # Dump general register definitions

    $self->create_defines(1);
    my $fl = SystemC::Vregs::File->open(language=>'Verilog', @_);

    $fl->include_guard();

    $fl->comment(("*"x70)."\n"
		 ."\tRAP_{regname}          Register address as a parameter\n"
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
	my $value   = $defref->{rst_val};
	my $comment = $defref->{desc};
	$value = $fl->sprint_hex_value ($value,$defref->{bits}) if (defined $defref->{bits});
	if ($define =~ s/^RA_/RAP_/) {
	    $fl->printf ("   parameter %-26s %12s\t// ${comment}\n",
			 $define . " =", $value.";", 
			 "Address of Module Base");
	}
    }

    $fl->close();
}

######################################################################

sub h_info_write {
    my $self = shift;
    # Dump headers for pli routines

    my $fl = SystemC::Vregs::File->open(language=>'C', @_);
    $fl->print ("\n"
		."class VregsRegInfo;\n"
		."\n");

    $fl->print ("class $self->{name}_info {\n"
		,"public:\n"
		,"    static void add_registers(VregsRegInfo* reginfop);\n"
	        ,"};\n\n");

    $fl->close();
}

sub c_info_write {
    my $self = shift;
    # Dump c pli routines

    $self->create_defines(1);
    my $fl = SystemC::Vregs::File->open(language=>'C', @_);

    $fl->print ("// Not for direct use -- VregsRegInfo.h provides all accessors\n"
		."\n"
		."#include \"VregsRegInfo.h\"\n"
		."#include \"$self->{name}_info.h\"\n"
	        ."\n");
		
    $fl->print ("//".('='x68)."\n\n");

    $fl->print ("void $self->{name}_info::add_registers(VregsRegInfo* rip)\n"
		,"{\n");

    $fl->printf ("    // Shorten the register info lines\n");
    $fl->printf ("#   define RFRDSIDE VregsRegEntry::REGFL_RDSIDE\n");
    $fl->printf ("#   define RFWRSIDE VregsRegEntry::REGFL_WRSIDE\n");
    $fl->printf ("    //rip->add_register( address,      spacing,  name,\n");
    $fl->printf ("    //  rdMask,     wrMask,     rstVal,     rstMask,    flags);\n");

    foreach my $regref ($self->regs_sorted()) {
	#reginfop->add_register (0x1010, 4, "Reg_at_0x1010", 4, 1);
	my $size = $self->addr_const_vec(4);	## FIX?
	my $noarray =  attribute_value($self,$regref->{typeref},'noarray');
	if ($noarray) {
	    # User wants to treat it as a bulk region without [] subscripts in info
	    # This munging should probably be done in Register instead.
	    $size->subtract ($regref->{addr_end}, $regref->{addr}, 0);
	}
	$fl->printf ("    rip->add_register (%s, %s, \"%s\"",
		     $fl->sprint_hex_value ($regref->{addr}, $self->{address_bits}),
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
	$fl->printf ("|RFDSIDE") if $rd_side;
	$fl->printf ("|RFWRSIDE") if $wr_side;
	$fl->printf (");\n",);
    }

    $fl->printf ("#   undef RFTEST\n");
    $fl->printf ("#   undef RFRDSIDE\n");
    $fl->printf ("#   undef RFWRSIDE\n");
    $fl->print ("};\n\n");

#    #########  vregs_val_bits
#    $fl->print ("const char *vregs_val_bits (\n"
#		 ."   address_t addr, uint32_t data, const char *prefix, const char *postfix)\n"
#		 ."/* Return character string for printing data, null if bad */\n"
#		 ."{\n"
#		 ."    static char buf[1000];\n"
#		 ."    int regnum;\n"
#		 ."    uint32_t lookup = vregs_lookup (addr);\n"
#		 ."    if (lookup==0) return (NULL);\n"
#		 ."    regnum = lookup & 0xffff;\n"
#		 ."    buf[0]='\\0';\n"
#		 ."    switch (regnum) {\n");
#    foreach my $regref ($self->regs_sorted()) {
#	 my $reg_mnem   = $regref->{name};
#	 # Each field include:
#	 #    $prefix "_" $bitfield "=" $data $postfix
#	 my $fmt = ""; my $vars="";
#	 foreach my $bitref (sort {$a->{bit_high} <=> $b->{bit_high}}
#			     (values %{$regref->{fields}})) {
#	     my $bit_mnem = $bitref->{name};
#	     my $bit_high = $bitref->{bit_high};
#	     my $bit_low  = $bitref->{bit_low};
#	     $fmt .= "%s_${bit_mnem}=";
#	     $fmt .= "0x" if ($bit_high - $bit_low)>3;
#	     $fmt .= "%x%s";
#	     my $vdata = sprintf "(data>>%d)&0x%x", $bit_low, (1<<($bit_high-$bit_low+1))-1;
#	     $vdata = "data" if ($bit_low==0 && $bit_high==31);
#	     $vars .= ", prefix, $vdata, postfix";
#	 }
#	 if ($fmt ne "") {
#	     $fl->printf ("    case 0x%x: ", $ids{$reg_mnem});
#	     $fl->print ("sprintf (buf, \"$fmt\" $vars); break;\n");
#	 }
#    }

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

=item METHODS

=over 4

=item type_write

Creates a C++ header file with class definitions.

=item header_write

Creates a C++, Verilog, or Perl header file with defines.  The language
parameter is used along with SystemC::Vregs::Language to produce the
definitions in a language appropriate way.

=item parameter_write

Creates a Verilog header file with parameters in place of defines.

=item h_info_write

Creates a header file for use with c_info_write.

=item c_info_write

Creates a C++ file with information on each register.  The information is
then added to a map which may be used during runtime to decode register
addresses into names.

=back

=head1 SEE ALSO

C<SystemC::Vregs>

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=cut

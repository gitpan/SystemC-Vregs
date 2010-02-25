# See copyright, etc in below POD section.
######################################################################

package SystemC::Vregs::Output::Info;
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
# METHODS

sub write_h {
    my $self = shift;
    my %params = (pack => $self->{pack},
		  @_);
    my $pack = $params{pack} or croak "%Error: No pack=> parameter passed,";
    # Dump headers for class name based accessors

    my $fl = SystemC::Vregs::File->open(language=>'CPP',
					rules => $pack->{rules},
					@_);
    $fl->include_guard();

    $pack->{rules}->execute_rule ('info_cpp_file_before', 'file_body', $pack);

    $fl->print ("\n");
    $fl->print ("#include \"VregsRegInfo.h\"\n");

    my $name = $pack->{name};
    my $nameInfo = $name."_info";
    my $nameClass = $nameInfo."_class";
    $fl->print ("/// Information on this specification. See VregsSpecInfo for documentation.\n",
		"// There's will be just one of this structure, constructed at init time,\n",
		"class ${nameClass} : public VregsSpecInfo {\n",
		"public:\n",
		"    // CONSTRUCTORS\n",
		"    ${nameClass}();\n",
		"    virtual ~${nameClass}() {}\n",
		"    // METHODS\n",
		"    virtual const char* name();\n",
		"    virtual void   addRegisters(VregsRegInfo* reginfop);\n",
		"    virtual bool   isClassName(const char* className);\n",
		"    virtual int    numClassNames();\n",
		"    virtual const char** classNames();\n",
		"    virtual void   dumpClass(const char* className, void* datap, OStream& ost=COUT, const char* pf=\"\\n\\t\");\n",
		"};\n",
		"\n",
		"extern ${nameClass} ${nameInfo};\n",
		);
    $fl->close();
}

sub write_cpp {
    my $self = shift;
    my %params = (pack => $self->{pack},
		  @_);
    my $pack = $params{pack} or croak "%Error: No pack=> parameter passed,";
    # Dump headers for class name based accessors

    my $fl = SystemC::Vregs::File->open(rules => $pack->{rules},
					language=>'CPP', @_);

    my $name = $pack->{name};
    my $nameInfo = $name."_info";
    my $nameClass = $nameInfo."_class";

    $fl->print ("#include \"${nameInfo}.h\"\n"
	        ."\n");
    $fl->print ("#include \"$pack->{name}_class.h\"\n");

    $fl->print ("//".('='x68)."\n");
    $fl->print ("// STATICS\n");

    $fl->print ("// Create the informational structure, which will link to list of all specs\n",
		"${nameClass} ${nameInfo};\n\n");

    $fl->print ("//".('='x68)."\n");
    $fl->print ("// METHODS\n\n");

    $fl->print ("${nameClass}::${nameClass}() {\n",
		"    VregsSpecsInfo::addSpec(\"${name}\", &${nameInfo});\n",
		"}\n\n");

    $fl->print ("const char* ${nameClass}::name() { return \"${name}\"; }\n\n");

    $fl->print ("static const char* $pack->{name}_named_classNames[] = {\n");
    my $nclasses=0;
    foreach my $typeref (sort { $a->{name} cmp $b->{name}}  # Else sorted by need of base classes
			 $pack->types_sorted) {
	next if $typeref->attribute_value('nofielddefines');
	$fl->print ("\t\"$typeref->{name}\",\n");
	$nclasses++;
    }
    $fl->print ("};\n\n");

    $fl->print ("const char** ${nameClass}::classNames() {\n");
    $fl->print ("    return $pack->{name}_named_classNames;\n\n");
    $fl->print ("}\n\n");

    $fl->print ("int ${nameClass}::numClassNames() {\n"
		,"    return ${nclasses};\n"
		,"}\n\n");

    $fl->print ("bool ${nameClass}::isClassName(const char* className) {\n");
    $fl->print ("    for (int i=0; i<numClassNames(); i++) {\n"
		,"\tif (0==strcmp(className, $pack->{name}_named_classNames[i])) return true;\n"
		,"    }\n");
    $fl->print ("    return false;\n");
    $fl->print ("}\n\n");

    $fl->print ("void ${nameClass}::dumpClass(const char* className, void* datap, OStream& ost, const char* pf) {\n");
    #$fl->print ("    // Must call .w() functions on each, as each class may have differing endianness\n");
    my $else = "";
    foreach my $typeref ($pack->types_sorted) {
	next if $typeref->attribute_value('nofielddefines');
	$fl->print ("    ${else}if (0==strcmp(className,\"$typeref->{name}\")) {\n"
		    ,"\t$typeref->{name}* p = ($typeref->{name}*)datap; \n"
		    ,"\tost<<p->dump(pf);\n"
		    ,"    }\n");
	$else = "else ";
    }
    $fl->print ("}\n\n");

    my %flags;
    foreach my $regref ($pack->regs_sorted()) {
	$flags{RFPACK} = 1 if $regref->attribute_value("packholes");
    }

    $fl->print ("//".('='x68)."\n\n");

    $fl->print ("void ${nameClass}::addRegisters(VregsRegInfo* rip) {\n");

    $fl->printf ("    // Shorten the register info lines\n");
    $fl->printf ("#   define RFRDSIDE  VregsRegEntry::REGFL_RDSIDE\n");
    $fl->printf ("#   define RFWRSIDE  VregsRegEntry::REGFL_WRSIDE\n");
    $fl->printf ("#   define RFPACK    VregsRegEntry::REGFL_PACKHOLES\n") if $flags{RFPACK};
    $fl->printf ("    //rip->add_register( address,       size,   name,     spacing, rangeLow, rangeHi,\n");
    $fl->printf ("    //  rdMask,     wrMask,     rstVal,     rstMask,\n");
    $fl->printf ("    //  flags, attributes);\n");

    foreach my $regref ($pack->regs_sorted()) {
	my $size = $pack->addr_const_vec($regref->{typeref}{words}*4);
	my $noarray =  $regref->attribute_value('noarray');
	if ($noarray) {
	    # User wants to treat it as a bulk region without [] subscripts in info
	    # This munging should probably be done in Register instead.
	    $size->subtract ($regref->{addr_end}, $regref->{addr}, 0);
	}
	$fl->printf ("    rip->add_register (%s, %s, \"%s\"",
		     $fl->sprint_hex_value_add0 ($regref->{addr}, $pack->{address_bits}),
		     $fl->sprint_hex_value_drop0 ($size, $pack->{address_bits}),
		     $regref->{name});
	if ($regref->{range} && ! $noarray) {
	    $fl->printf (", %s, %s, %s,\n",
			 $fl->sprint_hex_value_drop0 ($regref->{spacing}, $pack->{address_bits}),
			 $fl->sprint_hex_value_drop0 ($regref->{range_low}, $pack->{address_bits}),
			 $fl->sprint_hex_value_drop0 ($regref->{range_high_p1}, $pack->{address_bits}));
	} else {
	    $fl->print (",\n");
	}

	my $nbits = $pack->data_bits();
	$nbits = $size->to_Dec*8 if $size->to_Dec*8 > $nbits;

	my $rd_side = 0;
	my $wr_side = 0;
	my $rd_mask = Bit::Vector->new($nbits);
	my $wr_mask = Bit::Vector->new($nbits);
	my $rst_val = Bit::Vector->new($nbits);
	my $rst_mask = Bit::Vector->new($nbits);
	my $typeref = $regref->{typeref};

	for (my $bit=0; $bit<$nbits; $bit++) {
	    my $bitent = $typeref->{bitarray}[$bit];
	    next if !$bitent;
	    $rd_mask->Bit_On($bit) if ($bitent->{read});
	    $wr_mask->Bit_On($bit) if ($bitent->{write});
	    $rd_side   =  1 if ($bitent->{read_side});
	    $wr_side   =  1 if ($bitent->{write_side});
	    if (defined $bitent->{rstvec}) {
		$rst_mask->Bit_On($bit);
		$rst_val ->Bit_On($bit) if ($bitent->{rstvec});
	    }
	}
	$fl->printf (( ($nbits > 32)
		       ? "\tVREGS_ULL(0x%s), VREGS_ULL(0x%s), VREGS_ULL(0x%s), VREGS_ULL(0x%s),\n"
		       : "\t0x%s, 0x%s, 0x%s, 0x%s,\n"),
		     lc($rd_mask->to_Hex), lc($wr_mask->to_Hex),
		     lc($rst_val->to_Hex), lc($rst_mask->to_Hex));
	$fl->printf ("\t0");
	$fl->printf ("|RFRDSIDE") if $rd_side;
	$fl->printf ("|RFWRSIDE") if $wr_side;
	$fl->printf ("|RFPACK") if $flags{RFPACK} && $regref->attribute_value("packholes");
	$fl->printf (", \"%s\"", $typeref->attributes_string);
	$fl->printf (");\n",);
    }

    $fl->printf ("#   undef RFRDSIDE\n");
    $fl->printf ("#   undef RFWRSIDE\n");
    $fl->printf ("#   undef RFPACK\n") if $flags{RFPACK};
    $fl->print ("};\n\n");

    $pack->{rules}->execute_rule ('info_cpp_file_after', 'file_body', $pack);

    $fl->close();
}

######################################################################
######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::Output::Info - Outputting Vregs _dump Code

=head1 SYNOPSIS

SystemC::Vregs::Output::Info->new->write_h(pack=>$VregsPackageObject, filename=>$fn);
SystemC::Vregs::Output::Info->new->write_cpp(pack=>$VregsPackageObject, filename=>$fn);

=head1 DESCRIPTION

This package dumps vregs format into a file.  It is called by the Vregs
package.

=head1 METHODS

=over 4

=item new()

Create and return a new output class.

=item write_h

Creates a header file for use with write_cpp.

=item write_cpp

Creates a C++ file with information on each register.  The information is
then added to a map which may be used during runtime to decode register
addresses into names.

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

# $Revision: 1.19 $$Date: 2005-07-27 09:55:32 -0400 (Wed, 27 Jul 2005) $$Author: wsnyder $
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

package SystemC::Vregs::OutputInfo;
use File::Basename;
use Carp;
use vars qw($VERSION);
$VERSION = '1.301';

use SystemC::Vregs::Outputs;
use SystemC::Vregs::Number;
use SystemC::Vregs::Language;
use strict;

# We simply add to the existing package...
package SystemC::Vregs;

######################################################################

sub info_h_write {
    my $self = shift;
    # Dump headers for class name based accessors

    my $fl = SystemC::Vregs::File->open(language=>'C',
					rules => $self->{rules},
					@_);
    $fl->include_guard();

    $self->{rules}->execute_rule ('info_cpp_file_before', 'file_body', $self);

    $fl->print ("\n");
    $fl->print ("#include \"VregsRegInfo.h\"\n");

    my $name = $self->{name};
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

sub info_cpp_write {
    my $self = shift;
    # Dump headers for class name based accessors

    my $fl = SystemC::Vregs::File->open(rules => $self->{rules},
					language=>'C', @_);

    my $name = $self->{name};
    my $nameInfo = $name."_info";
    my $nameClass = $nameInfo."_class";

    $fl->print ("#include \"${nameInfo}.h\"\n"
	        ."\n");
    $fl->print ("#include \"$self->{name}_class.h\"\n");
		
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

    $fl->print ("static const char* $self->{name}_named_classNames[] = {\n");
    my $nclasses=0;
    foreach my $typeref (sort { $a->{name} cmp $b->{name}}  # Else sorted by need of base classes
			 $self->types_sorted) {
	$fl->print ("\t\"$typeref->{name}\",\n");
	$nclasses++;
    }
    $fl->print ("};\n\n");

    $fl->print ("const char** ${nameClass}::classNames() {\n");
    $fl->print ("    return $self->{name}_named_classNames;\n\n");
    $fl->print ("}\n\n");

    $fl->print ("int ${nameClass}::numClassNames() {\n"
		,"    return ${nclasses};\n"
		,"}\n\n");

    $fl->print ("bool ${nameClass}::isClassName(const char* className) {\n");
    $fl->print ("    for (int i=0; i<numClassNames(); i++) {\n"
		,"\tif (0==strcmp(className, $self->{name}_named_classNames[i])) return true;\n"
		,"    }\n");
    $fl->print ("    return false;\n");
    $fl->print ("}\n\n");

    $fl->print ("void ${nameClass}::dumpClass(const char* className, void* datap, OStream& ost, const char* pf) {\n");
    #$fl->print ("    // Must call .w() functions on each, as each class may have differing endianness\n");
    my $else = "";
    foreach my $typeref ($self->types_sorted) {
	$fl->print ("    ${else}if (0==strcmp(className,\"$typeref->{name}\")) {\n"
		    ,"\t$typeref->{name}* p = ($typeref->{name}*)datap; \n"
		    ,"\tost<<p->dump(pf);\n"
		    ,"    }\n");
	$else = "else "; 
    }
    $fl->print ("}\n\n");


    $fl->print ("//".('='x68)."\n\n");

    $fl->print ("void ${nameClass}::addRegisters(VregsRegInfo* rip) {\n");

    $fl->printf ("    // Shorten the register info lines\n");
    $fl->printf ("#   define RFRDSIDE  VregsRegEntry::REGFL_RDSIDE\n");
    $fl->printf ("#   define RFWRSIDE  VregsRegEntry::REGFL_WRSIDE\n");
    $fl->printf ("#   define RFNORTEST VregsRegEntry::REGFL_NOREGTEST\n");
    $fl->printf ("#   define RFNORDUMP VregsRegEntry::REGFL_NOREGDUMP\n");
    $fl->printf ("    //rip->add_register( address,       size,   name,     spacing, rangeLow, rangeHi,\n");
    $fl->printf ("    //  rdMask,     wrMask,     rstVal,     rstMask,    flags);\n");

    foreach my $regref ($self->regs_sorted()) {
	my $size = $self->addr_const_vec($regref->{typeref}{words}*4);
	my $noarray =  $regref->attribute_value('noarray');
	my $noregtest = $regref->attribute_value('noregtest');
	my $noregdump = $regref->attribute_value('noregdump');
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
######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::OutputInfo - Outputting Vregs _dump Code

=head1 SYNOPSIS

    use SystemC::Vregs::OutputInfo;

=head1 DESCRIPTION

This package contains additional SystemC::Vregs methods.  These methods
are used to output various types of files.

=head1 METHODS

=over 4

=item info_h_write

Creates a header file for use with info_cpp_write

=item info_cpp_write

Creates a C++ file which allows textual class names to be mapped
to appropriate pointer types for dumping to a stream.

=back

=head1 DISTRIBUTION

The latest version is available from CPAN and from L<http://www.veripool.com/>.

Copyright 2001-2005 by Wilson Snyder.  This package is free software; you
can redistribute it and/or modify it under the terms of either the GNU
Lesser General Public License or the Perl Artistic License.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=head1 SEE ALSO

L<SystemC::Vregs::Output>

=cut

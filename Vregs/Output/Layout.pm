# See copyright, etc in below POD section.
######################################################################

package SystemC::Vregs::Output::Layout;
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

sub _print_attributes {
    my $self = shift;
    my $item = shift;
    my $fl = shift;

    my $string = $item->attributes_string;
    $string =~ s/ +/\t/g;
    $string = "\t$string" if $string ne "";
    $fl->print($string);
}

sub _print_bit {
    my $self = shift;
    my $bitref = shift;
    my $fl = shift;

    my $descflags = "";
    $descflags = ".  Overlaps $bitref->{overlaps}." if $bitref->{overlaps};

    $fl->printf_tabify("\tbit\t%-15s\t%-7s\t%-3s %-11s\t%-7s"
		       ,$bitref->{name},$bitref->{bits},$bitref->{access}
		       ,$bitref->{type},$bitref->{rst});
    $self->_print_attributes($bitref,$fl);
    $fl->printf("\t \"%s%s\"\n", $bitref->{desc},$descflags);
}

sub _print_type {
    my $self = shift;
    my $typeref = shift;
    my $fl = shift;

    $fl->print("   type\t$typeref->{name}");
    if ($typeref->{inherits}) {
	$fl->print("\t:$typeref->{inherits}");
    }
    $self->_print_attributes($typeref, $fl);
    $fl->print("\n");
    foreach my $fieldref ($typeref->fields_sorted()) {
	$self->_print_bit($fieldref, $fl);
    }
}

######################################################################
# Saving

sub write {
    my $self = shift;
    my %params = (@_);
    my $pack = $params{pack} or croak "%Error: No pack=> parameter passed,";
    # Dump headers for class name based accessors

    my $fl = SystemC::Vregs::File->open(language=>'C',
					#rules => $pack->{rules},
					noheader => 1,
					%params);

    $fl->print("// DESCR"."IPTION: Register Layout: Generated AUTOMATICALLY by vregs\n");
    $fl->print("//\n");
    $fl->print("// Format:\n");
    $fl->print("//\tpackage {name}         [attributes...]\n");
    $fl->print("//\treg     {name} {type}[vec] {address} {spacing} [attributes...]\n");
    $fl->print("//\ttype    {name} [:{inherits}] [attributes...]\n");
    $fl->print("//\tbit     {name} {bits} {access} {type} {reset}  [attributes...] {description}\n");
    $fl->print("//\tconst   {name} {value} [attributes...] {description}\n");
    $fl->print("//\tdefine  {name} {value} [attributes...] {description}\n");
    $fl->print("//\tenum    {name}         [attributes...]\n");
    $fl->print("//  Where [attributes...] are multiple entries of '-{name}' or '-{name}={value}'\n");
    $fl->print("\n");

    $fl->print("package $pack->{name}");
    $self->_print_attributes($pack, $fl);
    $fl->print("\n");

    $fl->print("//Rebuild with: $pack->{rebuild_comment}\n") if $pack->{rebuild_comment};
    $fl->print("\n");

    $fl->print("//",'*'x70,"\n// Registers\n");
    my %printed;
    foreach my $regref ($pack->regs_sorted) {
	my $classname = $regref->{name} || "x";
	my $addr = $regref->{addr};
	my $range = $regref->{range} || "";
	if (!defined $addr) {
	    print "%Error: No address defined: ${classname}\n";
	} else {
	    (my $nor = $classname) =~ s/^R_//;
	    my $type = "Vregs${nor}";
	    $fl->printf("  reg\t$classname\t$type$range\t0x%s\t0x%s\t"
			, $addr->to_Hex, $regref->{spacing}->to_Hex);
	    $fl->print("\n");

	    my $typeref = $regref->{typeref};
	    if (!$printed{$typeref}) {
		$printed{$typeref} = 1;
		$self->_print_type ($typeref, $fl);
	    }
	}
    }

    $fl->print("//",'*'x70,"\n// Classes\n");
    foreach my $typeref ($pack->types_sorted) {
	if (!$printed{$typeref}) {
	    $printed{$typeref} = 1;
	    $self->_print_type ($typeref, $fl);
	}
    }

    $fl->print("//",'*'x70,"\n// Enumerations\n");
    foreach my $classref ($pack->enums_sorted) {
	my $classname = $classref->{name} || "x";
	$fl->printf("   enum\t$classname");
	$self->_print_attributes($classref, $fl);
	$fl->print("\n");

	foreach my $fieldref ($classref->fields_sorted()) {
	    next if $fieldref->{omit_from_vregs_file};
	    $fl->printf("\tconst\t%-13s\t%s"
			,$fieldref->{name},$fieldref->{rst});
	    $self->_print_attributes($fieldref, $fl);
	    $fl->printf("\t\"%s\"\n",$fieldref->{desc});
	}
    }

    $fl->print("//",'*'x70,"\n// Defines\n");
    foreach my $fieldref ($pack->defines_sorted) {
	next if !$fieldref->{is_manual};
	$fl->printf("\tdefine\t%-13s", $fieldref->{name});
	if ($fieldref->attribute_value('freeform')) {
	    $fl->printf("\t\"%s\"", $fieldref->{rst});
	} else {
	    $fl->printf("\t%s", $fieldref->{rst});
	}
	$self->_print_attributes($fieldref, $fl);
	$fl->printf("\t\"%s\"\n"
		    ,$fieldref->{desc});
    }

    $fl->close();
}

######################################################################
######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::Output::Layout - Outputting .vregs files

=head1 SYNOPSIS

SystemC::Vregs::Output::Layout->new->write(pack=>$VregsPackageObject, filename=>$fn);

=head1 DESCRIPTION

This package dumps .vregs format into a file.  It is called by the Vregs
package.

=head1 METHODS

=over 4

=item new()

Create and return a new output class.

=item write

Creates a file for use with vregs_read.

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

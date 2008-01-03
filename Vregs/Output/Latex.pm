# $Id: Latex.pm 49231 2008-01-03 16:53:43Z wsnyder $
# Author: Wilson Snyder <wsnyder@wsnyder.org>
######################################################################
#
# Copyright 2001-2008 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
######################################################################

package SystemC::Vregs::Output::Latex;
use SystemC::Vregs::Number;
use SystemC::Vregs::Language;
use Carp;
use strict;
use vars qw($VERSION);

$VERSION = '1.450';

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

sub _attrnames_collect {
    my $attrnames = shift;
    my $item = shift;
    foreach my $var (keys %{$item->{attributes}}) {
	$attrnames->{$var} = 1;
    }
}

sub _attrnames_format {
    my $attrnames = shift;
    my $out = "";
    foreach my $attr (sort keys %{$attrnames}) {
	$out .= "|l";
    }
    return $out;
}

sub _attrnames_head {
    my $attrnames = shift;
    my $out = "";
    foreach my $attr (sort keys %{$attrnames}) {
	$out .= "\t& $attr";
    }
    return $out;
}

sub _print_attributes {
    my $self = shift;
    my $item = shift;
    my $fl = shift;
    my $any = 0;
    foreach my $var (keys %{$item->{attributes}}) {
	my $val = $item->{attributes}{$var};
	$fl->print("\\vregsAttributes{") if $any++==0;
	if ($val eq '1') {
	    $fl->print(" -$var");
	} else {
	    $fl->print(" -$var=$val");
	}
    }
    $fl->print("}\n") if $any;
}

sub _print_type {
    my $self = shift;
    my $typeref = shift;
    my $fl = shift;
    my $forreg = shift;

    if (!$forreg) {
	$fl->printf("\\vregsClass{%s", $typeref->{name});
	if ($typeref->{inherits}) {
	    $fl->print(":$typeref->{inherits}");
	}
	$fl->printf("}{%s}\n", $typeref->{name});
    }
    $self->_print_attributes($typeref, $fl);

    my $attrnames = {};
    foreach my $bitref ($typeref->fields_sorted()) {
	_attrnames_collect($attrnames, $bitref);
    }
    $fl->printf("\\vregsTable{l|l|l|l%s|l|X}\n",_attrnames_format($attrnames));
    $fl->printf_tabify("\\vregsTHead{Bit\t& Mnemonic\t& Access \t& %s\t& Type%s\t& Definition }\n",
		       (($typeref->{name} =~ /^R_/) ? "Reset":"Constant"),
		       _attrnames_head($attrnames));
    foreach my $bitref ($typeref->fields_sorted()) {
	my $descflags = "";
	$descflags = ".  Overlaps $bitref->{overlaps}." if $bitref->{overlaps};

	my $line = ("\\vregsTLine{".$bitref->{bits});
	$line .= ("\t& ".$bitref->{name});
	$line .= ("\t& ".$bitref->{access});
	$line .= ("\t& ".$bitref->{rst});
	$line .= ("\t& ".$bitref->{type});
	foreach my $attr (sort keys %{$attrnames}) {
	    $line .= ("\t& ".($bitref->{attributes}{$attr}||""));
	}
	$line .= ("\t& ".$bitref->{desc}.$descflags);
	$fl->printf_tabify("%s",$line." }\n");
    }
    $fl->printf("\\vregsTableEnd\n");

    $fl->print("\n");
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

    $fl->print("%% DESCR"."IPTION: Register Latex: Generated AUTOMATICALLY by vregs\n");
    $fl->print("%% Rebuild with: $pack->{rebuild_comment}\n") if $pack->{rebuild_comment};
    $fl->print("%%\n");
    $fl->print("\\usepackage{vregs}\n");
    $fl->print("\n");

    $fl->print("%%\n");
    $fl->printf("\\vregsPackage{%s}{Package}\n", $pack->{name});
    $self->_print_attributes($pack, $fl);
    $fl->print("\n");

    $fl->print("\n");
    $fl->print("%%",'*'x70,"\n%% Defines\n");
    $fl->printf("\\vregsDefines{}{}\n");
    my $attrnames;
    $attrnames = {};
    foreach my $fieldref ($pack->defines_sorted) {
	next if !$fieldref->{is_manual};
	_attrnames_collect($attrnames, $fieldref);
    }
    $fl->printf("\\vregsTable{l|l%s|X}\n",_attrnames_format($attrnames));
    $fl->printf_tabify("\\vregsTHead{Constant\t& Mnemonic%s\t& Definition }\n",
		       _attrnames_head($attrnames));
    foreach my $fieldref ($pack->defines_sorted) {
	next if !$fieldref->{is_manual};
	my $line = ("\\vregsTLine{".$fieldref->{rst});
	$line .= ("\t& ".$fieldref->{name});
	foreach my $attr (sort keys %{$attrnames}) {
	    $line .= ("\t& ".($fieldref->{attributes}{$attr}||""));
	}
	$line .=("\t& ".$fieldref->{desc});
	$fl->printf_tabify("%s",$line." }\n");
    }
    $fl->printf("\\vregsTableEnd\n");
    $fl->print("\n");

    $fl->print("%%",'*'x70,"\n%% Enumerations\n");
    foreach my $classref ($pack->enums_sorted) {
	my $classname = $classref->{name} || "x";
	$fl->printf("\\vregsEnum{%s}{%s}\n", $classname, $classname);
	$self->_print_attributes($classref, $fl);
	$attrnames = {};
	foreach my $fieldref ($classref->fields_sorted()) {
	    next if $fieldref->{omit_from_vregs_file};
	    _attrnames_collect($attrnames, $fieldref);
	}

	$fl->printf("\\begin{vregsTable}{l|l%s|X}\n",_attrnames_format($attrnames));
	$fl->printf_tabify("\\vregsTHead{Constant\t& Mnemonic%s\t& Definition }\n",
			   _attrnames_head($attrnames));
	foreach my $fieldref ($classref->fields_sorted()) {
	    next if $fieldref->{omit_from_vregs_file};
	    my $line = ("\\vregsTLine{".$fieldref->{rst});
	    $line .= ("\t& ". $fieldref->{name});
	    foreach my $attr (sort keys %{$attrnames}) {
		$line .= ("\t& ".($fieldref->{attributes}{$attr}||""));
	    }
	    $line .= ("\t& ".$fieldref->{desc});
	    $fl->printf_tabify("%s",$line." }\n");
	}
	$fl->printf("\\end{vregsTable}\n");
	$fl->print("\n");
    }

    my %printed;  # What register/class should print it
    foreach my $regref ($pack->regs_sorted) {
	my $typeref = $regref->{typeref};
	if (!$printed{$typeref}) {
	    $printed{$typeref} = $regref;
	}
    }

    $fl->print("%%",'*'x70,"\n%% Classes\n");
    foreach my $typeref ($pack->types_sorted) {
	if (!$printed{$typeref}) {
	    $printed{$typeref} = $typeref;
	    $self->_print_type ($typeref, $fl, undef);
	}
    }

    $fl->print("%%",'*'x70,"\n%% Registers\n");
    foreach my $regref ($pack->regs_sorted) {
	my $classname = $regref->{name} || "x";
	my $addr = $regref->{addr};
	my $range = $regref->{range} || "";
	if (!defined $addr) {
	    print "%Error: No address defined: ${classname}\n";
	} else {
	    (my $nor = $classname) =~ s/^R_//;
	    my $type = "Vregs${nor}";
	    $fl->printf("\\vregsRegister{%s}{%s}\n", $classname, $classname);
	    $self->_print_attributes($regref, $fl);
	    $fl->printf("\\vregsAddress{0x%s", $addr->to_Hex);
	    $fl->printf(" (Add 0x%s per entry)", $regref->{spacing}->to_Hex) if $regref->{spacing};
	    $fl->printf("}\n");

	    my $typeref = $regref->{typeref};
	    if (!$printed{$typeref} || $printed{$typeref}==$regref) {
		$printed{$typeref} = $regref;
		$self->_print_type ($typeref, $fl, $regref);
	    } else {
		$fl->print("\n");
	    }
	}
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

SystemC::Vregs::Output::Latex - Outputting .tex files

=head1 SYNOPSIS

SystemC::Vregs::Output::Latex->new->write(pack=>$VregsPackageObject, filename=>$fn);

=head1 DESCRIPTION

This package dumps registers in Latex table format, suitable for printing.
It is called by the Vregs package.

=head1 METHODS

=over 4

=item new()

Create and return a new output class.

=item write

Creates the latex file.

=back

=head1 DISTRIBUTION

Vregs is part of the L<http://www.veripool.com/> free Verilog software tool
suite.  The latest version is available from CPAN and from
L<http://www.veripool.com/vregs.html>.  /www.veripool.com/>.

Copyright 2001-2008 by Wilson Snyder.  This package is free software; you
can redistribute it and/or modify it under the terms of either the GNU
Lesser General Public License or the Perl Artistic License.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=head1 SEE ALSO

L<vreg>,
L<SystemC::Vregs>

=cut

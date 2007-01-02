# $Id: CBitFields.pm 29376 2007-01-02 14:50:38Z wsnyder $
# Author: Wilson Snyder <wsnyder@wsnyder.org>
######################################################################
#
# Copyright 2001-2007 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
######################################################################

package SystemC::Vregs::Output::CBitFields;
use SystemC::Vregs::Number;
use SystemC::Vregs::Language;
use Carp;
use strict;
use vars qw($VERSION);
use base qw(SystemC::Vregs::Output::Class);   # So we get enum_struct_write

$VERSION = '1.430';

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


sub _class_write {
    my $self = shift;
    my $typeref = shift;
    my $pack = shift;
    my $fl = shift;

    my $clname = $typeref->{name} || "x";

    $fl->print("typedef struct {\n");
    #use Data::Dumper; $fl->print(Dumper($typeref->{bitarray}));

    # What fields are non-contiguous?  We need to add _#'s to differentiate the parts.
    my %noncontig;
    my %width_by_lsb;
    my $lastbitref;
    my $fieldlsb = undef;
    for (my $bit=0; $bit<=$#{$typeref->{bitarray}}; $bit++) {
	my $bitref = $typeref->{bitarray}[$bit]{bitref};
	if ($bitref && (!$lastbitref || $bitref != $lastbitref)) {  # LSB of bitref
	    $fieldlsb = $bit;
	}
	if ($bitref && $lastbitref && $bitref != $lastbitref
	    && defined $noncontig{$bitref->{name}}) {
	    $noncontig{$bitref->{name}} = 1;  # 1=duplicate
	}
	if ($bitref) {
	    $noncontig{$bitref->{name}} ||= 0;  # 0=seen
	    $width_by_lsb{$fieldlsb}++;
	}
	$lastbitref = $bitref;
    }

    my $padbits = 0;
    my $padnum = 0;
    $lastbitref = undef;
    for (my $bit=0; $bit<=$#{$typeref->{bitarray}}; $bit++) {
	my $bitref = $typeref->{bitarray}[$bit]{bitref};
	if ($bitref) {
	    if ($padbits) {
		# Need to output padding before this field
		$fl->printf("    %s\t_pad_%d:%d;\n",
			    (($padbits > 32) ? "uint64_t" : "uint32_t"),
			    $padnum++, $padbits);
		$padbits = 0;
	    }
	    if ($bitref && $lastbitref && $bitref != $lastbitref
		&& $noncontig{$bitref->{name}}) {
		# Increment the suffix each time we hit a split in the non-contiguous field
		$noncontig{$bitref->{name}}++;
	    }

	    (my $lc_mnem = $bitref->{name}) =~ s/^(.)/lc $1/xe;
	    my $nc_suffix = "";
	    $nc_suffix = "_".$noncontig{$bitref->{name}} if $noncontig{$bitref->{name}};

	    $fl->printf("    %s\t%s:%d;\n",
			(($width_by_lsb{$bit} > 32) ? "uint64_t" : "uint32_t"),
			$lc_mnem.$nc_suffix, $width_by_lsb{$bit});
	    # Jump ahead a number of bits
	    $bit += $width_by_lsb{$bit} - 1;
	} else {
	    $padbits++;
	}
	$lastbitref = $bitref;
    }

    $fl->print("} $clname;\n");
    $fl->print("\n");
}

sub write {
    my $self = shift;
    my %params = (@_);
    my $pack = $params{pack} or croak "%Error: No pack=> parameter passed,";
    # Dump headers for class name based accessors

    my $fl = SystemC::Vregs::File->open(language=>'C',
					rules => $pack->{rules},
					%params);

    $fl->include_guard();
    $fl->print("\n");
    $fl->comment("package $pack->{name}\n");
    $fl->print("\n");

    $pack->{rules}->execute_rule ('defines_file_before', 'file_body', $pack);

    $fl->print("// Vregs library Files:\n");
    foreach my $packref (@{$pack->{libraries}}) {
	$fl->print("#include \"$packref->{name}_bitfields.h\"\n");
    }

    $fl->print("\n\n");

    foreach my $typeref ($pack->enums_sorted) {
	$self->enum_struct_write ($typeref, $pack, $fl);
    }

    $fl->print("\n\n");
    # Bitbashing done verbosely to avoid slow preprocess time
    # We could use bit structures, but they don't work on non-contiguous fields

    # Sorted first does base classes, then children
    foreach my $typeref ($pack->types_sorted) {
	$self->_class_write($typeref, $pack, $fl);
    }

    $pack->{rules}->execute_rule ('defines_file_after', 'file_body', $pack);

    $fl->close();
}

######################################################################
######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::Output::CBitFields - Outputting Vregs Code

=head1 SYNOPSIS

SystemC::Vregs::Output::CBitFields->new->write(pack=>$VregsPackageObject, filename=>$fn);

=head1 DESCRIPTION

This package dumps C structures with bit fields.  It is called by the Vregs
package.

Note that the order of packing bits into integers is compiler-specific and
thus unportable.  You are better off using the C++ classes.

=head1 METHODS

=over 4

=item new()

Create and return a new output class.

=item write

Creates a C header file with structs for class definitions.

=back

=head1 DISTRIBUTION

Vregs is part of the L<http://www.veripool.com/> free Verilog software tool
suite.  The latest version is available from CPAN and from
L<http://www.veripool.com/vregs.html>.  /www.veripool.com/>.

Copyright 2001-2007 by Wilson Snyder.  This package is free software; you
can redistribute it and/or modify it under the terms of either the GNU
Lesser General Public License or the Perl Artistic License.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=head1 SEE ALSO

L<vreg>,
L<SystemC::Vregs>

=cut

# $Id: Type.pm 35449 2007-04-06 13:21:40Z wsnyder $
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

package SystemC::Vregs::Type;
use SystemC::Vregs::Number;
use SystemC::Vregs::Bit;
use Bit::Vector::Overload;

use strict;
use vars qw ($VERSION);
use base qw (SystemC::Vregs::Subclass);
$VERSION = '1.440';

# Fields:
#	{name}			Field name (Subclass)
#	{nor_name}		Field name 
#	{at}			File/line number (Subclass)
#	{pack}			Parent SystemC::Vregs ref
#	{bits}			Width of structure
#	{words}			Width of structure
#	{inherits}		Text inherits description
#	{inherits_typeref}	Inherits SystemC::Vregs::Type
#	{inherits_level}	Depth of inheritance
#	{fields}{<fieldname>}	SystemC::Vregs::Bit

######################################################################
# Accessors

sub new {
    my $class = shift;  $class = ref $class if ref $class;
    my $self = $class->SUPER::new(bitarray=>[],
				  attributes=>{},
				  inherits_level=>0,
				  subclass_level=>0,
				  @_);
    $self->{pack} or die;  # Should have been passed as parameter
    $self->{pack}{types}{$self->{name}} = $self;
    return $self;
}

sub delete {
    my $self = shift;
    $self->{pack} or die;
    delete $self->{pack}{types}{$self->{name}};
}

sub inherits {
    my $self = shift;
    my $val = shift;
    if (defined ($val)) {
	$self->{inherits} = $val;
	($self->{inherits} =~ s/^\s*:\s*//);
	$self->{inherits_level} = 0;
	$self->{inherits_level}++ if $self->{inherits} ne "";
	$self->{inherits_level}++ while ($self->{inherits} =~ /:/g);
    }
    return $self->{inherits};
}

sub find_bit {
    my $self = shift;
    my $name = shift;
    return $self->{fields}{$name};
}

sub attribute_value {
    my $typeref = shift;
    my $attr = shift;
    return $typeref->{attributes}{$attr} if defined $typeref->{attributes}{$attr};
    return $typeref->{inherits_typeref}{attributes}{$attr}
        if (defined $typeref->{inherits_typeref}
	    && defined $typeref->{inherits_typeref}{attributes}{$attr});
    return $typeref->{pack}{attributes}{$attr} if defined $typeref->{pack}{attributes}{$attr};
    return undef;
}

sub numbytes {
    my $self = shift;
    return int(($self->{numbits}+7)/8);
}

######################################################################

sub dewildcard {
    my $self = shift;

    # Expand any bit wildcards
    foreach my $fieldref (values %{$self->{fields}}) {
	$fieldref->dewildcard;
    }

    # Expand type wildcards
    #print ::Dumper($self);
    return if (($self->{name}||"") !~ /\*/);
    print "Type Wildcard ",$self->inherits(),"\n" if $SystemC::Vregs::Debug;
    (my $regexp = $self->inherits()) =~ s/[*]/\.\*/g;
    my $gotone;
    foreach my $matchref ($self->{pack}->find_type_regexp("^$regexp")) {
	$gotone = 1;
	my $newname = SystemC::Vregs::three_way_replace
	    ($self->{name}, $self->inherits(), $matchref->{name});
	print "  Wildcarded $matchref->{name} to $newname\n"  if $SystemC::Vregs::Debug;
	my $newref = $self->new (pack=>$self->{pack},
				 name=>$newname,
				 at => $matchref->{at},
				 );
	foreach my $key (keys %{$self->{attributes}}) {
	    $newref->{attributes}{$key} = $self->{attributes}{$key};
	}
	$newref->inherits($matchref->{name});
    }
    $gotone or $self->warn ("No types matching wildcarded type: ",$self->inherits(),"\n");
    $self->delete();
}

######################################################################

sub check_name {
    my $self = shift;
    my $field = $self->{name};
    ($field =~ /^[A-Z][a-zA-Z0-9_]*$/)
	or $self->warn ("Type names must match [capitals][alphanumerics]: $field\n");
    ($self->{nor_name} = $field);
}

sub check_inherit {
    my $typeref = shift;
    my $inh = $typeref->inherits();
    return if !$inh;
    my $ityperef = $typeref->{pack}->find_type($inh);
    $typeref->{inherits_typeref} = $ityperef;
    if (!$ityperef) {
	return $typeref->warn ("Cannot find subclass definition: $inh\n");
    }

    #print "INH $typeref->{name} $inh;\n";
    for (my $bit=0; $bit<=$#{$typeref->{bitarray}}; $bit++) {
	if (my $bitref = $typeref->{bitarray}[$bit]{bitref}) {
	    if (my $ibitref = $ityperef->{bitarray}[$bit]{bitref}) {
		my $iname = $ityperef->{name} . "::" . $ibitref->{name};
		#print "  ib$bit $bitref->{name}  $iname  $ibitref->{overlaps}\n";
		if ($bitref->{name} eq $ibitref->{name}) {
		    if ($bitref->{bits} ne $ibitref->{bits}) {
			$bitref->warn("Bits $bitref->{bits} don't match $ibitref->{bits} inherited from $iname\n");
			next;
		    }
		} else {
		    if (!$bitref->is_overlap_ok($ibitref)) {
			$bitref->warn("Bit $bit overlaps inherited $iname\n"
				      ."Perhaps you need a 'Overlaps $ibitref->{name}.' in $bitref->{name}'s description\n");
		    }
		}
	    }
	}
    }
}

sub check {
    my $self = shift;
    #print ::Dumper($self);
    $self->check_name();
    foreach my $fieldref (values %{$self->{fields}}) {
	$fieldref->check();
    }
    $self->check_inherit();
    foreach my $fieldref ($self->fields_sorted_inherited) {
	$fieldref->computes_type($self);
    }
    $self->computes();
}

sub remove_if_mismatch {
    my $self = shift;
    my $rm=0;  my $cnt=0;
    foreach my $fieldref (values %{$self->{fields}}) {
	$rm++ if $fieldref->remove_if_mismatch();
	$cnt++;
    }
    if ($self->{pack}->is_mismatch($self) || ($rm && $rm == $cnt)) {
	$self->delete;
    }
}

sub computes {
    my $typeref = shift;
    # Create vector describing bit layout of the word
    $typeref->_computes_words();
    $typeref->_computes_inh_level_recurse(0);
    #
    my $mnem_vec = "";
    my $last_bitref = 0;
    my $x = 0;
    for (my $bit=($typeref->{words}*$typeref->{pack}{data_bits})-1; $bit>=0; $bit--) {
	my $bitent = $typeref->{bitarray}[$bit];
	if (!defined $bitent) {
	    $x++;
	} else {
	    my $bitref = $bitent->{bitref};
	    next if !$bitref;
	    my $bits = $bitref->{bits};
	    my $bit_mnem = $bitref->{name};
	    $bits =~ s/^w0//;
	    if ($last_bitref != $bitref) {
		$mnem_vec .= sprintf "X[%d], ", $bit+1 if $x==1;
		$mnem_vec .= sprintf "X[%d:%d], ", $bit+$x, $bit+1 if $x>1;
		$x = 0;
		$mnem_vec .= $bit_mnem . (($bits eq "") ? ", " : "$bits, ");
	    }
	    $last_bitref = $bitref;
	}
    }
    my $bit=-1;
    $mnem_vec .= sprintf "X[%d], ", $bit+1 if $x==1;
    $mnem_vec .= sprintf "X[%d:%d], ", $bit+$x, $bit+1 if $x>1;
    $mnem_vec =~ s/, $//;
    $typeref->{mnem_vec} = $mnem_vec;
}

sub _computes_words {
    my $self = shift;

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
    if (my $numbits = $self->attribute_value('numbits')) {
	$self->{words}   = int(($numbits+31)/32);
	$self->{words}   = 1 if $self->{words}<1;
	$self->{numbits} = $numbits;
    } else {  # Make a guess based on the fields used.
	$self->{words} = $words;
	$self->{numbits} = $words*32;
    }
}

sub _computes_inh_level_recurse {
    my $self = shift;
    my $level = shift;
    if ($self->{subclass_level} > $level) {
	$level = $self->{subclass_level};
    }
    $self->{subclass_level} = $level;
    # If a class is a baseclass of this class, the baseclass needs bigger level.
    if (my $ityperef = $self->{inherits_typeref}) {
	$ityperef->_computes_inh_level_recurse($level+1);
    }
    # If a class is used as a field in this class, the used class needs bigger level.
    foreach my $fieldref ($self->fields) {
	my $ityperef = $fieldref->{pack}->find_type($fieldref->{type});
	if ($ityperef) {
	    $ityperef->_computes_inh_level_recurse($level+1);
	}
    }
    #print STDERR "LEVEL $self->{name} $level;\n";
}

######################################################################

sub fields {
    my $typeref = shift;
    return (values %{$typeref->{fields}});
}

sub fields_sorted {
    my $typeref = shift;
    return (sort {$b->{bitlist}[0] <=> $a->{bitlist}[0]
		  || $a->{name} cmp $b->{name}}
	    (values %{$typeref->{fields}}));
}

sub fields_sorted_inherited {
    my $typeref = shift;
    my @flds = (values %{$typeref->{fields}});
    if ($typeref->{inherits_typeref}) {
	foreach my $fld (values %{$typeref->{inherits_typeref}->{fields}}) {
	    next if $typeref->{fields}{$fld->{name}};  # Inherited, but redefined in class.
	    push @flds, $fld;
	}
    }
    return (sort {$b->{bitlist}[0] <=> $a->{bitlist}[0]
		      || $a->{name} cmp $b->{name}}
	    @flds);
}

sub dump {
    my $self = shift;
    my $fh = shift || \*STDOUT;
    my $indent = shift||"  ";
    print $fh +($indent,"Type: ",$self->{name},
		"  bits:",$self->{bits}||'',
		"\n");
    foreach my $fieldref (values %{$self->{fields}}) {
	$fieldref->dump($fh,$indent."  ");
    }
}

######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::Type - Type object

=head1 SYNOPSIS

    use SystemC::Vregs;

=head1 DESCRIPTION

This package contains a blessed hash object for each class and register
definition.

=head1 FIELDS

These fields may be specified with the new() function, and accessed
via the self hash: $self->{field}.

=over 4

=item inherits

String with whatever base classes this class should inherit from.

=item fields

Hash with references to SystemC::Vregs::Bit objects, for the fields inside
this class.

=item name

Name of the object.

=item pack

Reference to the package (SystemC::Vregs) object self is a member of.

=back

=head1 DERIVED FIELDS

These fields are valid only after check() is called.

=over 4

=item inherits_typeref

Reference to a SystemC::Vregs::Type object for the base class of this
object (if any.)

=back

=head1 METHODS

=over 4

=item new

Creates a new type object.

=item check

Checks the object for errors, and parses to create derived fields.

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

L<SystemC::Vregs>

=cut

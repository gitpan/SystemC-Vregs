# $Id: Type.pm,v 1.6 2001/10/18 12:46:49 wsnyder Exp $
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

package SystemC::Vregs::Type;
use SystemC::Vregs::Number;
use SystemC::Vregs::Bit;
use Bit::Vector::Overload;

use strict;
use vars qw (@ISA $VERSION);
@ISA = qw (SystemC::Vregs::Subclass);
$VERSION = '1.100';

######################################################################
# Accessors

sub new {
    my $class = shift;  $class = ref $class if ref $class;
    my $self = $class->SUPER::new(bitarray=>[],
				  attributes=>{},
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

######################################################################

sub dewildcard {
    my $self = shift;
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
	$newref->inherits($matchref->{name});
    }
    $gotone or $self->warn ("No types matching wildcarded type: ",$self->inherits(),"\n");
    $self->delete();
}

######################################################################

sub check_name {
    my $self = shift;
    my $field = $self->{name};
    ($field =~ /^[A-Z][a-zA-Z0-9_]+$/)
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

sub computes {
    my $typeref = shift;
    # Create vector describing bit layout of the word
    my $mnem_vec = "";
    my $last_bitref = 0;
    my $x = 0;
    for (my $bit=$typeref->{pack}{data_bits}-1; $bit>=0; $bit--) {
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

    $typeref->_computes_words();
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
    $self->{words} = $words;
}

sub fields_sorted {
    my $typeref = shift;
    return (sort {$b->{bitlist}[0] <=> $a->{bitlist}[0]}
	    (values %{$typeref->{fields}}));
}

sub fields_sorted_inherited {
    my $typeref = shift;
    my @flds = (values %{$typeref->{fields}});
    if ($typeref->{inherits_typeref}) {
	push @flds, (values %{$typeref->{inherits_typeref}->{fields}});
    }
    return (sort {$b->{bitlist}[0] <=> $a->{bitlist}[0]}
	    @flds);
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

=item FIELDS

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

=item DERRIVED FIELDS

These fields are valid only after check() is called.

=over 4

=item inherits_typeref

Reference to a SystemC::Vregs::Type object for the base class of this
object (if any.)

=back

=item METHODS

=over 4

=item new

Creates a new type object.

=item check

Checks the object for errors, and parses to create derrived fields.

=back

=head1 SEE ALSO

C<SystemC::Vregs>

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=cut

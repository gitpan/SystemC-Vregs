# $Id: Enum.pm,v 1.11 2002/03/11 15:53:29 wsnyder Exp $
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

package SystemC::Vregs::Enum;
use SystemC::Vregs::Number;
use SystemC::Vregs::Subclass;
use Verilog::Language;	# For value parsing

use strict;
use vars qw (@ISA $VERSION);
@ISA = qw (SystemC::Vregs::Subclass);
$VERSION = '1.210';

######################################################################
######################################################################
######################################################################
######################################################################
#### SystemC::Vregs::Enum

package SystemC::Vregs::Enum;
use strict;

#Fields: name, at, pack, fields

sub new {
    my $class = shift;
    my $self = {@_};
    bless $self, $class;
    $self->{pack} or die;  # Should have been passed as parameter
    $self->{pack}{enums}{$self->{name}} = $self;
    return $self;
}

sub find_value {
    my $self = shift;
    my $name = shift;
    return $self->{fields}{$name};
}

sub check_name {
    my $self = shift;
    my $field = $self->{name};
    if ($field !~ /^[A-Z][a-zA-Z0-9_]+$/) {
	$self->warn ("Enum names must match [capitals][alphanumerics]'\n: $field");
	return;
    }
    if (my $lang = SystemC::Vregs::Language::is_keyword(lc $field)) {
	$self->warn ("Name matches a $lang language keyword: ", lc $field, "\n");
    }
}

sub check {
    my $self = shift;
    #print ::Dumper($enumref);
    $self->check_name();
    foreach my $fieldref (values %{$self->{fields}}) {
	$fieldref->check();
    }
}

sub fields_sorted {
    my $typeref = shift;
    return (sort {$a->{rst_val} <=> $b->{rst_val}}
	    (values %{$typeref->{fields}}));
}

######################################################################
######################################################################
######################################################################
######################################################################
#### SystemC::Vregs::Enum::Value

package SystemC::Vregs::Enum::Value;
use strict;
use vars qw (@ISA);
@ISA = qw (SystemC::Vregs::Subclass);

# Fields: 	name, at, class

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{class} or die;  # Should have been passed as parameter
    $self->{class}{fields}{$self->{name}} = $self;
    return $self;
}

sub clean_desc {
    my $self = shift;
    $self->{desc} = $self->clean_sentence($self->{desc});
}

sub clean_rst {
    my $self = shift;
    my $field = $self->{rst};

    my $bits = Verilog::Language::number_bits ($field);
    if (!$bits) { return $self->warn ("Number of bits in constant not specified: $field\n"); }
    $self->{bits} = $bits;
    my $val = Verilog::Language::number_value ($field);
    if (!defined $val) { return $self->warn ("Value of constant unparsable: $field\n"); }
    $self->{rst_val} = $val;

    if (defined $self->{class}{bits}
	&& ($self->{class}{bits} != $bits)) {
	return $self->warn ("Enum value doesn't match register width: $field != "
			    .$self->{class}{bits}."\n");
    }
    $self->{class}{bits} = $bits;
}

sub check_name {
    my $self = shift;
    my $field = $self->{name};
    my $class = $self->{class};
    if ($field !~ /^[A-Z][A-Z0-9_]+$/) {
	return $self->warn ("Enum field names must match [capital][capitalnumerics_]: $field'\n");
    }
    #my $prefix = $1;
    #if (defined $class->{value_prefix}
    #	 && ($class->{value_prefix} ne $prefix)) {
    #	 return $self->warn ("Enum field name $field doesn't have class specific prefix: "
    #			     .$class->{value_prefix}."\n");
    #}
    #$class->{value_prefix} = $prefix;
}

sub check {
    my $self = shift;
    $self->clean_desc();
    $self->clean_rst();
    $self->check_name();
}

######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::Enum - Definition object

=head1 SYNOPSIS

    use SystemC::Vregs;

=head1 DESCRIPTION

This package contains a blessed hash object for each enumeration.

=item FIELDS

These fields may be specified with the new() function, and accessed
via the self hash: $self->{field}.

=over 4

=item bits

Number of bits wide the enumeration values are.

=item desc

Description comment for the object.

=item name

Name of the object.

=item pack

Reference to the package (SystemC::Vregs) object self is a member of.

=item fields

Hash containing SystemC::Vregs::Enum::Value objects.  Each value object
contains a name, desc, and rst field, just like the SystemC::Vregs::Define
objects.

=back

=item METHODS

=over 4

=item new

Creates a new enumeration object.

=item check

Checks the object for errors, and parses to create derrived Fields.

=back

=head1 SEE ALSO

C<SystemC::Vregs>

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=cut

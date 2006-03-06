# $Id: Define.pm 15061 2006-03-01 19:51:13Z wsnyder $
# Author: Wilson Snyder <wsnyder@wsnyder.org>
######################################################################
#
# Copyright 2001-2006 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
######################################################################

package SystemC::Vregs::Define;
use SystemC::Vregs::Number;
use SystemC::Vregs::Subclass;
use Verilog::Language;	# For value parsing

use strict;
use vars qw ($VERSION);
use base qw (SystemC::Vregs::Subclass);
$VERSION = '1.400';

#Fields:
#	{name}			Field name (Subclass)
#	{at}			File/line number (Subclass)
#	{pack}			Parent SystemC::Vregs ref
#	{class}			Parent SystemC::Vregs::Type ref
#	{bits}			Width or undef for unsized
#	{desc}			Description
#	{rst}			Reset value or 'X'
#	{rst_val}		{rst} as a hex value	
#	{sort_key}		Order to output into file
#	{is_manual}		Created by user (vs from program)

######################################################################
######################################################################
######################################################################
######################################################################
#### SystemC::Vregs::Define::Value

package SystemC::Vregs::Define::Value;
use strict;
use base qw (SystemC::Vregs::Subclass);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{pack} or die;  # Should have been passed as parameter
    $self->{pack}{defines}{$self->{name}} = $self;
    $self->{sort_key} ||= '000000_' . $self->{name};
    return $self;
}

use vars qw($_Defines_New_Push_Val);
sub new_push {
    my $class = shift;
    # Like new, but add automatic to bottom of existing definitions
    my $self = $class->new(@_);
    $_Defines_New_Push_Val = ($_Defines_New_Push_Val||0) + 1;
    $self->{sort_key} = sprintf("%06d_%s",$_Defines_New_Push_Val,$self->{name});
    return $self;
}

sub clean_desc {
    my $self = shift;
    $self->{desc} = $self->clean_sentence($self->{desc});
    ($self->{desc}) or $self->warn("Empty description, please document it.\n");
}

sub clean_rst {
    my $self = shift;
    my $field = $self->{rst};

    my $bits = Verilog::Language::number_bits ($field);
    if (!$bits) { return $self->warn ("Number of bits in constant not specified: $field\n"); }
    $self->{bits} = $bits;
    if ($field =~ /\'s?h([0-9a-f_]+)$/i) {
	# Prevent overflowing 32 bits by keeping the number in hex form
	my $valhex = lc $1;
	$valhex =~ s/_//g;
	$self->{rst_val} = $valhex;
    } else {
	my $val = Verilog::Language::number_value ($field);
	if (!defined $val) { return $self->warn ("Value of constant unparsable: $field\n"); }
	$self->{rst_val} = sprintf("%x",$val);
    }

    # Note Enum and Bit rst_vals are decimal, Define rst_vals are hex.  Yuk.

    if (defined $self->{class}{bits}
	&& ($self->{class}{bits} != $bits)) {
	return $self->warn ("Define value doesn't match register width: $field != "
			    .$self->{class}{bits}."\n");
    }
    $self->{class}{bits} = $bits;

    if ($bits && $bits<32 && hex($self->{rst_val}||"0")>= (1<<$bits)) {
	$self->warn ("Define value wider then width: ".$self->{rst}." > width "
		     .$self->{class}{bits}."\n");
    }
}

sub check_name {
    my $self = shift;
    my $field = $self->{name};
    if ($self->{is_manual}
	&& $field !~ /^[A-Z][A-Z0-9_]*$/) {
	return $self->warn ("Define field names must match [capital][capitalnumerics_]: $field\n");
    }
}

sub check {
    my $self = shift;
    $self->clean_desc();
    $self->clean_rst();
    $self->check_name();
}

sub dump {
    my $self = shift;
    my $fh = shift || \*STDOUT;
    my $indent = shift||"  ";
    print $fh +($indent,"Def: ",$self->{name},
		"  width:",$self->{bits}||'',
		"  rst:",$self->{rst}||'', 
		"  rst_val:",$self->{rst_val}||'',
		"\n");
}

######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::Define - Definition object

=head1 SYNOPSIS

    use SystemC::Vregs;

=head1 DESCRIPTION

This package contains a blessed hash object for each definition.

=head1 FIELDS

These fields may be specified with the new() function, and accessed
via the self hash: $self->{field}.

=over 4

=item bits

Number of bits in the define.  If not specified, it is assumed to be a
unsized object that is less then 32 bits.

=item desc

Description comment for the object.

=item name

Name of the object.

=item pack

Reference to the package (SystemC::Vregs) object self is a member of.

=item rst

Reset value for the object.

=back

=head1 DERIVED FIELDS

These fields are valid only after check() is called.

=over 4

=item rst_val

The reset value, expressed as a hex string.

=back

=head1 METHODS

=over 4

=item new

Creates a new definition object.

=item new_push

Creates a new definition object, at the head of the list of definitions.

=item check

Checks the object for errors, and parses to create derived Fields.

=back

=head1 DISTRIBUTION

The latest version is available from CPAN and from L<http://www.veripool.com/>.

Copyright 2001-2006 by Wilson Snyder.  This package is free software; you
can redistribute it and/or modify it under the terms of either the GNU
Lesser General Public License or the Perl Artistic License.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=head1 SEE ALSO

L<SystemC::Vregs>

=cut

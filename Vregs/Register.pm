# $Id: Register.pm,v 1.22 2001/06/27 16:10:22 wsnyder Exp $
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

package SystemC::Vregs::Register;
use SystemC::Vregs::Number;
use SystemC::Vregs::Type;
use Bit::Vector::Overload;

use strict;
use vars qw (@ISA $VERSION);
@ISA = qw (SystemC::Vregs::Subclass);
$VERSION = '0.1';

# mnem
# addr

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{pack} or die;  # Should have been passed as parameter
    $self->{pack}{regs}{$self->{name}} = $self;
    return $self;
}

sub check_name {
    my $regref = shift;
    my $field = $regref->{name};
    ($field =~ /^R_[A-Z][a-zA-Z0-9]+$/)
	or $regref->warn ("Register mnemonics must match R_[capitals][alphanumerics]'\n");
    ($field =~ /cnfg[0-9]+$/i) and $regref->warn ("Abbreviate CNFG (Configuration) as Cfg\n");  #Dan Lussier'ism
    ($regref->{nor_name} = $field) =~ s/^[RC]_//;
}

sub check_addrtext {
    my $regref = shift;
    my $addrtext = $regref->{addrtext};

    my $endtext = "";
    if ($addrtext =~ s/^(0x[0-9a-f_]+)\s*-\s*(0x[0-9a-f_]+)$/$1/i) {
	$endtext = $2;
	$regref->{addr_end} = $regref->{pack}->addr_text_to_vec($endtext);
    }

    ($addrtext =~ /^0x[0-9a-f_]+$/i)
	or $regref->warn ("Strange address format '$addrtext'\n");

    $regref->{addr} = $regref->{pack}->addr_text_to_vec($addrtext);
}

sub check_range_spacing {
    my $regref = shift;

    my $range = $regref->{range};
    if (!defined $regref->{spacing}) {
	$regref->{spacing} = $regref->{pack}->addr_text_to_vec($regref->{spacingtext});
	(defined $regref->{spacing}) or $regref->warn ("Strange spacing value $regref->{spacingtext}\n");
    }

    my $spacing = $regref->{spacing};
    if ($range) {
	$range =~ /^\[([^\]:]+):([^\]:]+)\]$/
	    or $regref->warn ("Strange range $range\n");
	my $htext = $1;  my $ltext = $2;
	$regref->{range_high} = $regref->{pack}->addr_text_to_vec($htext);
	$regref->{range_low}  = $regref->{pack}->addr_text_to_vec($ltext);
	(defined $regref->{range_high}) or $regref->warn ("Can't parse $htext in range $range\n");
	(defined $regref->{range_low}) or $regref->warn ("Can't parse $htext in range $range\n");
	($spacing->Lexicompare($regref->{pack}->addr_const_vec(4)) >= 0)
	    or $regref->warn ("Strange address spacing $spacing\n");
    }
    else { # No range
	($spacing->equal($regref->{pack}->addr_const_vec(0)))
	    or $regref->warn ("Address spacing set to $spacing, but no range specified\n");
	$regref->{range_low}  
	= $regref->{range_high}
	= $regref->{pack}->addr_const_vec(0);
    }
    $regref->{range_ents} = $regref->{pack}->addr_const_vec(1);
    $regref->{range_ents}->add( $regref->{range_high}, $regref->{range_ents}, 0);
    $regref->{range_ents}->subtract ($regref->{range_ents}, $regref->{range_low}, 0);
    $regref->{range_high_p1} = $regref->{pack}->addr_const_vec(1);
    $regref->{range_high_p1}->add( $regref->{range_high_p1}, $regref->{range_high}, 0);
}

sub check {
    my $regref = shift;
    #print ::Dumper($regref);
    $regref->check_name();
    $regref->check_addrtext();
    $regref->check_range_spacing();
    # Computes after all checks
    $regref->computes();
}

sub computes {
    my $regref = shift;
    # Computes rely on check() being correct
    if (!defined $regref->{addr_end}) {
	# addr_end = addr + 4 + ((spacing * (ents - 1)))
	my $inc = $regref->{pack}->addr_const_vec(1);
        $inc->subtract($regref->{range_ents}, $inc, 0);
	$inc->Multiply($regref->{spacing}, $inc);
	$inc->add($inc, $regref->{pack}->addr_const_vec(4), 0);
	$inc->add($regref->{addr}, $inc, 0);
	$regref->{addr_end} = $inc;
    }
}

######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::Register - Register object

=head1 SYNOPSIS

    use SystemC::Vregs;

=head1 DESCRIPTION

This package contains a blessed hash object for each register
definition.

=item FIELDS

These fields may be specified with the new() function, and accessed
via the self hash: $self->{field}.

=over 4

=item addrtext

Textual form of the address of the register.

=item spacing

Spacing of each register in a range, normally 4 bytes.

=item range

Entry range a ram covers, for example [7:0].

=item name

Name of the object.

=item pack

Reference to the package (SystemC::Vregs) object self is a member of.

=back

=item DERRIVED FIELDS

These fields are valid only after check() is called.

=over 4

=item addr

Address of the register.

=item addr_end

Ending address of the register.

=back

=item METHODS

=over 4

=item new

Creates a new register object.

=item check

Checks the object for errors, and parses to create derrived fields.

=back

=head1 SEE ALSO

C<SystemC::Vregs>

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=cut

# $Id: Number.pm,v 1.8 2002/03/11 15:53:29 wsnyder Exp $
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

package SystemC::Vregs::Number;
use strict;
use Carp;
use vars qw($VERSION @ISA);

use Bit::Vector;

@ISA = qw (Bit::Vector);	# For now, let Bit::Vector do all the work
$VERSION = '1.210';

######################################################################
######################################################################
######################################################################
######################################################################
#### Creators

sub min {
    my $veca = shift;
    my $vecb = shift;
    return $veca if !defined $vecb;
    return $vecb if !defined $veca;
    if ($veca->Lexicompare($vecb) < 0) {return $veca;}
    else {return $vecb;}
}
sub max {
    my $veca = shift;
    my $vecb = shift;
    return $veca if !defined $vecb;
    return $vecb if !defined $veca;
    if ($veca->Lexicompare($vecb) > 0) {return $veca;}
    else {return $vecb;}
}

sub text_to_vec {
    my $default_width = shift;	# Width if not specified, undef=must be sized
    my $text = shift;
    # Return bitvector structure, or undef if it isn't a nicely formed number
    # We allow C format  (10, 0x10, 0x10_11)
    # And Verilog format (32'd20, 32'h2f, 32'b1011)
    $text =~ s/_//g;
    $text =~ s/\s+$//;
    my $width = $default_width;
    if ($text =~ s/^(\d+)\'/\'/) {
	$width = $1;
    }
    if ($text =~ /^(\'d|)(\d+)$/i) {
	return undef if !$width;
	return SystemC::Vregs::Number->new_Dec($width, $2);
    }
    elsif ($text =~ /^(0x|\'[hx])([a-z0-9]+)$/i) {
	return undef if !$width;
	return SystemC::Vregs::Number->new_Hex($width, $2);
    }
    elsif ($text =~ /^\'b([0-1]+)$/i) {
	return undef if !$width;
	return SystemC::Vregs::Number->new_Bin($width, $1);
    }

    return undef;
}

######################################################################
#### Accessors

######################################################################
#### Package return
1;
__END__

=pod

=head1 NAME

SystemC::Vregs::Number - Number parsing used by Vregs

=head1 SYNOPSIS

  use SystemC::Vregs::Number;

=head1 DESCRIPTION

This package is used to extract numbers in C++ or Verilog format into a
Bit::Vector.

=head1 SEE ALSO

C<SystemC::Vregs>

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=cut

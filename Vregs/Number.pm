# See copyright, etc in below POD section.
######################################################################

package SystemC::Vregs::Number;
use strict;
use Carp;
use vars qw($VERSION);
use base qw(Bit::Vector);	# For now, let Bit::Vector do all the work

$VERSION = '1.470';

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

L<SystemC::Vregs>

=cut

# $Id: Subclass.pm,v 1.11 2002/03/11 15:53:29 wsnyder Exp $
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

package SystemC::Vregs::Subclass;

use strict;
use vars qw($Errors $VERSION);
use Carp;
$VERSION = '1.210';

$Errors = 0;

sub new {
    my $class = shift;
    my $self = {@_};
    defined $self->{name} or croak ("No name=> parameter passed");
    bless $self, $class;
    return $self;
}

sub warn {
    my $self = shift;
    if (ref $_[0]) { $self = shift; }   # Use the class provided, if passed

    my $at = "";
    if ($self) {
	my $typeref = $self->{class} || $self->{typeref};
	if ($typeref) {
	    $at = ($typeref->{name}||$typeref->{Register}||$typeref->{at}||"");
	    $at .= "::";
	}
	$at .= ($self->{name}||$self->{Register}||$self->{Mnemonic}||$self->{at}||"");
	$at .= ": ";
    }

    $at .= ($self->{at}||"").":" if $SystemC::Vregs::Debug;

    # Make a warning based on the bit being processed
    my $atblank = " " x length($at);
    my $text = join('',@_);
    $text =~ s/\n(.)/\n%Warning: $atblank$1/g;
    CORE::warn "%Warning: $at$text";
    $Errors++;
}

sub exit_if_error {
    exit(10) if $Errors;
}

sub clean_sentence {
    my $self = shift;
    my $field = shift;

    # Make it reasonably small, or the first sentence
    $field =~ s/^\s+//g;
    $field =~ s/\s*\bthis bit\b//g;
    $field =~ s/\"/ /g;
    $field =~ s/\s+/ /g;
    $field = substr $field,0,80;
    if ($field =~ /[.,;]/) {
	$field =~ s/\..*$//;
    }
    $field = ucfirst $field;
    $field =~ s/\s+$//;

    return ($field);
}

END {
    $? = 10 if $Errors;
    CORE::warn "Exiting due to errors\n" if $?;
}

sub check {}

######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::Subclass - Common base class

=head1 SYNOPSIS

    use SystemC::Vregs;

=item METHODS

=over 4

=item new

Creates a new blessed object.

=item warn

Prints a warning message, using the name field if it exists.  Errors
are held until exit_if_error is called.

=item exit_if_error

Exits if any warnings have been found.

=item clean_sentence.

Finds the first sentence in a paragraph.  Used to extract description
lines from the description columns.

=back

=head1 SEE ALSO

C<SystemC::Vregs>

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=cut

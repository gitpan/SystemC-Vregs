# $Id: Subclass.pm 15061 2006-03-01 19:51:13Z wsnyder $
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

package SystemC::Vregs::Subclass;

use strict;
use vars qw($Errors $VERSION);
use Carp;
$VERSION = '1.400';

$Errors = 0;

sub new {
    my $class = shift;
    my $self = {@_};
    defined $self->{name} or croak ("No name=> parameter passed");
    bless $self, $class;
    return $self;
}

sub at_text {
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
	# If the name has non-printing or strange chars, quote it and show them.
	if ($at !~ /^[\w\-\:]+$/) {
	    $at =~ s/(.)/substchar($1)/egs;
	    $at = "'". $at ."'";
	}
	$at .= ": ";
    }

    $at .= ($self->{at}||"").":" if $SystemC::Vregs::Debug;
    return $at;
}

sub substchar {
    my $c = shift; 
    my $n = ord $c;
    if ($n >= 33 && $n <= 126) {
	return "\\\'" if ($c eq "'");
	return "\\\\" if ($c eq "\\");
	return $c;
    }
    return sprintf("\\x%02x", $n);
}

sub info {
    my $self = shift;
    if (ref $_[0]) { $self = shift; }   # Use the class provided, if passed

    # Make a warning based on the bit being processed
    my $at = at_text($self);
    my $atblank = " " x length($at);
    my $text = join('',@_);
    $text =~ s/\n(.)/\n-Info: $atblank$1/g;
    CORE::warn "-Info: $at$text";
}

sub warn {
    my $self = shift;
    if (ref $_[0]) { $self = shift; }   # Use the class provided, if passed

    # Make a warning based on the bit being processed
    my $at = at_text($self);
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
    $field =~ s/[\"\'\`]+/ /g;
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

=head1 METHODS

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

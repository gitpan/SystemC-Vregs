# See copyright, etc in below POD section.
######################################################################

package SystemC::Vregs::Subclass;

use strict;use vars qw($Errors $VERSION);
use Carp;
$VERSION = '1.470';

$Errors = 0;

sub new {
    my $class = shift;
    my $self = {@_};
    defined $self->{name} or croak ("No name=> parameter passed");
    bless $self, $class;
    return $self;
}

sub attributes_parse {
    my $self = shift;
    my $flags = shift;

    $flags = " $flags ";
    $self->{attributes}{$1} = $2 while ($flags =~ s/\s-([a-zA-Z][a-zA-Z0-9_]*)=([^ \t]*)\s/ /);
    $self->{attributes}{$1} = 1  while ($flags =~ s/\s-([a-zA-Z][a-zA-Z0-9_]*)\s/ /);
    ($flags =~ /^\s*$/) or $self->warn ("Unparsable attributes setting: '$flags'");
}

sub attributes_string {
    my $self = shift;
    my $text = "";
    foreach my $var (sort keys %{$self->{attributes}}) {
	my $val = $self->{attributes}{$var};
	$text .= " " if $text ne "";
	if ($val eq '1') {
	    $text .= "-$var";
	} else {
	    $text .= "-$var=$val";
	}
    }
    return $text;
}
sub copy_attributes_from {
    my $self = shift;
    my $from = shift or return;

    foreach my $key (keys %{$from->{attributes}}) {
	if (!defined $self->{attributes}{$key}) {
	    $self->{attributes}{$key} = $from->{attributes}{$key}
	}
    }
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
    my $out = $field;
    $out =~ s/^\s+//g;
    $out =~ s/\s*\bthis bit\b//g;
    $out =~ s/[\"\'\`]+/ /g;
    $out =~ s/\s+/ /g;
    $out = substr $out,0,80;
    if ($out =~ /[.,;]/) {
	$out =~ s/\..*$//;
    }
    $out = ucfirst $out;
    $out =~ s/\s+$//;

    return $out;
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

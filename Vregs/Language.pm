# $Revision: #33 $$Date: 2003/06/09 $$Author: wsnyder $
# Author: Wilson Snyder <wsnyder@wsnyder.org>
######################################################################
#
# This program is Copyright 2001 by Wilson Snyder.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of either the GNU General Public License or the
# Perl Artistic License.
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

package SystemC::Vregs::Language;

use strict;
use vars qw(@ISA $VERSION);
use Carp;
use IO::File;
$VERSION = '1.241';

######################################################################
#### Implementation

######################################################################
#### Creation

sub new {
    my $class = shift;
    my $self = {text=>[],
		close_text=>[],
		@_};
    
    $self->{filename} or croak "%Error: ->new() requires filename=> argument, stopped";
    $self->{modulename} = $self->{filename};
    $self->{modulename} =~ s/.*[\/\\]//;
    $self->{modulename} =~ s/[^a-zA-Z0-9]/_/g;

    my $bless_class = $class;
    if ($self->{language}) {
	# Have language=>C use the class SystemC::Vregs::Language::C
	$bless_class .= "::" . $self->{language};
	my $package_class = __PACKAGE__ . "::" . $self->{language};
	$package_class = $class if $class eq __PACKAGE__;
	#exists $::{$bless_class} or croak "%Error: ->new() passed invalid language=>",$self->{language},", stopped";
	# Things are interesting, because the user might have made their
	# own class.  We'll simply make a multiple-inheritance package for them.
	eval ("
            package ${bless_class};
	    use vars qw (\@ISA);
	    \@ISA = qw (${package_class} ${class});
	    1;") or die;
    }

    # Allow $self->{C} to be a short cut for $self->{language} eq "C"
    $self->{ $self->{language} } = 1;

    bless $self, $bless_class;
    return $self;
}

sub DESTROY {
    my $self = shift;
    if ($#{$self->{text}} >= 0) {
	$self->close();
    }
}

sub close_prep {
    my $self = shift;
    $self->print (@{$self->{close_text}});
    @{$self->{close_text}} = ();
}

sub text_to_output {
    my $self = shift;
    return join('',@{$self->{text}},@{$self->{close_text}});
}

sub close {
    my $self = shift;
    $self->close_prep();

    my @oldtext;	# Old file contents
    my $keepstamp = $self->{keep_timestamp};
    if ($keepstamp) {
	my $fh = IO::File->new ($self->{filename});
	if ($fh) {
	    @oldtext = $fh->getlines();
	    $fh->close();
	} else {
	    $keepstamp = 0;
	}
    }
    
    if (!$keepstamp
	|| (join ('',@oldtext) ne join ('',@{$self->{text}}))) {
	printf "Writing $self->{filename}\n" if ($self->{verbose});
	my $fh = IO::File->new (">$self->{filename}") or die "%Error: $! $self->{filename}\n";
	print $fh @{$self->{text}};
	$fh->close();
    } else {
	printf "Same $self->{filename}\n" if ($self->{verbose});
    }

    $self->{text} = [];
}

######################################################################
#### Accessors

sub language {
    my $self = shift;
    return $self->{language};
}

sub is_keyword {
    my $sym = shift;
    return (SystemC::Vregs::Language::C::is_keyword($sym) && "C"
	    || SystemC::Vregs::Language::Perl::is_keyword($sym) && "Perl"
	    || SystemC::Vregs::Language::Verilog::is_keyword($sym) && "Verilog"
	    || SystemC::Vregs::Language::Assembler::is_keyword($sym) && "Assembler"
	    || SystemC::Vregs::Language::Tcl::is_keyword($sym) && "Tcl"
	    # XML keywords can't conflict as they all have <'s
	    ); 
}

######################################################################
#### Printing

sub print {
    my $self = shift;
    push @{$self->{text}}, @_;
}

sub printf {
    my $self = shift;
    my $fmt = shift;
    local $SIG{__WARN__} = sub { carp @_ };
    my $text = sprintf ($fmt, @_);
    $self->print($text);
}

sub print_at_close {
    my $self = shift;
    push @{$self->{close_text}}, @_;
}

sub printf_at_close {
    my $self = shift;
    my $fmt = shift;
    push @{$self->{close_text}}, sprintf ($fmt, @_);
}

sub comment {
    my $self = shift; ($self && ref($self)) or croak 'Not a hash reference';
    my $strg = join ('', @_);
    # Assume C++ style commenting
    $strg =~ s%\n(?!$)% */\n/*%sg;
    if ($strg =~ s/\n$//) {
	$self->print("/* $strg */\n");
    } else {
	$self->print("/* $strg */");
    }
}

sub define {
    my $self = shift; ($self && ref($self)) or croak 'Not a hash reference';
    # Assume C++ define
    if ($_[2]) {
	$self->printf ("#define\t%-26s %16s\t/* %s */\n", @_);
    } else {
	$self->printf ("#define\t%-26s %16s\n", @_);
    }
}

sub preproc_char {
    return '#';
}

sub preproc {
    my $self = shift; ($self && ref($self)) or croak 'Not a hash reference';
    $self->print($self->preproc_char(), @_);
}

sub include_guard {
    my $self = shift; ($self && ref($self)) or croak 'Not a hash reference';
    my $cmt = "_".uc $self->{modulename}."_";
    if ($self->{language} eq 'Verilog') {
	$self->preproc ("ifdef $cmt\n");
	$self->preproc ("else\n");	# Verilog doesn't support ifndef
    } else {
	$self->preproc ("ifndef $cmt\n");
    }
    $self->preproc ("define $cmt 1\n");
    
    $self->print_at_close("\n", $self->preproc_char(), "endif /*$cmt*/\n");
}

sub sprint_hex_value {
    my ($self,$value,$bits) = @_;
    if ($bits>32) {
	return "0x".$value . "ULL";
    } else {
	return "0x".$value;
    }
}

sub sprint_hex_value_add0 {
    my ($self,$valuestr,$bits) = @_;
    # Print the hex number, adding leading 0s to make it the proper width
    $valuestr = "0".$valuestr;	# Force conversion to string in case is Bit::Vector
    $valuestr=~ s/^0+([0-9a-f])/$1/i;
    my $add = int(($bits+3)/4) - length($valuestr);
    $valuestr = "0"x$add . $valuestr if $add>=1;
    print "ADD $valuestr $add  ".("0"x$add)."\n" if $SystemC::Vregs::Debug;
    return $self->sprint_hex_value ($valuestr, $bits);
}

sub sprint_hex_value_drop0 {
    my ($self,$valuestr,$bits) = @_;
    $valuestr = "0".$valuestr;	# Force conversion to string in case is Bit::Vector
    $valuestr=~ s/^0+(\d)/$1/;
    return $self->sprint_hex_value ($valuestr, $bits);
}

######################################################################
######################################################################
######################################################################
#### C

package SystemC::Vregs::Language::C;
use vars qw(@ISA %Keywords);
#Made by super::New: @ISA = qw(SystemC::Vregs::Language);
use strict;

#Includes some stdlib functions at the end.
foreach my $kwd (qw( asm auto break case catch cdecl char class const
		     continue default delete do double else enum extern far
		     float for friend goto huge if inline int interrupt
		     long near new operator pascal private protected public
		     register short signed sizeof static struct switch
		     template this throw try typedef union unsigned virtual
		     void volatile while

		     bool false NULL string true

		     sensitive sensitive_pos sensitive_neg

		     abort))
{ $Keywords{$kwd} = 1; }

sub is_keyword {
    return $Keywords{$_[0]};
}

######################################################################
######################################################################
######################################################################
#### Perl

package SystemC::Vregs::Language::Perl;
use vars qw(@ISA);
#Made by super::New: @ISA = qw(SystemC::Vregs::Language);
use strict;

sub is_keyword {
    my $sym = shift;
    return undef;
}

sub include_guard {
    my $self = shift;
    # Presumably is a module, so doesn't matter
    $self->printf_at_close ("1;\n");	# Good idea to have true exit status though.
}

sub comment_start_char {
    return "#";
}
sub comment_end_char {
    return "";
}

sub comment {
    my $self = shift;
    my $strg = join ('', @_);
    $strg =~ s!\n(.)!\n#$1!g;
    $self->print("#".$strg);
}

sub preproc {
    my $self = shift;
    warn 'No preprocessor for Perl Language'; 
}

sub define {
    my $self = shift;
    if ($_[2]) {
	$self->printf ("use constant %-26s => %16s;\t# %s\n", @_);
    } else {
	$self->printf ("use constant %-26s => %16s;\n", @_);
    }
}    

sub sprint_hex_value {
    my ($self,$value,$bits) = @_;
    if ($bits>32) {
#	return "Bit::Vector::new_hex(".$bits.",0x".$value.")";
	return "0x".$value;
    } else {
	return "0x".$value;
    }
}

######################################################################
######################################################################
######################################################################
#### Verilog

package SystemC::Vregs::Language::Verilog;
use vars qw(@ISA);
#Made by super::New: @ISA = qw(SystemC::Vregs::Language);
use strict;

use Verilog::Language;

sub is_keyword {
    my $sym = shift;
    return (Verilog::Language::is_keyword($sym));
}

sub preproc_char {
    return "`";
}

sub define {
    my $self = shift;
    if ($_[2]) {
	$self->printf ("`define\t%-26s %16s\t// %s\n", @_);
    } else {
	$self->printf ("`define\t%-26s %16s\n", @_);
    }
}

sub sprint_hex_value {
    my ($self,$value,$bits) = @_;
    return "${bits}'h".$value;
}

######################################################################
######################################################################
######################################################################
#### Assembler

package SystemC::Vregs::Language::Assembler;
use vars qw(@ISA);
#Made by super::New: @ISA = qw(SystemC::Vregs::Language);
use strict;

sub is_keyword {
    my $sym = shift;
    return undef;
}

sub comment_start_char {
    return ";";
}
sub comment_end_char {
    return "";
}
sub comment {
    my $self = shift;
    my $strg = join ('', @_);
    $strg =~ s!\n(.)!\n;$1!g;
    $self->print (";".$strg);
}

######################################################################
######################################################################
######################################################################
#### Tcl

package SystemC::Vregs::Language::Tcl;
use vars qw(@ISA);
@ISA = qw(SystemC::Vregs::Language);
use strict;

sub is_keyword {
    my $sym = shift;
    return undef;
}

sub comment_start_char {
    return "\#";
}
sub comment_end_char {
    return "";
}
sub comment {
    my $self = shift;
    my $strg = join ('', @_);
    $strg =~ s!\n(.)!\n#$1!g;
    $self->print ("\#".$strg);
}

######################################################################
######################################################################
######################################################################
#### XML

package SystemC::Vregs::Language::XML;
use vars qw(@ISA);
@ISA = qw(SystemC::Vregs::Language);
use strict;

sub is_keyword { return undef;}
sub comment_start_char { return "<!--"; }
sub comment_end_char { return "-->"; }
sub comment {
    my $self = shift;
    my $strg = join ('', @_);
    $strg =~ s%--+%-%sg;	# Drop --'s, they end comments
    $strg =~ s%[<>]%_%sg;	# Replace special <>'s
    $strg =~ s%\n(?!$)% -->\n<!-- %sg;
    if ($strg =~ s/\n$//) {
	$self->print("<!-- $strg -->\n");
    } else {
	$self->print("<!-- $strg -->");
    }
}

######################################################################
package SystemC::Vregs::Language;
#### Package return
1;
=pod

=head1 NAME

SystemC::Vregs::Language - File processing for various Languages

=head1 SYNOPSIS

    use SystemC::Vregs::Languages;

    my $fh = SystemC::Vregs::Languages->new (filename=>"foo.c",
				    language=>'C',);
    $fh->comment ("This file is generated automatically\n");
    $fh->define ("TRUE",1, "Set true");
    $fh->print ("void main();\n");

=head1 DESCRIPTION

This package creates a file handle with language specific semantics.  This
allows similar operators to be called, such as I<comment>, for many
different file formats.

The output data is stored in an array and dumped when the file is complete.
This allows the file to only be written if the data changes, to reduce
makefile rebuilding.

=item FIELDS

These fields may be specified with the new() function.

=over 4

=item filename

The filename to write the data to.

=item keep_timestamp

If true, the file will only be written if the data being written differs
from the present file contents.

=item language

The language for the file.  May be C, Perl, Assembler, Tcl, or Verilog.  A new
language Foo may be defined by making a SystemC::Vregs::Language::Foo class
which is an @ISA of SystemC::Vregs::Language.

=back

=item ACCESSORS

=over 4

=item language

Returns the type of file, for example 'C'.

=back

=item OUTPUT FUNCTIONS

=over 4

=item comment

Output a string with the appropriate comment delimiters.

=item include_guard

Output a standard #ifndef around the file to prevent multiple inclusion.
Closing the file will automatically add the #endif

=item sprint_hex_value

Return a string representing the value as a hex number.  Second argument is
number of bits.

=item preproc

Output a preprocessor directive.

=item print

Output plain text.  This function is called by all other functions.  You
will probably want to make a inherited class and override this method.

=item printf

Output printf text.

=back

=head1 SEE ALSO

C<IO::File>

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=cut

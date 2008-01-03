# $Id: Language.pm 49231 2008-01-03 16:53:43Z wsnyder $
# Author: Wilson Snyder <wsnyder@wsnyder.org>
######################################################################
#
# Copyright 2001-2008 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
######################################################################

package SystemC::Vregs::Language;

use strict;
use vars qw($VERSION);
use Carp;
use IO::File;

$VERSION = '1.450';

######################################################################
#### Implementation

######################################################################
#### Creation

sub new {
    my $class = shift;
    my $self = {text=>[],
		close_text=>[],
		#keep_timestamp=>undef,
		#dry_run=>undef,	# Don't do it, just see if would do it
		#change_diff=>"",
		#change_error=>{},
		#changes=>undef,	# For dry_run, any changes found?
		#verbose=>0,
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
	    use base qw (${package_class} ${class});
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
    return if $self->{_closing};  # Don't recurse in close if we die() here.
    $self->{_closing} = 1;
    
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
	$self->{changes} = 1;
	if ($self->{change_error}{ $self->language }
	    || $self->{change_error}{ALL}) {
	    if ($self->_close_change_diff()) {
		die "%Error: Changes needed to $self->{filename}, but not allowed to change ".$self->language." files\n";
	    }

	}
	if ($self->{dry_run}) {
	    printf "Would write $self->{filename} (--dry-run)\n" if ($self->{verbose});
	} else {
	    printf "Writing $self->{filename}\n" if ($self->{verbose});
	    my $fh = IO::File->new ($self->{filename},"w") or die "%Error: $! $self->{filename}\n";
	    print $fh @{$self->{text}};
	    $fh->close();
	}
    } else {
	printf "Same $self->{filename}\n" if ($self->{verbose});
    }

    $self->{text} = [];
    delete $self->{_closing};
}

our $_CloseUnlink;  END { unlink($_CloseUnlink) if $_CloseUnlink; }
sub _close_change_diff {
    my $self = shift;
    # Are there differences the user cared about?
    return 1 if (!$self->{change_diff});
    # Write to temp file
    my $tempname = (($ENV{TEMP}||$ENV{TMP}||"/tmp")."/.vreg_".$$);
    $_CloseUnlink = $tempname;
    my $fh = IO::File->new(">$tempname") or die "%Error: $! $tempname,";
    $fh or die "%Error: $! $tempname\n";
    print $fh @{$self->{text}};
    $fh->close();
    # Diff it
    system ($self->{change_diff}, $self->{filename}, $tempname);
    my $status = $?;
    # Cleanup
    unlink ($tempname); $_CloseUnlink=undef;
    return ($status != 0);
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
	    || SystemC::Vregs::Language::CPP::is_keyword($sym) && "CPP"
	    || SystemC::Vregs::Language::Perl::is_keyword($sym) && "Perl"
	    || SystemC::Vregs::Language::Verilog::is_keyword($sym) && "Verilog"
	    || SystemC::Vregs::Language::Assembler::is_keyword($sym) && "Assembler"
	    || SystemC::Vregs::Language::Tcl::is_keyword($sym) && "Tcl"
	    # XML keywords can't conflict as they all have <'s
	    ); 
}

######################################################################
#### Printing

sub push_text {
    my $self = shift;
    push @{$self->{text}}, @_;
}

sub print {
    my $self = shift;
    $self->push_text(@_);
}

sub printf {
    my $self = shift;
    my $fmt = shift;
    local $SIG{__WARN__} = sub { carp @_ };
    my $text = sprintf ($fmt, @_);
    $self->print($text);
}

sub push_close_text {
    my $self = shift;
    push @{$self->{close_text}}, @_;
}

sub print_at_close {
    my $self = shift;
    $self->push_close_text(@_);
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

sub comment_pre {
    my $self = shift; ($self && ref($self)) or croak 'Not a hash reference';
    $self->comment(@_);
}

sub comment_post {
    my $self = shift; ($self && ref($self)) or croak 'Not a hash reference';
    $self->comment(@_);
}

sub define {
    my $self = shift; ($self && ref($self)) or croak 'Not a hash reference';
    my $def = shift;
    my $val = shift;
    my $cmt = shift;
    # Assume C++ define
    my $len = ((length($val)> 16) ? 29 : 16);
    if ($cmt) {
	$self->printf ("#define\t%-26s\t%${len}s\t", $def, $val);
	$self->comment_post ($cmt,"\n");
    } else {
	$self->printf ("#define\t%-26s\t%${len}s\n", $def, $val);
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
    my ($self,$value,$bits,$force_ull) = @_;
    if ($bits>32) {
	if ($force_ull) {
	    return "0x".$value . "ULL";
	} else {
	    return "VREGS_ULL(0x".$value . ")";
	}
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
    #print "ADD $valuestr $add  ".("0"x$add)."\n" if $SystemC::Vregs::Debug;
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
use Carp;
use vars qw(%Keywords);
#Made by super::New: use base qw(SystemC::Vregs::Language);
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

sub comment_pre {
    my $self = shift; ($self && ref($self)) or croak 'Not a hash reference';
    my $strg = join ('', @_);
    $strg =~ s!\n(.)!\n/// $1!og;
    $strg =~ s!\n\n!\n///\n!og;
    $strg = " ".$strg unless $strg =~ /^\s/;
    $self->print("///$strg");
}

sub comment_post {
    my $self = shift; ($self && ref($self)) or croak 'Not a hash reference';
    my $strg = join ('', @_);
    $strg =~ s!\n(.)!\n///< $1!og;
    $self->print("///< $strg");
}

######################################################################
######################################################################
######################################################################
#### CPP

package SystemC::Vregs::Language::CPP;
use Carp;
use vars qw(%Keywords);
use base qw(SystemC::Vregs::Language::C);
use strict;

sub is_keyword {
    return SystemC::Vregs::Language::C::is_keyword(@_);
}

######################################################################
######################################################################
######################################################################
#### Lisp

package SystemC::Vregs::Language::Lisp;
use base qw(SystemC::Vregs::Language);
use Carp;
use strict;

sub is_keyword { return undef;}
sub include_guard {}

sub comment_start_char { return ";;"; }
sub comment_end_char { return ""; }
sub comment {
    my $self = shift;
    my $strg = join ('', @_);
    $strg =~ s!\n(.)!\n;;$1!g;
    $strg =~ s!\n\n!\n;;\n!og;
    $self->print(";;".$strg);
}

sub define {
    my $self = shift; ($self && ref($self)) or croak 'Not a hash reference';
    my $def = shift;
    my $val = shift;
    my $cmt = shift;
    if ($cmt) {
	$self->printf ("(defconstant %-26s\t%16s) ;; %s\n", $def, $val, $cmt);
    } else {
	$self->printf ("(defconstant %-26s\t%16s)\n", $def, $val);
    }
}

sub sprint_hex_value {
    my ($self,$value,$bits) = @_;
    return "#x".$value;
}

######################################################################
######################################################################
######################################################################
#### Perl

package SystemC::Vregs::Language::Perl;
#Made by super::New: use base qw(SystemC::Vregs::Language);
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
    $strg =~ s!\n\n!\n#\n!og;
    $self->print("#".$strg);
}

sub preproc {
    my $self = shift;
    warn 'No preprocessor for Perl Language'; 
}

sub define {
    my $self = shift;
    if ($_[2]) {
	$self->printf ("use constant %-26s\t=> %16s;\t# %s\n", @_);
    } else {
	$self->printf ("use constant %-26s\t=> %16s;\n", @_);
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
#Made by super::New: use base qw(SystemC::Vregs::Language);
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
	$self->printf ("`define\t%-26s\t%16s\t// %s\n", @_);
    } else {
	$self->printf ("`define\t%-26s\t%16s\n", @_);
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
#Made by super::New: use base qw(SystemC::Vregs::Language);
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
    $strg =~ s!\n\n!\n;\n!og;
    $self->print (";".$strg);
}

######################################################################
######################################################################
######################################################################
#### Gas Assembler

package SystemC::Vregs::Language::Gas;
use base qw(SystemC::Vregs::Language);
use strict;

sub is_keyword {
    my $sym = shift;
    return undef;
}

sub sprint_hex_value {
    my ($self,$value,$bits) = @_;
    # Never a ULL postfix
    return "0x".$value;
}

######################################################################
######################################################################
######################################################################
#### Tcl

package SystemC::Vregs::Language::Tcl;
use base qw(SystemC::Vregs::Language);
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
    $strg =~ s!\n\n!\n#\n!og;
    $self->print ("\#".$strg);
}

######################################################################
######################################################################
######################################################################
#### XML

package SystemC::Vregs::Language::XML;
use base qw(SystemC::Vregs::Language);
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

    use SystemC::Vregs::Language;

    my $fh = SystemC::Vregs::Language->new (filename=>"foo.c",
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

=head1 FIELDS

These fields may be specified with the new() function.

=over 4

=item filename

The filename to write the data to.

=item keep_timestamp

If true, the file will only be written if the data being written differs
from the present file contents.

=item language

The language for the file.  May be C, Perl, Assembler, TCL, or Verilog.  A new
language Foo may be defined by making a SystemC::Vregs::Language::Foo class
which is an @ISA of SystemC::Vregs::Language.

=back

=head1 ACCESSORS

=over 4

=item language

Returns the type of file, for example 'C'.

=back

=head1 OUTPUT FUNCTIONS

=over 4

=item comment

Output a string with the appropriate comment delimiters.

=item comment_pre

Output a comment and Doxygen document before-the-fact.

=item comment_post

Output a comment and Doxygen document after-the-fact.

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

=head1 DISTRIBUTION

Vregs is part of the L<http://www.veripool.com/> free Verilog software tool
suite.  The latest version is available from CPAN and from
L<http://www.veripool.com/vregs.html>.  /www.veripool.com/>.

Copyright 2001-2008 by Wilson Snyder.  This package is free software; you
can redistribute it and/or modify it under the terms of either the GNU
Lesser General Public License or the Perl Artistic License.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=head1 SEE ALSO

L<SystemC::Vregs>, L<IO::File>

=cut

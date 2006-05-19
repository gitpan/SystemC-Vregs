# $Id: File.pm 20440 2006-05-19 13:46:40Z wsnyder $
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

package SystemC::Vregs::File;
use File::Basename;
use vars qw($VERSION);
use base qw(SystemC::Vregs::Language);

use SystemC::Vregs::Number;
use SystemC::Vregs::Language;
use strict;
use Carp;

$VERSION = '1.420';

######################################################################
######################################################################
# Files

sub open {
    my $class = shift;
    # General routine for opening output file and starting header

    my %params = @_;
    $params{language} or croak "%Error: No language=> specified,";

    my $self = $class->SUPER::new(verbose=>1,
				  # noheader=>0,
				  %params);

    my ($name,$path,$suffix) = fileparse($self->{filename},'\..*');
    my $template_filename = $path.$name."__template".$suffix;
    print "Check Template File $template_filename\n" if $SystemC::Vregs::Debug;
    if (-r $template_filename) {
	#$self->{template}->read (filename=>$template_filename);
    }

    if (!$self->{noheader}) {
	$self->print("// -*- C++ -*-\n") if ($self->{CPP});
	$self->print("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n") if ($self->{XML});
	$self->comment("DO NOT EDIT -- Generated automatically by vregs\n");
	if ($self->{C} || $self->{CPP}) {
	    $self->comment_pre("\\file\n");
	    $self->comment_pre("\\brief Register Information: Generated automatically by vregs\n");
	} else {
	    $self->comment("DESC"."RIPTION: Register Information: Generated automatically by vregs\n");
	}
	$self->comment_pre("\n");
    }

    if ($self->{rules}) {
	$self->{rules}->filehandle($self);
	foreach my $rfile ($self->{rules}->filenames()) {
	    $rfile = basename($rfile,"^");
	    $self->comment_pre("See SystemC::Vregs::Rules file: $rfile\n");
	}
	$self->comment_pre("\n");
    }

    $self->{rules}->execute_rule ('any_file_before', 'any_file', $self) if $self->{rules};

    return $self;
}

sub close {
    my $self = shift;
    # General routine for closing output file

    $self->close_prep();

    $self->{rules}->execute_rule ('any_file_after', 'any_file', $self) if $self->{rules};

    if (!$self->{noheader}) {
	$self->print("\n");
	$self->comment ("DO NOT EDIT -- Generated automatically by vregs\n");
    }

    $self->SUPER::close();
}

sub private_not_public {
    my $self = shift;
    my $private = shift;
    my $pack = shift;
    # Print public: or private: depending on desired state

    my $enabled = (defined $pack->{rules}{protect_rdwr_only}
		   ? $pack->{rules}{protect_rdwr_only}
		   : $pack->{protect_rdwr_only});
    $private = 0 if !$enabled;
    if ($self->{CPP}) {
	if ($private && !$self->{private}) {
	    $self->print ("protected:\n");
	}
	if (!$private && $self->{private}) {
	    $self->print ("public:\n");
	}
    }
    $self->set_private($private);
}

sub set_private {
    my $self = shift;
    my $private = shift;
    $self->{private} = $private;
}

sub fn {
    my $self = shift;
    my $clname = shift;
    my $suffix = shift;
    my $proto = shift;
    # Declare a function with C++ semantics, mangle into C if necessary
    if ($self->{CPP}) {
	$self->print ("    $proto ",@_);
    } else {
	my $const = ($proto =~ s/const\s*$//) ? "const ":"";

	$proto =~ m/\s*(\S+)\s*\(/;
	my $fname = lcfirst "${clname}_$1";
	$fname .= "_".$suffix if $suffix;
	if ($self->{private}) {
	    $self->{func_private}{$fname} = $self->{private};
	    $fname .= "_private";
	}
	$proto =~ s/\s+(\S+)\s*\(/ ${fname}(/;

        $proto =~ s/\(/(${const}${clname}* thisp,/;
        $proto =~ s/,\s*\)/)/;
	$self->print ("$proto ",@_);
    }
}

sub call_str {
    my $self = shift;
    my $clname = shift;
    my $suffix = shift;
    my $call = shift;
    # Call a function with C++ semantics, mangle into C if necessary
    # return as *string*
    if ($self->{CPP}) {
	return join('',"$call",@_);
    } else {
	$call =~ m/\s*(\S+)\s*\(/;
	my $fname = lcfirst "${clname}_$1";
	$fname .= "_".$suffix if $suffix;
	$fname .= "_private" if $self->{func_private}{$fname};
	$call =~ s/(\S+)\s*\(/${fname}(/;
        $call =~ s/\(/(thisp,/ or croak "%Error: No args in func call '$call',";
        $call =~ s/,\s*\)/)/;
	return join('',$call,@_);
    }
}

######################################################################
# Tabify all output

sub print {
    my $self = shift;
    # Override default SystemC::Vregs::Language::print to tabify all output
    $self->push_text($self->tabify(@_));
}

sub print_at_close {
    my $self = shift;
    # Override default SystemC::Vregs::Language::print to tabify all output
    $self->push_close_text($self->tabify(@_));
}

sub printf_tabify {
    my $self = shift;
    my $line = sprintf(shift,@_);
    $self->print($self->tabify($line));
}

sub tabify {
    my $self = shift;
    my $line = join('',@_);
    # Convert any space-tabs to just tabs
    my $out='';
    my $col=0;
    my $spaces=0;
    $line =~ s/\t        /\t\t/g;
    for (my $i=0; $i<length($line); $i++) {
	my $c = substr($line,$i,1);
	if ($c eq "\n") {
	    $out .= $c;
	    $col = 0;
	    $spaces = 0;
	} elsif ($c eq "\t") {
	    my $wantcol = int(($col+$spaces+8)/8)*8;
	    while ($wantcol > $col) {
		$col = int(($col+8)/8)*8;
		$out .= "\t";
	    }
	    $spaces = 0;
	} elsif ($c eq " ") {
	    $spaces++;
	} else {
	    if ($spaces) { $out .= ' 'x$spaces; $col+=$spaces; $spaces=0; }
	    $out .= $c;
	    $col++;
	}
    }
    return $out;
}

######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::File - Output Vregs Code

=head1 SYNOPSIS

    use SystemC::Vregs::File;

=head1 DESCRIPTION

This package contains an extension of the SystemC::Vregs::Language class,
used for writing files.

=head1 METHODS

=over 4

=item open

Create a new file handle object. Named parameters include:

  filename - passed  to SystemC::Vregs::Language.

  verbose - print comment on opening of file on the screen.

  noheader - suppress Automatically Generated comments.

  And all parameters supported by SystemC::Vregs::Language.

=item close

Print the closing comment and close the file.

=item private_not_public

Unless previously printed, if true, print "private:" else print "public".

=item fn

Print a function declaration in C or C++ format.

=item call_str

Return a function call string in C or C++ format.

=item print_tabify

Print the line with spaces that land on tab stops as tabs.

=back

=head1 DISTRIBUTION

The latest version is available from CPAN and from L<http://www.veripool.com/>.

Copyright 2001-2006 by Wilson Snyder.  This package is free software; you
can redistribute it and/or modify it under the terms of either the GNU
Lesser General Public License or the Perl Artistic License.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=head1 SEE ALSO

L<SystemC::Vregs>,
L<SystemC::Vregs::Language>

=cut

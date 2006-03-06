# $Id: Hash.pm 15061 2006-03-01 19:51:13Z wsnyder $
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

package SystemC::Vregs::Output::Hash;

require 5.005;
use SystemC::Vregs;
use SystemC::Vregs::File;
use strict;
use Carp;
use vars qw($VERSION);

$VERSION = '1.400';

######################################################################
# CONSTRUCTOR

sub new {
    my $class = shift;
    my $self = {@_};
    bless $self, $class;
    return $self;
}

######################################################################
# METHODS

sub write {
    my $self = shift;
    my %params = (pack => $self->{pack},
		  @_);
    my $pack = $params{pack} or croak "%Error: No pack=> parameter passed,";

    my $fl = SystemC::Vregs::File->open(language=>'Perl',
					%params);
    $fl->include_guard();
    $fl->print("\n");
    $fl->print("package $pack->{name};\n");
    $fl->print("\n");

    foreach my $eref ($pack->enums_sorted) {
	$fl->print ('%'.$eref->{name}." = (\n");
	foreach my $fieldref ($eref->fields_sorted()) {
	    my $cmt = "";
	    $cmt = "\t# $fieldref->{desc}" if $pack->{comments};
	    $fl->printf ("  0x%-4x => '%-20s%s\n"
			 ,$fieldref->{rst_val}
			 ,$fieldref->{name}."',"
			 ,$cmt);
	}
	$fl->print ("  );\n\n");
    }

    $fl->close();
}

######################################################################
######################################################################
######################################################################
######################################################################
1;
__END__

=pod

=head1 NAME

SystemC::Vregs::Output::Hash - Dump Vregs into Hash format

=head1 SYNOPSIS

SystemC::Vregs::Output::Hash->new->write(pack=>$VregsPackageObject, filename=>$fn);

=head1 DESCRIPTION

This package dumps vregs format into a perl Hash file.  It is called by the
Vregs package.

=head1 METHODS

=over 4

=item new()

Create and return a new output class.

=item $self->write(pack=>I<vregsPackage>, filename=>I<filename>)

Creates the output file.

=back

=head1 DISTRIBUTION

Copyright 2001-2006 by Wilson Snyder.  This package is free software; you
can redistribute it and/or modify it under the terms of either the GNU
Lesser General Public License or the Perl Artistic License.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=head1 SEE ALSO

L<vreg>,
L<SystemC::Vregs>

=cut

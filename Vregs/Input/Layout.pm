# See copyright, etc in below POD section.
######################################################################

package SystemC::Vregs::Input::Layout;
use Carp;
use strict;
use vars qw($VERSION);

$VERSION = '1.470';

######################################################################
# CONSTRUCTOR

sub new {
    my $class = shift;
    my $self = {@_};
    bless $self, $class;
    return $self;
}

######################################################################
# Saving

sub read {
    my $self = shift;
    my %params = (#filename =>
		  #pack =>
		  @_);
    my $pack = $params{pack} or croak "%Error: No pack=> parameter passed,";
    $self->{pack} = $pack;
    # Dump headers for class name based accessors

    my $filename = $params{filename};
    my $fh = new IO::File ("<$filename") or die "%Error: $! $filename\n";

    my $line;
    my $lineno = 0;
    my $regref;
    my $typeref;
    my $classref;
    my $got_a_line = 0;
    while (my $line = $fh->getline() ) {
	chomp $line;
	$lineno++;
	$got_a_line=1;
	if ($line =~ /^\# (\d+) \"([^\"]+)\"[ 0-9]*$/) {  # from cpp: # linenu "file" {level}
	    $lineno = $1 - 1;
	    $filename = $2;
	    #print "#FILE '$filename'\n" if $Debug;
	}
	$line =~ s/\/\/.*$//;	# Remove C/Verilog style comments
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;

	my $fileline = "$filename:$lineno";
	if ($line eq "") {}
	elsif ($line =~ /^reg\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)(.*)$/ ) {
	    my $classname = $1;
	    my $type = $2;
	    my $addr = lc $3;
	    my $spacingtext = $4;
	    my $flags = $5 || "";
	    my $range = "";
	    $range = $1 if $type =~ s/(\[.*\])//;
	    $regref = new SystemC::Vregs::Register
		(pack => $pack,
		 name => $classname,
		 at => "${filename}:$.",
		 addrtext => $addr,
		 spacingtext => $spacingtext,
		 range => $range,
		 );
	    $regref->attributes_parse($flags);
	}
	elsif ($line =~ /^type\s+(\S+)\s*(.*)$/ ) {
	    my $typemnem = $1; my $flags = $2;
	    my $inh = "";
	    $inh = $1 if ($flags =~ s/:(\S+)//);
	    $typemnem =~ s/^Vregs//;
	    $typemnem =~ s/_t$//;
	    $typeref = new SystemC::Vregs::Type
		(pack => $pack,
		 name => $typemnem,
		 at => "${filename}:$.",
		 );
	    $typeref->inherits($inh);
	    $typeref->attributes_parse($flags);
	    $regref->{typeref} = $typeref if $regref && $typemnem =~ /^R_/;
	    $regref = undef;
	}
	elsif ($line =~ /^bit\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+([^\"]*)"(.*)"$/ ) {
	    if (!$typeref) {
		die "%Error: $filename:$.: bit without previous type declaration\n";;
	    }
	    my $bit_mnem = $1;
	    my $bits = $2; my $acc = $3; my $type = $4; my $rst = $5; my $flags=$6; my $desc=$7;
	    my $ref = new SystemC::Vregs::Bit
		(pack => $pack,
		 name => $bit_mnem,
		 typeref => $typeref,
		 bits => $bits,
		 access => $acc,
		 rst  => $rst,
		 desc => $desc,
		 type => $type,
		 at => "${filename}:$.",
	     );
	    $ref->attributes_parse($flags);
	}
	elsif ($line =~ /^enum\s+(\S+)\s*(.*)$/) {
	    my $name = $1; my $flags = $2;
	    $classref = new SystemC::Vregs::Enum
		(pack => $pack,
		 name => $name,
		 at => "${filename}:$.",
		 );
	    $classref->attributes_parse($flags);
	}
	elsif ($line =~ /^const\s+(\S+)\s+(\S+)\s+([^\"]*)"(.*)"$/ ) {
	    my $name = $1;  my $rst=$2;  my $flags=$3;  my $desc=$4;
	    my $ref = new SystemC::Vregs::Enum::Value
		(pack => $pack,
		 name => $name,
		 class => $classref,
		 rst  => $rst,
		 desc => $desc,
		 at => "${filename}:$.",
		 );
	    $ref->attributes_parse($flags);
	}
	elsif ($line =~ /^define\s+(\S+)\s+(\S+)\s+([^\"]*)"(.*)"$/ ) {
	    my $name = $1;  my $rst=$2;  my $flags=$3; my $desc=$4;
	    $rst = $1 if $rst =~ m/^"(.*)"$/;
	    my $ref = new SystemC::Vregs::Define::Value
		(pack => $pack,
		 name => $name,
		 rst  => $rst,
		 desc => $desc,
		 is_manual => 1,
		 at => "${filename}:$.",
		 );
	    $ref->attributes_parse($flags);
	}
	elsif ($line =~ /^package\s+(\S+)\s*(.*)$/ ) {
	    my $flags = $2;
	    $pack->{name} = $1;
	    $pack->{at} = "${filename}:$.";
	    $pack->attributes_parse($flags);
	}
	else {
	    die "%Error: $fileline: Can't parse \"$line\"\n";
	}
    }

    ($got_a_line) or die "%Error: File empty or cpp error in $filename\n";

    $fh->close();
}

######################################################################
######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::Input::Layout - Inputting .vregs files

=head1 SYNOPSIS

SystemC::Vregs::Input::Layout->new->read(pack=>$VregsPackageObject, filename=>$fn);

=head1 DESCRIPTION

This package reads .vregs format from a file.  It is called by the Vregs
package.

=head1 METHODS

=over 4

=item new()

Create and return a new output class.

=item read

Reads a file.

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

L<vreg>,
L<SystemC::Vregs>

=cut

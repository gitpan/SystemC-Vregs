# See copyright, etc in below POD section.
######################################################################

package SystemC::Vregs::Output::Param;

require 5.005;
use SystemC::Vregs;
use SystemC::Vregs::File;
use strict;
use Carp;
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
# METHODS

sub write {
    my $self = shift;
    my %params = (pack => $self->{pack},
		  @_);
    my $pack = $params{pack} or croak "%Error: No pack=> parameter passed,";

    $pack->create_defines(1);
    my $fl = SystemC::Vregs::File->open(language=>'Verilog',
					rules => $pack->{rules},
					@_);

    #$fl->include_guard();  #no guards-- it may be used in multiple modules

    $fl->comment_pre
	(("*"x70)."\n"
	 ."\tP_{defname}             Define values as a parameter\n"
	 ."\tRAP_{regname}           Register address as a parameter\n"
	 ."\tCMP_{regname}_WRITABLE  Register RdWr bit-mask as a parameter\n"
	 ."\n"
	 ."\tThis is useful in Verilog to allow extraction of bit\n"
	 ."\tranges, for example:\n"
	 ."\t\tif (myaddr == RAP_SOMEREG[31:15]) ...\n"
	 ."\n");

    $fl->print ("\n"
		."`ifdef NOTDEFINED\n"
		."module just_for_proper_indentation ();\n"
		."`endif\n"
		."\n"
		."//Verilint 175 off //WARNING: Unused parameter\n\n");

    foreach my $defref ($pack->defines_sorted) {
	my $define  = $defref->{name};
	my $value   = $defref->{val};
	my $comment = $defref->{desc};

	my $cmt = "";
	$cmt = "\t// ${comment}" if $pack->{comments};

	if (($define =~ s/^(RA|RAM|CM|RBASEA)_/${1}P_/
	    || ($defref->{is_manual} && $define =~ s/^(.*)$/P_$1/))
	    && ($defref->{rst_val}||'') !~ /Not_Aligned/i
	    && !$defref->attribute_value('freeform')) {
	    my $prt_val = _param_write_value($self, $defref, $fl);
	    $fl->printf ("   %s %-26s %13s%s\n",
			 ($pack->attribute_value('v2k') ? 'localparam':'parameter'),
			 $define . " =", $prt_val.";",
			 $cmt
			 );
	}
    }

    foreach my $classref ($pack->enums_sorted) {
	my @fields = ($classref->fields_sorted());
	my $i=0;
	foreach my $fieldref (@fields) {
	    if ($i==0) {
		$fl->printf ("   %s %s\n",
			     ($pack->attribute_value('v2k') ? 'localparam':'parameter'),
			     "// synopsys enum En_$classref->{name}"
			     );
	    }
	    my $prt_val = _param_write_value($self, $fieldref, $fl, 'tohex');
	    $fl->printf ("\t     %-26s %13s\n",
			 "EP_" . $classref->{name} . "_" . $fieldref->{name}." =",
			 $prt_val.(($i==$#fields) ? ";" : ","),
			 );
	    $i++;
	}
    }

    $fl->close();
}

######################################################################

use vars qw($_Param_Write_Value_Bit32);

sub _param_write_value {
    my $self = shift;
    my $fieldref = shift;
    my $fl = shift;
    my $tohex = shift;

    # Create max value that fits in 32 bits, just once for speed
    $_Param_Write_Value_Bit32 ||= $fieldref->{pack}->addr_const_vec(0xffffffff);
    my $bit32 = $_Param_Write_Value_Bit32;

    my $rst_val = $fieldref->{rst_val};
    $rst_val = sprintf("%X",$rst_val) if !ref $rst_val && $tohex;
    my $value   = $fieldref->{val};
    my $bits    = $fieldref->{bits};
    if (defined $bits && defined $value && ref $value) {
	$bits = 32 if ($bits==32
		       || $fieldref->{pack}{param_always_32bits}
		       || (!defined $fieldref->{pack}{param_always_32bits}
			   && !$fieldref->{pack}->attribute_value('v2k'))
		       || ($value->Lexicompare($bit32)<=0));  # value<32 bits
	$value = Bit::Vector->new_Hex($bits, $value->to_Hex);
	$rst_val = $value->to_Hex;
    }
    return $fl->sprint_hex_value_add0 ($rst_val,$bits);
}

######################################################################
######################################################################
######################################################################
######################################################################
1;
__END__

=pod

=head1 NAME

SystemC::Vregs::Output::Param - Dump Vregs into Perl Parameters format

=head1 SYNOPSIS

SystemC::Vregs::Output::Param->new->write(pack=>$VregsPackageObject, filename=>$fn);

=head1 DESCRIPTION

This package dumps vregs format into a perl parameters file.  It is called
by the Vregs package.

=head1 METHODS

=over 4

=item new()

Create and return a new output class.

=item $self->write(pack=>I<vregsPackage>, filename=>I<filename>)

Creates the output file.

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

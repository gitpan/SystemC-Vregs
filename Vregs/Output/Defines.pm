# See copyright, etc in below POD section.
######################################################################

package SystemC::Vregs::Output::Defines;

require 5.005;
use SystemC::Vregs;
use SystemC::Vregs::File;
use strict;
use Carp;
use vars qw($VERSION);

$VERSION = '1.463';

######################################################################
# CONSTRUCTOR

sub new {
    my $class = shift;
    my $self = {define_prefix => '',
		@_};
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
    my $fl = SystemC::Vregs::File->open(rules => $pack->{rules},
					@_);

    $fl->comment_pre("\n");
    $fl->comment_pre("package $pack->{name}\n");
    $fl->comment_pre("\n");
    $fl->comment_pre(("*"x70)."\n");

    $self->_print_header($pack, $fl);

    $fl->include_guard();
    $fl->print("\n");

    $fl->print ("//Verilint  34 off //WARNING: Unused macro\n") if $fl->{Verilog};
    $fl->print("\n");

    $pack->{rules}->execute_rule ('defines_file_before', $fl->{filename}, $pack);
    $fl->print("\n");

    $self->_body($pack, $fl);

    $pack->{rules}->execute_rule ('defines_file_after', $fl->{filename}, $pack);

    $fl->close();
}

######################################################################

sub _print_header {
    my $self = shift;
    my $pack = shift;
    my $fl = shift;

    $fl->comment_pre
	("  General convention:\n"
	 ."     RA_{regname}     Register beginning address\n"
	 ."     RAE_{regname}    Register ending address + 1\n"
	 ."     RAC_{regname}    Number of entries in register\n"
	 ."     RAM_{regname}    Register region address mask\n"
	 ."     RRP_{regname}    Register RANGE spacing in bytes, if arrayed\n"
	 ."     RRS_{regname}    Register RANGE size, if arrayed\n"
	 ."\n"
	 ."     RBASEA_{regs}    Register common-prefix starting address\n"
	 ."     RBASEAE_{regs}   Register common-prefix ending address + 1\n"
	 ."     RBASEAM_{regs}   Register common-prefix bit mask\n"
	 ."\n"
	 ."     E_{enum}_{alias}           Value of enumeration encoding\n"
	 ."\n"
	 ."     CM{w}_{class}_WRITABLE     Mask of all writable bits\n"
	 ."     CB{w}_{class}_{field}_{f}  Class field starting bit\n"
	 ."     CE{w}_{class}_{field}_{f}  Class field ending bit\n"
	 ."     CR{w}_{class}_{field}_{f}  Class field range\n"
	 ."          {w}=32=bit word number,  {f}=field number if discontinuous\n"
	 );
    $fl->print("\n");
}

sub _body {
    my $self = shift;
    my $pack = shift;
    my $fl = shift;

    $fl->print("{\n    no warnings 'portable';\n") if $fl->{Perl};

    my $firstauto = 1;
    foreach my $defref ($pack->defines_sorted) {
	if ($firstauto && !$defref->{is_manual}) {
	    $fl->print("\n\n");
	    $fl->comment("Automatic Defines\n");
	    $firstauto = 0;
	}

	my $define  = $defref->{name};
	my $comment = $defref->{desc};
	if (($fl->{C} || $fl->{CPP}) && $define =~ /^C[BER][0-9]/) {
	    next;  # Skip for Perl/C++, not much point as we have structs
	}

	my $value   = $defref->{rst_val};
	if ($defref->attribute_value('freeform')) {
	    $value = $defref->{rst};
	} else {
	    $value = $fl->sprint_hex_value_add0 ($value,$defref->{bits}) if (defined $defref->{bits});
	}
	if ($fl->{Perl}) {
	    if (($defref->{bits}||0) > 64) {
		$fl->print ("#");
		$comment .= " (TOO LARGE FOR PERL)";
	    }
	}
	if (($defref->{is_verilog} && $fl->{Verilog})
	    || ($defref->{is_perl} && $fl->{Perl})
	    || (!$defref->{is_verilog} && !$defref->{is_perl})) {
	    $comment = "" if !$pack->{comments};
	    $comment = "" if $pack->{no_trivial_comments} && $defref->{desc_trivial};
	    $fl->printf("#ifndef %s\n",$self->{define_prefix}.$define)
		if $self->{ifdef_wrap_all};
	    $fl->define ($self->{define_prefix}.$define, $value, $comment);
	    $fl->printf("#endif\n") if $self->{ifdef_wrap_all};
	}
    }

    $fl->print("}\n") if $fl->{Perl};
}

######################################################################
######################################################################
######################################################################
######################################################################
1;
__END__

=pod

=head1 NAME

SystemC::Vregs::Output::Defines - Dump Vregs into Defines header format

=head1 SYNOPSIS

SystemC::Vregs::Output::Defines->new->write(pack=>$VregsPackageObject, filename=>$fn);

=head1 DESCRIPTION

This package dumps vregs format into a header file for various languages.
It is called by the Vregs package.

=head1 METHODS

=over 4

=item new()

Create and return a new output class.

=item $self->write(pack=>I<vregsPackage>, filename=>I<filename>)

Creates a C++, Verilog, or Perl header file with defines.  The language
parameter is used along with SystemC::Vregs::Language to produce the
definitions in a language appropriate way.

=back

=head1 DISTRIBUTION

Vregs is part of the L<http://www.veripool.org/> free Verilog software tool
suite.  The latest version is available from CPAN and from
L<http://www.veripool.org/vregs>.  /www.veripool.org/>.

Copyright 2001-2009 by Wilson Snyder.  This package is free software; you
can redistribute it and/or modify it under the terms of either the GNU
Lesser General Public License Version 3 or the Perl Artistic License Version 2.0.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=head1 SEE ALSO

L<vreg>,
L<SystemC::Vregs>

=cut

# $Revision: #47 $$Date: 2004/10/26 $$Author: ws150726 $
# Author: Wilson Snyder <wsnyder@wsnyder.org>
######################################################################
#
# Copyright 2001-2004 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
######################################################################

package SystemC::Vregs::Register;
use SystemC::Vregs::Number;
use SystemC::Vregs::Type;
use Bit::Vector::Overload;

use strict;
use vars qw (@ISA $VERSION);
@ISA = qw (SystemC::Vregs::Subclass);
$VERSION = '1.246';

# Fields:
#	{name}			Field name (Subclass)
#	{nor_name}		Name w/o leading R_
#	{at}			File/line number (Subclass)
#	{pack}			Parent SystemC::Vregs ref
#	{typeref}		Owning SystemC::Vregs::Type ref
#	{addrtext}	
#	{addr}			Beginning SystemC::Vregs::Addr
#	{addr_end}		Ending SystemC::Vregs::Addr
#	{spacingtext}	
#	{range}			Range text
#	{range_high}		SystemC::Vregs::Addr
#	{range_low}		SystemC::Vregs::Addr
#	{range_ents}		Number of range entries, SystemC::Vregs::Addr

######################################################################
# Accessors

sub new {
    my $class = shift;  $class = ref $class if ref $class;
    my $self = $class->SUPER::new(@_);
    $self->{pack} or die;  # Should have been passed as parameter
    $self->{pack}{regs}{$self->{name}} = $self;
    return $self;
}

sub delete {
    my $self = shift;
    $self->{pack} or die;
    delete $self->{pack}{regs}{$self->{name}};
}

######################################################################

sub dewildcard {
    my $self = shift;
    #print ::Dumper($self);
    return if (($self->{name}||"") !~ /\*/);
    my $inh = $self->{typeref}->inherits();
    print "Reg Wildcard $self->{name} $inh\n" if $SystemC::Vregs::Debug;
    (my $regexp = $inh) =~ s/[*]/\.\*/g;

    #(my $defbase = $inh) =~ s/[*]/Base/g;
    #(my $defname = $defbase) =~ s/^R_//g;
    #my $defref = new SystemC::Vregs::Define::Value
    #	 (pack => $self->{pack},
    #	  name => "RA_".$defname,
    #	  rst  => $self->{addrtext},
    #	  desc => "Base address from wildcarded register range",
    #	  );
    
    my $gotone;
    foreach my $matchref ($self->{pack}->find_reg_regexp("^$regexp")) {
	$gotone = 1;
	my $newname = SystemC::Vregs::three_way_replace
	    ($self->{name}, $inh, $matchref->{name});
	my $typeref = $self->{pack}->find_type($newname) or die;
	my $addr = $self->{addrtext} ."|". $matchref->{addrtext};
	print "  Wildcarded $matchref->{name} to $newname\n" if $SystemC::Vregs::Debug;
	$self->new (name=>$newname,
		    pack=>$self->{pack},
		    addrtext => $addr,
		    spacingtext => $matchref->{spacingtext},
		    range =>  $matchref->{range},
		    typeref => $typeref,
		    );
    }
    $gotone or $self->warn ("No types matching wildcarded type: ",$self->inherits(),"\n");
    $self->delete();
}

######################################################################

sub check_name {
    my $regref = shift;
    my $field = $regref->{name};
    ($field =~ /^R_[A-Z][a-zA-Z0-9]*$/)
	or $regref->warn ("Register mnemonics must match R_[capitals][alphanumerics]\n");
    ($field =~ /cnfg[0-9]+$/i) and $regref->warn ("Abbreviate CNFG (Configuration) as Cfg\n");  #Dan Lussier'ism
    ($regref->{nor_name} = $field) =~ s/^[RC]_//;
}

sub check_addrtext {
    my $regref = shift;
    my $addrtext = $regref->{addrtext};

    my $inher_min;
    if ($addrtext =~ s/\s*[|]\s*\b(R_[0-9a-zA-Z_]+)\b//) {
	my $orin_name = $1;
	my $orin_ref = $regref->{pack}->find_reg($orin_name);
	if (!$orin_ref) {
	    $regref->warn ("Address contains | of unknown register: $addrtext\n");
	} else {
	    my $text = $orin_ref->{addrtext};
	    $text =~ s/-.*//;
	    $inher_min = $regref->{pack}->addr_text_to_vec($text);
	    defined $inher_min or $orin_ref->warn("Can't parse address text: $text\n");
	}
    }

    if ($addrtext =~ s/^.*(0x[0-9a-f_]+)\s*-\s*(0x[0-9a-f_]+)\s*[|]\s*//i) {
	my $mintext = $1;  my $maxtext = $2;
	$inher_min = $regref->{pack}->addr_text_to_vec($mintext);
	$regref->{addr_end_wildcard} = $regref->{pack}->addr_text_to_vec($maxtext);
    }
    ($addrtext !~ /[|]/) or $regref->warn ("Address cannot contain |'s, or needs complete range: ", $addrtext,"\n");

    my $endtext = "";
    if ($addrtext =~ s/^(0x[0-9a-f_]+)\s*-\s*(0x[0-9a-f_]+)$/$1/i) {
	$endtext = $2;
	$regref->{addr_end} = $regref->{pack}->addr_text_to_vec($endtext);
    }

    ($addrtext =~ /^0x[0-9a-f_]+$/i)
	or $regref->warn ("Strange address format '$addrtext'\n");

    $regref->{addr} = $regref->{pack}->addr_text_to_vec($addrtext);
    if ($inher_min) {
	$regref->{addr}->add(      $regref->{addr},  $inher_min, 0);
	$regref->{addr_end}->add(  $regref->{addr},  $inher_min, 0) if $regref->{addr_end};
    }
}

sub check_range_spacing {
    my $regref = shift;

    my $range = $regref->{range};
    if (!defined $regref->{spacing}) {
	$regref->{spacing} = $regref->{pack}->addr_text_to_vec($regref->{spacingtext});
	(defined $regref->{spacing}) or $regref->warn ("Strange spacing value $regref->{spacingtext}\n");
    }

    my $spacing = $regref->{spacing};
    if ($range) {
	$range =~ /^\[([^\]:]+):([^\]:]+)\]$/
	    or $regref->warn ("Strange range $range\n");
	my $htext = $1;  my $ltext = $2;
	$regref->{range_high} = $regref->{pack}->addr_text_to_vec($htext);
	$regref->{range_low}  = $regref->{pack}->addr_text_to_vec($ltext);
	(defined $regref->{range_high}) or $regref->warn ("Can't parse $htext in range $range\n");
	(defined $regref->{range_low}) or $regref->warn ("Can't parse $htext in range $range\n");
	($spacing->Lexicompare($regref->{pack}->addr_const_vec(4)) >= 0)
	    or $regref->warn ("Strange address spacing $spacing\n");
    }
    else { # No range
	($spacing->equal($regref->{pack}->addr_const_vec(0)))
	    or $regref->warn ("Address spacing set to $spacing, but no range specified\n");
	$regref->{range_low}  
	= $regref->{range_high}
	= $regref->{pack}->addr_const_vec(0);
    }
    $regref->{range_ents} = $regref->{pack}->addr_const_vec(1);
    $regref->{range_ents}->add( $regref->{range_high}, $regref->{range_ents}, 0);
    $regref->{range_ents}->subtract ($regref->{range_ents}, $regref->{range_low}, 0);
    $regref->{range_high_p1} = $regref->{pack}->addr_const_vec(1);
    $regref->{range_high_p1}->add( $regref->{range_high_p1}, $regref->{range_high}, 0);
}

sub check {
    my $regref = shift;
    #print ::Dumper($regref);
    $regref->check_name();
    $regref->check_addrtext();
    $regref->check_range_spacing();
    # Computes after all checks
    $regref->computes();
    $regref->check_end();
}

sub computes {
    my $regref = shift;
    # Computes rely on check() being correct
    if (!defined $regref->{addr_end}) {
	# addr_end = addr + 4 + ((spacing * (ents - 1)))
	my $inc = $regref->{pack}->addr_const_vec(1);
        $inc->subtract($regref->{range_ents}, $inc, 0);
	$inc->Multiply($regref->{spacing}, $inc);
	$regref->{ent_size} = $regref->{pack}->addr_const_vec($regref->{typeref}{words}*4);
	$inc->add($inc, $regref->{ent_size}, 0);
	$inc->add($regref->{addr}, $inc, 0);
	$regref->{addr_end} = $inc;
    }
}

sub check_end {
    my $regref = shift;
    if ($regref->{addr_end_wildcard}) {
	($regref->{addr_end}->Lexicompare($regref->{addr_end_wildcard}) < 0)
	    or $regref->warn ("Register exceeds upper boundary in wildcarded declaration: ", $regref->{addr_end}," ", $regref->{addr_end_wildcard}, "\n");
    }
}

sub dump {
    my $self = shift;
    my $fh = shift || \*STDOUT;
    my $indent = shift||"  ";
    print $fh +($indent,"Reg: ",$self->{name},
		" addr:",$self->{addrtext}||'',
		"\n");
}

######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::Register - Register object

=head1 SYNOPSIS

    use SystemC::Vregs;

=head1 DESCRIPTION

This package contains a blessed hash object for each register
definition.

=head1 FIELDS

These fields may be specified with the new() function, and accessed
via the self hash: $self->{field}.

=over 4

=item addrtext

Textual form of the address of the register.

=item spacing

Spacing of each register in a range, normally 4 bytes.

=item range

Entry range a ram covers, for example [7:0].

=item name

Name of the object.

=item pack

Reference to the package (SystemC::Vregs) object self is a member of.

=back

=head1 DERIVED FIELDS

These fields are valid only after check() is called.

=over 4

=item addr

Address of the register.

=item addr_end

Ending address of the register.

=back

=head1 METHODS

=over 4

=item new

Creates a new register object.

=item check

Checks the object for errors, and parses to create derived fields.

=back

=head1 DISTRIBUTION

The latest version is available from CPAN and from L<http://www.veripool.com/>.

Copyright 2001-2004 by Wilson Snyder.  This package is free software; you
can redistribute it and/or modify it under the terms of either the GNU
Lesser General Public License or the Perl Artistic License.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=head1 SEE ALSO

L<SystemC::Vregs>

=cut

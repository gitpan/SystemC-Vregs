# $Id: Bit.pm 49231 2008-01-03 16:53:43Z wsnyder $
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

package SystemC::Vregs::Bit;
use SystemC::Vregs::Number;
use Bit::Vector::Overload;

use strict;
use vars qw ($VERSION %Keywords);
use base qw (SystemC::Vregs::Subclass);
$VERSION = '1.450';

foreach my $kwd (qw( w dw fieldsZero fieldsReset
		     ))
{ $Keywords{$kwd} = 1; }

######################################################################

#Fields:
#	{name}			Field name (Subclass)
#	{at}			File/line number (Subclass)
#	{pack}			Parent SystemC::Vregs ref
#	{typeref}		Parent SystemC::Vregs::Type ref
#	{desc}			Description
#	{bits}			Textlist of bits
#	{bitlist}[]		Array of each bit being set		
#	{access}		RW/R/W etc
#	{overlaps}		What fields can overlap
#	{type}			C++ type
#	{rst}			Reset value or 'x'
#	{rst_val}		{rst} as hex
# After check
#	{cast_needed}		True if C++ needs a cast to convert
#	{bitarray}[bit]{...}	Per bit info		

######################################################################

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(overlaps=>'',
				  @_);
    ($self->{typeref}) or die "%Error: No typeref,";
    # Enter each bit into the table
    $self->{typeref}{fields}{ $self->{name} } = $self;
    return $self;
}

sub DESTROY {
    my $self = shift;
    if ($self->{typeref}) {
	delete $self->{typeref}{fields}{$self->{name}};
    }
}
sub delete { $_[0]->DESTROY(); }
sub ignore {
    my $self = shift;
    return $self->{attributes}{Deleted};
}

sub attribute_value {
    my $self = shift;
    my $attr = shift;
    return $self->{attributes}{$attr} if defined $self->{attributes}{$attr};
    return $self->{typeref}->attribute_value($attr);
}

sub is_overlap_ok {
    my $self = shift;
    my $other = shift;
    # Return true if these two bitrefs can overlap
    return 1 if !$self || !$other;
    return 1 if lc $self->{overlaps}  eq "allowed";
    return 1 if lc $other->{overlaps} eq "allowed";
    return 1 if lc $self->{name} eq lc $other->{name};
    return 1 if lc $self->{overlaps}  eq lc $other->{name};
    return 1 if lc $other->{overlaps} eq lc $self->{name};
    return 1 if $self->ignore || $other->ignore;
    return 0;
}

sub check_desc {
    my $self = shift;
    $self->{overlaps} = $1 if ($self->{desc} =~ /\boverlaps\s+([a-zA-Z0-9_]+)/i);
    $self->{desc} = $self->clean_sentence($self->{desc});
    ($self->{desc}) or $self->warn("Empty description, please document it.\n");
}

sub check_name {
    my $self = shift;
    my $field = $self->{name};
    $field =~ s/^_//g;

    if ($self->{typeref}->attribute_value('allowunder')) {
	($field =~ /^[A-Z][A-Za-z0-9_]*$/)
	    or $self->warn ("Bit mnemonics must start with capitals and contain only alphanumerics or underscores.\n");
    } else {
	($field =~ /^[A-Z][A-Za-z0-9]*$/)
	    or $self->warn ("Bit mnemonics must start with capitals and contain only alphanumerics.\n");
    }
    $self->{name} = $field;
    my $lang = (SystemC::Vregs::Language::is_keyword(lc $field)
		|| ($Keywords{lc($field)} && "Vregs"));
    if ($lang && (lc $lang ne "verilog")) {
	# For now, we don't emit verilog structures, so don't burden the world
	$self->warn ("Name matches a $lang language keyword: ", lc $field, "\n");
    }
}

sub compute_type {
    my $self = shift;
    my $field = $self->{type};
    if (!defined $field || $field eq "") {
	if ($self->{bits} =~ /:/) {
	    if ($self->{numbits} > 64) {
		$field = 'uint'.$self->{numbits}.'_t';
		# probably a compile error, let the user deal with it
	    } elsif ($self->{numbits} > 32) {
		$field = 'uint64_t';
	    } else {
		$field = 'uint32_t';
	    }
	} else {
	    $field = 'bool';
	}
    }

    $self->{cast_needed}=1 if ($field !~ /^(bool|uint\d+_t)$/);
    #use Data::Dumper; $Data::Dumper::Maxdepth=1; print Dumper($self);

    $self->{type} = $field;
}

sub check_access {
    my $bitref = shift;
    my $field = $bitref->{access};

    my $l = "";
    $l = "L" if ($field =~ s/L//g);
    if ($field eq "R" || $field eq "RO" ) {
	$field = "R";	# Read only, no side effects
    } elsif ($field eq "RW" || $field eq "R/W") {
	$field = "RW";	# Read/Write
    } elsif ($field eq "W" || $field eq "WO") {
	$field = "W";	# Write only
    }
    $field =~ s/V//g;	# Volitile - for testing access only -- currently ignored
    $field = $field . $l;

    if ($field !~ /$SystemC::Vregs::Bit_Access_Regexp/o) {
        $bitref->warn ("Bit access must match ${SystemC::Vregs::Bit_Access_Regexp}: '$field'\n");
	$field = 'RW';
    }

    $bitref->{access} = $field;
}

sub check_rst {
    my $bitref = shift;
    my $typeref = $bitref->{typeref};
    my $field = $bitref->{rst};
    $field =~ s/0X/0x/;
    if ($field =~ /^0?x?[0-9a-f]+$/i) {
    } elsif ($field =~ /^FW-?0$/i) {
	$field = "FW0";
    } elsif ($field =~ /^0-?FW$/i) {
	$field = "FW0";
    } elsif ($field =~ /^FW-(\(.*\))$/i) {
	$field = "FW$1";
    } elsif ($field =~ /^x$/i || $field =~ /^N\/A$/i) {
	$field = "X";
    } elsif ($field =~ /^pin/i) {
	$field = "X";
    } elsif ($field =~ /^tbd$/i) {
	print "-Info: $typeref->{name}_$bitref->{bitmnem} TBD reset field value, assuming not reset.\n";
	$field = "X";
    } elsif ($field eq 'true') {
	$field = "1";
    } elsif ($field eq 'false') {
	$field = "0";
    } elsif ($field =~ /^[A-Z0-9_]+$/) {
	if (!$bitref->{type}) {
	    $bitref->warn ("Reset mnemonic, but no type: '$field'\n");
	} else {
	    my $mnemref = $bitref->{pack}->find_enum($bitref->{type});
	    if ($mnemref) {
		if (!$mnemref->find_value($field)) {
		    $bitref->warn("Field '$field' not found as member of enum '$bitref->{type}'\n");
		}
	    }
	    #else We could check for a valid enum, but are they all in this document?
	}
    } else {
        $bitref->warn ("Strange reset field definition: '$field'\n");
	$field = "0";
    }
    $bitref->{rst} = $field;
}

sub check_bits {
    my $bitref = shift;
    my $field = $bitref->{bits};

    $field =~ s/[ \t]+//g;  $field = lc $field;
    $field =~ s/,,+//g; $field =~ s/,$//;
    $bitref->{bits} = $field;

    (defined $field && $field =~ /^[0-9wbdh]/) or $bitref->warn ("No bit range specified: '$field'\n");

    # Split w[15:0],w[21] into 15,14,13,...
    $bitref->{bitlist} = [];
    my $numbits=0;
    foreach my $subfield (split ",","$field,") {
	$subfield = "w0[${subfield}]" if $subfield !~ /\[/;
	foreach my $busbit (Verilog::Language::split_bus ($subfield)) {
	    my $bit;
	    if ($busbit =~ /^(b(\d+))\[(\d+)\]$/) {
		my $byte=$2; $bit=$3;
		$bit += $byte*8 if $byte;
	    }
	    elsif ($busbit =~ /^(h(\d+))\[(\d+)\]$/) {
		my $byte=$2; $bit=$3;
		$bit += $byte*16 if $byte;
	    }
	    elsif ($busbit =~ /^(w(\d+)|)\[(\d+)\]$/) {  # Default if no letter
		my $word=$2; $bit=$3;
		$bit += $word*32 if $word;
	    }
	    elsif ($busbit =~ /^(d(\d+))\[(\d+)\]$/) {
		my $word=$2; $bit=$3;
		$bit += $word*64 if $word;
	    }
	    else {
		$bitref->warn ("Strange bits selection: '$field': $busbit\n");
		return;
	    }
	    push @{$bitref->{bitlist}}, $bit;
	    $numbits++;
	}
    }
    ($numbits) or $bitref->warn ("Register without bits\n");
    $bitref->{numbits} = $numbits;
    #print "bitdecode '$field'=> @{$bitref->{bitlist}}\n";

    # Encode bits back into extents and ranges
    $bitref->{bitlist_range} = [];
    $bitref->{bitlist_range_32} = [];
    foreach my $thirtytwo (0 .. 1) {
	my @blist;
	my $msb = -1;
	my $lastbit = -1;
	my $tobit = $bitref->{numbits};
	foreach my $bit (@{$bitref->{bitlist}}, -1) {
	    if ($bit != $lastbit-1
		|| ($thirtytwo && (31==($bit % 32)))	# Don't let a range span different 32 bit words
		|| $bit == -1
		) {
		if ($msb>=0) {
		    #print " rangeadd $msb $lastbit $bit\n";
		    push @blist, [$msb, $lastbit, $msb-$lastbit+1, $tobit];
		}
		$msb = $bit;
	    }
	    $lastbit = $bit;
	    $tobit--;
	}
	$bitref->{bitlist_range_32} = \@blist if $thirtytwo;
	$bitref->{bitlist_range}    = \@blist if !$thirtytwo;
    }
}

######################################################################

sub dewildcard {
    my $bitref = shift;
    return if !$bitref->{expand};

    print "type_expand_field $bitref->{name}\n" if $SystemC::Vregs::Debug;
    my $ityperef = $bitref->{pack}->find_type($bitref->{type});
    if (!$ityperef) {
	$bitref->warn("Can't find class $bitref->{type} for bit marked as 'Expand Class'\n");
	return;
    }

    # Copy the expanded type's fields directly into this class, minding the bit offsets
    foreach my $ibitref (values %{$ityperef->{fields}}) {
	my $newname = $bitref->{name}.$ibitref->{name};
	# Compute what bit numbers the new structure gets
	$bitref->check_bits;  # So we get bistlist
	$ibitref->check_bits;  # So we get bistlist
	my $bits="";
	my $basebit = $bitref->{bitlist_range}[0][1];
	defined $basebit or $bitref->warn("No starting bit specified for base structure\n");
        foreach my $bitrange (@{$ibitref->{bitlist_range}}) {
	    my ($msb,$lsb,$nbits,$srcbit) = @{$bitrange};
	    $bits .= ($msb+$basebit).":".($lsb+$basebit).",";
	}
	#print "$newname $bitref->{bitlist_range}[0]\n" if $SystemC::Vregs::Debug;
	print "$newname $basebit $bits\n" if $SystemC::Vregs::Debug;
	my $overlaps = $ibitref->{overlaps};
	$overlaps = ($bitref->{name}.$overlaps) if $overlaps && $overlaps ne "allowed";
	my $newref = SystemC::Vregs::Bit->new
	    (%{$ibitref},  # Clone attributes, etc
	     pack=>$bitref->{pack},
	     name=>$newname,
	     typeref=>$bitref->{typeref},
	     expanded_super=>$bitref->{name},
	     expanded_sub=>$ibitref->{name},
	     bits=>$bits,
	     );
	$newref->{desc} =~ s/(\boverlaps\s+)([a-zA-Z0-9_]+)/$1$overlaps/i if $overlaps;
	#print "REG $newref->{name}  ol $overlaps\n";

	# Cleanup the bitlist
	$newref->check_bits;
    }

    # Eliminate ourself
    $bitref->delete();
}

sub computes {
    my $bitref = shift;
    {
	my $access = $bitref->{access};
	$bitref->{access_last} = 	 (($access =~ /L/) ? 1:0);
	$bitref->{access_read} =     	 (($access =~ /R/) ? 1:0);
	$bitref->{access_read_side} = 	 (($access =~ /R[^W]*S/) ? 1:0);
	$bitref->{access_write} = 	 (($access =~ /W/) ? 1:0);
	$bitref->{access_write_side} =	 (($access =~ /(W[^R]*S|W1C)/) ? 1:0);
    }

    $bitref->{fw_reset} = 1 if ($bitref->{rst} =~ /^FW/ && $bitref->{access} =~ /W/);
    $bitref->{comment} = sprintf ("%5s %4s %3s: %s",
				  $bitref->{bits}, $bitref->{access}, $bitref->{rst}, $bitref->{desc});
}

sub computes_type {
    # Computes that associate a bit with a type
    # These need to be done on any inherited types also
    my $bitref = shift;
    my $typeref = shift or die;

    # Access fields that affect the register itself
    $typeref->{access_last} = 1 if $bitref->{access_last};
    $typeref->{access_read} = 1      if $bitref->{access_read};
    $typeref->{access_read_side} = 1  if $bitref->{access_read_side};
    $typeref->{access_write_side} = 1  if $bitref->{access_write_side};

    my $bitsleft = $bitref->{numbits}-1;
    foreach my $bit (@{$bitref->{bitlist}}) {
	#print "Use $bit $bitref->{name}\n";

	my $prevuser = $typeref->{bitarray}[$bit];
	if ($prevuser) {
	    $prevuser = $prevuser->{bitref};
	    if (!$bitref->is_overlap_ok($prevuser)) {
		$bitref->warn ("Bit $bit defined twice in register ($bitref->{name} and $prevuser->{name})\n"
			       ."Perhaps you need a 'Overlaps $bitref->{name}.' in $prevuser->{name}'s description\n");
	    }
	}

	my $rstvec = undef;	# undef means unknown (x)
	my $rst = $bitref->{rst};
	if ($rst eq "X" || $rst =~ /^FW/) {
	    $rstvec = undef;
	} elsif ($rst eq "0") {
	    $rstvec = 0;
	    $bitref->{rst_val} = 0;
	} elsif ($rst =~ /^0x[0-9a-f]+$/i) {
	    my $value = hex $rst;
	    $bitref->{rst_val} = $value;
	    $rstvec = (($value & (1<<($bitsleft))) ? 1:0);
	} elsif ($rst =~ /^[0-9_]+$/i) {
	    (my $value = $rst) =~ s/_//g;
	    $bitref->{rst_val} = $value;
	    $rstvec = (($value & (1<<($bitsleft))) ? 1:0);
	} elsif ($rst =~ /^[A-Z][A-Z0-9_]*$/) {
	    $rstvec = 0;
	    my $mnemref = $bitref->{pack}->find_enum($bitref->{type});
	    $mnemref or $bitref->warn("Enum '$bitref->{type}' not found\n");
	    if ($mnemref) {
		my $vref = $mnemref->find_value($rst);
		if (!$vref) {
		    $bitref->warn("Field '$rst' not found as member of enum '$bitref->{type}'\n");
		}
		$bitref->{rst_val} = $vref->{rst_val};
		$rstvec = 1 if ($vref->{rst_val} & (1<<$bitsleft));
	    }
	} else {
	    $bitref->warn ("Odd reset form: $rst\n");
	}

	# Save info for every bit in the register
	$bitref->{bitarray}[$bit] = $typeref->{bitarray}[$bit]
	    = { bitref=>$bitref,
		write => $bitref->{access_write},
		read  => $bitref->{access_read},
		write_side => $bitref->{access_write_side},
		read_side  => $bitref->{access_read_side},
		rstvec => $rstvec,
	    };
	$bitsleft--;
    } # each bit
}

sub check {
    my $self = shift;
    $self->check_desc();
    $self->check_name();
    $self->check_access();
    $self->check_rst();
    $self->check_bits();
    # Computes rely on check() being correct
    $self->computes();
    $self->compute_type();
}

sub remove_if_mismatch {
    my $self = shift;
    my $test_cb = shift;
    if ($test_cb->($self)) {
	$self->delete;
	return 1;
    }
    return undef;
}

sub dump {
    my $self = shift;
    my $fh = shift || \*STDOUT;
    my $indent = shift||"  ";
}

######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::Bit - Bit object

=head1 SYNOPSIS

    use SystemC::Vregs;

=head1 DESCRIPTION

This package contains a blessed hash object for each bit field in a
SystemC::Vregs::Type.

=head1 FIELDS

These fields may be specified with the new() function, and accessed
via the self hash: $self->{field}.

=over 4

=item access

RW/R/W access for the field, from the access column of the field definition.

=item bits

The bits the field occupies, from the bit column in the field definition.

=item desc

Description comment for the object.

=item name

Name of the object.

=item overlaps

A string indicating what bitfields may be overlapped by this field.  From
parsing the description column of the field for "overlaps allowed" strings.

=item pack

Reference to the package (SystemC::Vregs) object self is a member of.

=item rst

Reset value from the reset column of the field definition.

=item type

Type of the field, from the type column of the field definition.

=back

=head1 DERIVED FIELDS

These fields are valid only after check() is called.

=over 4

=item bitarray

A array, with one entry for each bit number (0..31).  Each entry contains a
hash with the bit field reference and status on that bit.

=back

=head1 METHODS

=over 4

=item new

Creates a new bit object.

=item check

Checks the object for errors, and parses to create derived Fields.

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

L<SystemC::Vregs>

=cut

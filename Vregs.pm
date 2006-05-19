# $Id: Vregs.pm 20440 2006-05-19 13:46:40Z wsnyder $
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

package SystemC::Vregs;
use SystemC::Vregs::Number;

use SystemC::Vregs::TableExtract;
use SystemC::Vregs::Enum;
use SystemC::Vregs::Define;
use SystemC::Vregs::Register;
use SystemC::Vregs::Number;
use SystemC::Vregs::Rules;
use SystemC::Vregs::Output::Layout;
use strict;
use Carp;
use vars qw ($Debug $VERSION
	     $Bit_Access_Regexp %Ignore_Keywords);
use base qw (SystemC::Vregs::Subclass);	# In Vregs:: so we can get Vregs->warn()

$VERSION = '1.420';

######################################################################
#### Constants

# Regexp matching valid bit access
$Bit_Access_Regexp = '^(RS?|)(WS?|W1CS?|)L?'."\$";

# Loaded by user programs to prevent keyword warnings
%Ignore_Keywords = ();

######################################################################
######################################################################
######################################################################
######################################################################
#### Creation

#Fields:
#	{name}			Field name (Subclass)
#	{at}			File/line number (Subclass)
#	{address_bits}
#	{data_bits}
#	{rebuild_comment}
#	{attributes}{<attr>}{<value>}
#	{libraries}[]		SystemC::Vregs ref
#	{rules}			SystemC::Vregs::Rules ref
#	{enums}{<enum>}		SystemC::Vregs::Enum ref
#	{types}{<enum>}		SystemC::Vregs::Type ref
#	{regs}{<enum>}		SystemC::Vregs::Regs ref
#	{defines}{<enum>}	SystemC::Vregs::Define ref

sub new {
    my $class = shift;
    my $self = {address_bits => 32,
		data_bits => 32,	# Changing this isn't verified
		rebuild_comment => undef,
		attributes => {
		    # v2k => 0,		# Use localparam instead of parameter
		},
		comments => 1,
		protect_rdwr_only => 1,
		@_};
    bless $self, $class;
    $self->{rules} = new SystemC::Vregs::Rules (package => $self, );
    # Calculations
    $self->{data_bytes} = $self->{data_bits}/8;
    return $self;
}

sub addr_text_to_vec {
    my $self = shift;
    my $text = shift;
    return SystemC::Vregs::Number::text_to_vec
	($self->{address_bits}, $text);
}

sub addr_const_vec {
    my $self = shift;
    my $num = shift;
    return Bit::Vector->new_Dec($self->{address_bits}, $num);
}

######################################################################
#### Access

sub find_define {
    my $pack = shift;
    my $name = shift;
    foreach my $packref ($pack, @{$pack->{libraries}}) {
	my $regref = $packref->{defines}{$name};
	return $regref if $regref;
    }
    return undef;
}
sub find_enum {
    my $pack = shift;
    my $name = shift;
    foreach my $packref ($pack, @{$pack->{libraries}}) {
	my $enumref = $packref->{enums}{$name};
	return $enumref if $enumref;
    }
    return undef;
}
sub find_type {
    my $pack = shift;
    my $name = shift;
    foreach my $packref ($pack, @{$pack->{libraries}}) {
	my $typeref = $packref->{types}{$name};
	return $typeref if $typeref;
    }
    return undef;
}
sub find_type_regexp {
    my $pack = shift;
    my $regexp = shift;
    my @list;
    foreach my $packref ($pack, @{$pack->{libraries}}) {
	foreach my $matchref (values %{$packref->{types}}) {
	    if ($matchref->{name} =~ /$regexp/) {
		push @list, $matchref;
	    }
	}
    }
    return @list;
}
sub find_reg {
    my $pack = shift;
    my $name = shift;
    foreach my $packref ($pack, @{$pack->{libraries}}) {
	my $regref = $packref->{regs}{$name};
	return $regref if $regref;
    }
    return undef;
}
sub find_reg_regexp {
    my $pack = shift;
    my $regexp = shift;
    my @list;
    foreach my $packref ($pack, @{$pack->{libraries}}) {
	foreach my $matchref (values %{$packref->{regs}}) {
	    if ($matchref->{name} =~ /$regexp/) {
		push @list, $matchref;
	    }
	}
    }
    return @list;
}

sub regs_sorted {
    my $pack = shift;
    return (sort {($a->{addr} && $b->{addr} && $a->{addr}->Lexicompare($b->{addr}))
		      || $a->{name} cmp $b->{name}}
	    (values %{$pack->{regs}}));
}
sub types_sorted {
    my $pack = shift;
    return (sort {($b->{subclass_level} <=> $a->{subclass_level})
		      || ($a->{inherits_level} <=> $b->{inherits_level})
		      || ($a->{name} cmp $b->{name})}
	    (values %{$pack->{types}}));
}
sub enums_sorted {
    my $pack = shift;
    return (sort {$a->{name} cmp $b->{name}}
	    (values %{$pack->{enums}}));
}
sub defines_sorted {
    my $pack = shift;
    return (sort {$a->{sort_key} cmp $b->{sort_key}}
	    (values %{$pack->{defines}}));
}

sub attribute_value {
    my $self = shift;
    my $attr = shift;
    return $self->{attributes}{$attr} if defined $self->{attributes}{$attr};
    return undef;
}

######################################################################
#### html parsing

sub html_read {
    my $self = shift;
    my $filename = shift;

    my $te = new SystemC::Vregs::TableExtract(depth=>0, );
    $te->{_vregs_pack} = $self;
    $te->parse_file($filename);
}

sub three_way_replace {
    my $orig_name = shift;
    my $orig_inh = shift;
    my $sub_name = shift;
    # Take "FOO*", "BAR*", and "BARBAZ" and return "FOOBAZ"

    $orig_name =~ /^([^*]*)[*]$/ or die "%Error: Missing * in original name: $orig_name";
    my $orig_name_prefix = $1;
    $orig_inh =~ /^([^*]*)[*]$/ or die "%Error: Missing * in inherit name: $orig_inh";
    my $orig_inh_prefix = $1;
    my $new_name = substr($sub_name,length($orig_inh_prefix));
    return ($orig_name_prefix . $new_name);
}

######################################################################
#### Declaring registers/enums

sub new_package {
    my $self = shift;
    my $bittableref = shift;  my @bittable = @{$bittableref};
    my $flagref = shift;	# Hash of {heading} = value_of_heading
    # Create a new package

    ($flagref->{Package}) or die;
    (!$self->{_got_package_decl}) or return $self->warn($flagref, "Multiple Package attribute sections, previous at $self->{_got_package_decl}.\n");

    my $attr = $flagref->{Attributes}||"";
    while ($attr =~ s/-(\w+)//) {
	$self->{attributes}{$1} = 1;
	print "PACK ATTR -$1\n" if $Debug;
	$self->{_got_package_decl} = $flagref->{at};
    }
    ($attr =~ /^\s*$/) or $self->warn($flagref, "Strange attributes $attr\n");
}

sub new_item {
    my $self = $_[0];
    my $bittableref = $_[1];
    my $flagref = $_[2];	# Hash of {heading} = value_of_heading
    #Create a new register/class/enum, called from the html parser
    print "new_item:",::Dumper(\$flagref, $bittableref) if $SystemC::Vregs::TableExtract::Debug;

    if ($flagref->{Register}) {
	new_register (@_);
    } elsif ($flagref->{Class}) {
	new_register (@_);
    } elsif ($flagref->{Enum}) {
	new_enum (@_);
    } elsif ($flagref->{Defines}) {
	new_define (@_);
    } elsif ($flagref->{Package}) {
	new_package (@_);
    }
}

sub new_define {
    my $self = shift;
    my $bittableref = shift;  my @bittable = @{$bittableref};
    my $flagref = shift;	# Hash of {heading} = value_of_heading
    # Create a new enumeration
    return if $#bittable<0;   # Empty list of defines

    #print ::Dumper(\$flagref, $bittableref);
    ($flagref->{Defines}) or die;
    my $defname = $flagref->{Defines};
    $defname .= "_" if $defname ne "" && $defname !~ /_$/;
    $defname = "" if $defname eq "_";

    my ($const_col, $mnem_col, $def_col)
	 = _choose_columns ($flagref,
			    [qw(Constant Mnemonic Definition)],
			    $bittable[0]);
    defined $const_col or return $self->warn ($flagref, "Define table is missing column headed 'Constant'\n");
    defined $mnem_col  or return $self->warn ($flagref, "Define table is missing column headed 'Mnemonic'\n");
    defined $def_col   or return $self->warn ($flagref, "Define table is missing column headed 'Definition'\n");

    foreach my $row (@bittable) {
	 print "  Row:\n" if $Debug;
	 foreach my $col (@$row) {
	     print "    Ent:$col\n" if $Debug;
	     if (!defined $col) {
		 $self->warn ($flagref, "Column ".($col+1)." is empty\n");
	     }
	 }
	 next if $row eq $bittable[0];	# Ignore header

	 my $val_mnem = $row->[$mnem_col];
	 my $desc     = $row->[$def_col];

	 # Skip blank/reserved values
	 next if ($val_mnem eq "" && ($desc eq "" || $desc =~ /^reserved/i));

	 # Check for empty field
	 my $defref = new SystemC::Vregs::Define::Value
	     (pack => $self,
	      name => $defname . $val_mnem,
	      rst  => $row->[$const_col],
	      desc => $desc,
	      is_manual => 1,
	      );
    }
}

sub new_enum {
    my $self = shift;
    my $bittableref = shift;  my @bittable = @{$bittableref};
    my $flagref = shift;	# Hash of {heading} = value_of_heading
    # Create a new enumeration

    ($flagref->{Enum}) or die;
    my $classname = $flagref->{Enum};

    my ($const_col, $mnem_col, $def_col)
	= _choose_columns ($flagref,
			   [qw(Constant Mnemonic Definition)],
			   $bittable[0]);
    defined $const_col or return $self->warn ($flagref, "Enum table is missing column headed 'Constant'\n");
    defined $mnem_col  or return $self->warn ($flagref, "Enum table is missing column headed 'Mnemonic'\n");
    defined $def_col   or return $self->warn ($flagref, "Enum table is missing column headed 'Definition'\n");

    my $classref = new SystemC::Vregs::Enum
	(pack => $self,
	 name => $classname,
	 at => $flagref->{at},
	 );

    my $attr = $flagref->{Attributes}||"";
    while ($attr =~ s/-(\w+)//) {
	$classref->{attributes}{$1} = 1;
    }
    ($attr =~ /^\s*$/) or $self->warn($flagref, "Strange attributes $attr\n");

    foreach my $row (@bittable) {
	print "  Row:\n" if $Debug;
	foreach my $col (@$row) {
	    print "    Ent:$col\n" if $Debug;
	    if (!defined $col) {
		$self->warn ($flagref, "Column ".($col+1)." is empty\n");
	    }
	}
	next if $row eq $bittable[0];	# Ignore header

	my $val_mnem = $row->[$mnem_col];
	my $desc     = $row->[$def_col];
	$val_mnem =~ s/\([^\)]*\)\s*//;	# Strip (comment)
	$desc =~ s/\([^\)]*\)\s*//;	# Strip (comment)

	# Skip blank/reserved values
	next if ($val_mnem eq "" && ($desc eq "" || $desc =~ /^reserved/i));

	# Check for empty field
	my $valref = new SystemC::Vregs::Enum::Value
	    (pack => $self,
	     name => $val_mnem,
	     class => $classref,
	     rst  => $row->[$const_col],
	     desc => $desc,
	     );


	# Take special user defined fields and add to table
	for (my $colnum=0; $colnum<=$#{$bittable[0]}; $colnum++) {
	    my $col = $bittable[0][$colnum];
	    $col =~ s/\s+//;
	    if ($col =~ /^\s*\(([a-zA-Z_0-9]+)\)\s*$/) {
		my $var = $1;
		my $val = $row->[$colnum]||"";
		$val =~ s/\s*\([^\)]*\)//g;
		$valref->{attributes}{$var} = $val if $val =~ /^([a-zA-Z._:0-9]+)$/;
	    }
	}
    }
}

sub new_register {
    my $self = shift;
    my $bittableref = shift;  my @bittable = @{$bittableref};
    my $flagref = shift;	# Hash of {heading} = value_of_heading
    # Create a new register

    my $classname = $flagref->{Register} || $flagref->{Class};
    (defined $classname) or die;

    #print "new_register!\n",::Dumper(\$flagref,\@bittable);

    my $range = "";
    $range = $1 if ($classname =~ s/(\[[^\]]+])//);
    $classname =~ s/\s+$//;

    my $is_register = ($flagref->{Register} || $flagref->{Address});
    
    my $inherits = "";
    if ($classname =~ s/\s*:\s*(\S+)$//) {
	$inherits = $1;
    }

    my $attr = $flagref->{Attributes}||"";
    return if $attr =~ /noimplementation/;

    my $typeref = new SystemC::Vregs::Type
	(pack => $self,
	 name => $classname,
	 at => $flagref->{at},
	 is_register => $is_register,	# Ok, perhaps I should have made a superclass
	 );
    $typeref->inherits($inherits);

    # See also $typeref->{attributes}{lcfirst}, below.
    while ($attr =~ s/-([a-zA-Z_0-9]+)\s*=?\s*([a-zA-Z._0-9]+)?//) {
	$typeref->{attributes}{$1} = (defined $2 ? $2 : 1);
    }
    ($attr =~ /^\s*$/) or $self->warn($flagref, "Strange attributes $attr\n");

    if ($is_register) {
	# Declare a register
	($classname =~ /^[R]_/) or return $self->warn($flagref, "Strange mnemonic name, doesn't begin with R_");

	my $addr = $flagref->{Address};
	my $spacingtext = 0;
	$spacingtext = $self->{data_bytes} if $range;
	if (!$addr) {
	    $self->warn ($flagref, "No 'Address' Heading Found\n");
	    return;
	}
	$addr =~ s/[()]//g;
	$addr =~ s/\s*plus\s*base\s*address\s*//;
	$addr =~ s/\s*per\s+entry//g;
	if ($addr =~ s/\s*Add\s*(0x[a-f0-9_]+)\s*//i) {
	    $spacingtext = $1;
	}

	my $regref = new SystemC::Vregs::Register
	    (pack => $self,
	     typeref => $typeref,
	     name => $classname,
	     at => $flagref->{at},
	     addrtext => $addr,
	     spacingtext => $spacingtext,
	     range => $range,
	     );
    }

    if (defined $bittable[0] || !$inherits) {
	my ($bit_col, $mnem_col, $type_col, $def_col,
	    $acc_col, $rst_col,
	    $const_col,
	    $size_col)
	    = _choose_columns ($flagref,
			       [qw(Bit Mnemonic Type Definition),
				qw(Access Reset),	# Register decls
				qw(Constant),	# Class declarations
				qw(Size),		# Ignored Optionals
				],
			       $bittable[0]);
	$rst_col ||= $const_col;
	defined $bit_col or  return $self->warn ($flagref, "Table is missing column headed 'Bit'\n");
	defined $mnem_col or return $self->warn ($flagref, "Table is missing column headed 'Mnemonic'\n");
	defined $def_col or  return $self->warn ($flagref, "Table is missing column headed 'Definition'\n");
	if ($is_register) {
	    defined $rst_col or  return $self->warn ($flagref, "Table is missing column headed 'Reset'\n");
	    defined $acc_col or  return $self->warn ($flagref, "Table is missing column headed 'Access'\n");
	}

	# Table by table, allow the field mnemonics to be either 'fooFlag'
	# (per our Coding Conventions) or 'FooFlag' (as in a Vregs ASCII file).

	my $allMnems_LCFirst = (@bittable > 1);
	foreach my $row (@bittable) {
	    next if $row eq $bittable[0];	# Ignore header
	    my $bit_mnem = $row->[$mnem_col] or next;
	    my $c1 = substr($bit_mnem, 0, 1);
	    if ($c1 ge 'A' && $c1 le 'Z') { $allMnems_LCFirst = 0; }
	}
	if ($allMnems_LCFirst) {
	    print "  Upcasing first letter of mnemonics.\n" if $Debug;
	    foreach my $row (@bittable) {
		next if $row eq $bittable[0];	# Ignore header
		my $bit_mnem = $row->[$mnem_col] or next;
		$row->[$mnem_col] = ucfirst $bit_mnem;
	    }
	    $typeref->{attributes}{lcfirst} = 1;
	}

	foreach my $row (@bittable) {
	    print "  Row:\n" if $Debug;
	    foreach my $col (@$row) {
		print "    Ent:$col\n" if $Debug;
		if (!defined $col) {
		    $self->warn ($flagref, "Column ".($col+1)." is empty\n");
		}
	    }
	    next if $row eq $bittable[0];	# Ignore header

	    # Check for empty field
	    my $bit_mnem = $row->[$mnem_col];
	    $bit_mnem =~ s/^_//;
	    my $desc = $row->[$def_col];

	    my $overlaps = "";
	    $overlaps = $1 if ($desc =~ /\boverlaps\s+([a-zA-Z0-9_]+)/i);

	    # Skip empty fields
	    if (($bit_mnem eq "" || $bit_mnem eq '-')
		&& ($desc eq "" || $desc =~ /Reserved/ || $desc=~/Hardwired/
		    || $desc =~ /^(\/\/|\#)/)) {	# Allow //Comment or #Comment
		next;
	    }
	    if ((!defined $bit_col || $row->[$bit_col] eq "")
		&& (!defined $mnem_col || $row->[$mnem_col] eq "")
		&& (!defined $rst_col || $row->[$rst_col] eq "")
		) {
		next;	# All blank lines (excl comment) are fine.
	    }

	    my $rst = defined $rst_col ? $row->[$rst_col] : "";
	    $rst = 'X' if ($rst eq "" && !$is_register);

	    my $type = defined $type_col && $row->[$type_col];

	    (!$typeref->{fields}{$bit_mnem}) or
		$self->warn ($typeref->{fields}{$bit_mnem}, "Field defined twice in spec\n");
	    my $bitref = new SystemC::Vregs::Bit
		(pack => $self,
		 name => $bit_mnem,
		 typeref => $typeref,
		 bits => $row->[$bit_col],
		 access => (defined $acc_col ? $row->[$acc_col] : 'RW'),
		 overlaps => $overlaps,
		 rst  => $rst,
		 desc => $row->[$def_col],
		 type => $type,
		 expand => ($type && $desc =~ /expand class/i)?1:undef,
		 );

	    # Take special user defined fields and add to table
	    for (my $colnum=0; $colnum<=$#{$bittable[0]}; $colnum++) {
		my $col = $bittable[0][$colnum];
		$col =~ s/\s+//;
		if ($col =~ /^\s*\(([a-zA-Z_0-9]+)\)\s*$/) {
		    my $var = $1;
		    my $val = $row->[$colnum]||"";
		    $val =~ s/\s*\([^\)]*\)//g;
		    $bitref->{attributes}{$var} = $val if $val =~ /^([a-zA-Z._:0-9]+)$/;
		}
	    }
	}
    }
}

######################################################################
#### Parsing

sub _choose_columns {
    my $flagref = shift;
    my $fieldref = shift;
    my $headref = shift;
    # Look for the columns with the given headings.  Require them to exist.

    my @collist;
    my @colused = ();
    my @colheads;
    # The list is short, so this is faster then forming a hash.
    # If things get wide, this may change
    for (my $h=0; $h<=$#{$headref}; $h++) {
	$colheads[$h] = $headref->[$h];
	if ($colheads[$h] =~ s/\s*\(.*\)\s*//) {
	    # Strip comments in the header
	    # Allow ignoring these columns entirely
	    #print "HR $h '$headref->[$h]'  '$colheads[$h]'\n";
	}
	$colused[$h] = 1 if $colheads[$h] eq "";
    }
  headchk:
    foreach my $fld (@{$fieldref}) {
	for (my $h=0; $h<=$#{$headref}; $h++) {
	    if ($fld eq $colheads[$h]) {
		push @collist, $h;
		$colused[$h] = 1;
		next headchk;
	    }
	}
	push @collist, undef;
    }

    my $ncol = 0;
    for (my $h=0; $h<=$#{$headref}; $h++) {
	$ncol = $h+1 if !$colused[$h];
    }
    
    if ($ncol) {
        SystemC::Vregs::Subclass::warn ($flagref, "Column ".($ncol-1)." found with unknown header.\n");
	print "Desired column headers: '",join("' '",@{$fieldref}),"'\n";
	print "Found   column headers: '",join("' '",@{$headref}),"'\n";
	print "Defined:("; foreach (@collist) { print (((defined $_)?$_:'-'),' '); }
	print ")\n";
	print "Used:   ("; foreach (@colused) { print ((($_)?'Y':'-'),' '); }
	print ")\n";
    }

    return (@collist);
}

######################################################################
#### Reading files

sub regs_read {
    my $self = shift;
    my $filename = shift;


    my $fh = new IO::File ($filename) or die "%Error: $! $filename\n";

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
	    print "#FILE '$filename'\n" if $Debug;
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
		(pack => $self,
		 name => $classname,
		 at => "${filename}:$.",
		 addrtext => $addr,
		 spacingtext => $spacingtext,
		 range => $range,
		 );
	}
	elsif ($line =~ /^type\s+(\S+)\s*(.*)$/ ) {
	    my $typemnem = $1; my $flags = $2;
	    my $inh = "";
	    $inh = $1 if ($flags =~ s/:(\S+)//); 
	    $typemnem =~ s/^Vregs//;
	    $typemnem =~ s/_t$//;
	    $typeref = new SystemC::Vregs::Type
		(pack => $self,
		 name => $typemnem,
		 at => "${filename}:$.",
		 );
	    $typeref->inherits($inh);
	    _regs_read_attributes($typeref, $flags);
	    $regref->{typeref} = $typeref if $regref && $typemnem =~ /^R_/;
	    $regref = undef;
	}
	elsif ($line =~ /^bit\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+([^\"]*)"(.*)"$/ ) {
	    if (!$typeref) {
		die "%Error: $filename:$.: bit without previous type declaration\n";;
	    }
	    my $bit_mnem = $1;
	    my $bits = $2; my $acc = $3; my $type = $4; my $rst = $5; my $flags=$6; my $desc=$7;
	    my $bitref = new SystemC::Vregs::Bit
		(pack => $self,
		 name => $bit_mnem,
		 typeref => $typeref,
		 bits => $bits,
		 access => $acc,
		 rst  => $rst,
		 desc => $desc,
		 type => $type,
	     );
	    _regs_read_attributes($bitref, $flags);
	}
	elsif ($line =~ /^enum\s+(\S+)\s*(.*)$/) {
	    my $name = $1; my $flags = $2;
	    $classref = new SystemC::Vregs::Enum
		(pack => $self,
		 name => $name,
		 at => "${filename}:$.",
		 );
	    _regs_read_attributes($classref, $flags);
	}
	elsif ($line =~ /^const\s+(\S+)\s+(\S+)\s+([^\"]*)"(.*)"$/ ) {
	    my $name = $1;  my $rst=$2;  my $flags=$3;  my $desc=$4;
	    my $bitref = new SystemC::Vregs::Enum::Value
		(pack => $self,
		 name => $name,
		 class => $classref,
		 rst  => $rst,
		 desc => $desc,
		 at => "${filename}:$.",
		 );
	    _regs_read_attributes($bitref, $flags);
	}
	elsif ($line =~ /^define\s+(\S+)\s+(\S+)\s+"(.*)"$/ ) {
	    my $name = $1;  my $rst=$2;  my $desc=$3;
	    new SystemC::Vregs::Define::Value
		(pack => $self,
		 name => $name,
		 rst  => $rst,
		 desc => $desc,
		 is_manual => 1,
		 at => "${filename}:$.",
		 );
	}
	elsif ($line =~ /^package\s+(\S+)\s*(.*)$/ ) {
	    my $flags = $2;
	    $self->{name} = $1;
	    $self->{at} = "${filename}:$.";
	    _regs_read_attributes($self, $flags);
	}
	else {
	    die "%Error: $fileline: Can't parse \"$line\"\n";
	}
    }

    ($got_a_line) or die "%Error: File empty or cpp error in $filename\n";

    $fh->close();
}

sub _regs_read_attributes {
    my $obj = shift;
    my $flags = shift;

    $flags = " $flags ";
    $obj->{attributes}{$1} = $2 while ($flags =~ s/\s-([a-zA-Z][a-zA-Z0-9_]*)=([^ \t]*)\s/ /);
    $obj->{attributes}{$1} = 1  while ($flags =~ s/\s-([a-zA-Z][a-zA-Z0-9_]*)\s/ /);
    ($flags =~ /^\s*$/) or $obj->warn ("Unparsable attributes setting: '$flags'");
}

sub regs_read_check {
    my $self = shift;
    $self->regs_read(@_);
    $self->check();
    $self->exit_if_error();
}

sub rules_read {
    my $self = shift;
    my $filename = shift;
    $self->{rules}->read ($filename) if -r $filename;
}

######################################################################
#### Checks/Cleanups

sub check {
    my $self = shift;

    # Eliminate wildcarding
    foreach my $typeref (values %{$self->{types}}) {
	$typeref->dewildcard();
    }
    foreach my $regref (values %{$self->{regs}}) {
	$regref->dewildcard();
    }

    # Check enums first; type checking requires enums
    foreach my $defref ($self->defines_sorted) {
	$defref->check();
    }
    foreach my $enumref (values %{$self->{enums}}) {
	$enumref->check();
    }
    # Sorted, as we want to do base classes first
    foreach my $typeref ($self->types_sorted) {
	$typeref->check();
    }
    foreach my $regref (values %{$self->{regs}}) {
	$regref->check();
    }
    #use Data::Dumper; print Dumper($self);
}

######################################################################
######################################################################
#### Defines

sub _force_mask {
    my $pack = shift;
    my $mask = shift;
    # Return new mask which assumes power-of-2 alignment of all registers
    my $bit;
    for ($bit=$pack->{address_bits}-1; $bit>=1; --$bit) {  # Ignore bits 1&0
	if ($mask->bit_test($bit)) {
	    last;
	}
    }
    for (; $bit>=0; --$bit) {
	$mask->Bit_On($bit);
    }
    return $mask;
}

sub _valid_mask {
    my $pack = shift;
    my $addr = shift;
    my $mask = shift;

    # if (($addr & ~$mask) != $addr)
    my $a = Bit::Vector->new($pack->{address_bits});
    my $b = Bit::Vector->new($pack->{address_bits});
    $a->Complement($mask);
    $b->Intersection($a,$addr);
    return 0 if !$b->equal($addr);

    my $one = 1;
    for (my $bit=0; $bit<$pack->{address_bits}; $bit++) {
	if ($mask->bit_test($bit)) {
	    return 0 if !$one;
	} else {
	    $one = 0;
	}
    }
    return 1;
}

sub SystemC::Vregs::Type::_create_defines {
    my $typeref = shift;

    # Make size alias
    (my $nor_mnem  = $typeref->{name}) =~ s/^R_//;
    new_push SystemC::Vregs::Define::Value
	(pack => $typeref->{pack},
	 name => "CSIZE_".$nor_mnem,
	 rst_val  => $typeref->{words}*$typeref->{pack}{data_bytes},
	 is_verilog => 1,	# In C++ use Class::SIZE
	 is_perl => 1,
	 desc => "Class Size", );

    if ($typeref->{name} =~ /^R_/) {
	for (my $word=0; $word<$typeref->{words}; $word++) {
	    my $wr_mask = 0;
	    for (my $bit=$word*$typeref->{pack}->{data_bits};
		 $bit<(($word+1)*$typeref->{pack}->{data_bits});
		 $bit++) {
		my $bitent = $typeref->{bitarray}[$bit];
		next if !$bitent;
		$wr_mask  |= (1<<$bit) if ($bitent->{write});
	    }
	    my $wd=""; $wd=$word if $word;
	    new_push SystemC::Vregs::Define::Value
		(pack => $typeref->{pack},
		 name => "CM${wd}_".$nor_mnem."_WRITABLE",
		 rst_val  => sprintf("%08X",$wr_mask,),
		 bits=>$typeref->{pack}->{data_bits},
		 is_verilog => 1,	# In C++ use Class::BITMASK_WRITABLE
		 desc => "Writable mask", );
	}
    }

    # Make bit alias
    foreach my $bitref (values %{$typeref->{fields}}) {
	next if $bitref->ignore;
	{   # Wide-word defines
	    my $rnum = 0;  $rnum = 1 if $#{$bitref->{bitlist_range}};
	    foreach my $bitrange (reverse @{$bitref->{bitlist_range}}) {
		$bitref->_create_defines_range ($typeref, $bitrange, $rnum++, 1);
	    }
	}

	# Multi-word defines
	if ($typeref->{words}>1) {
	    my $rnum = 0;  $rnum = 1 if $#{$bitref->{bitlist_range_32}};
	    foreach my $bitrange (reverse @{$bitref->{bitlist_range_32}}) {
		$bitref->_create_defines_range ($typeref, $bitrange, $rnum++, 0);
	    }
	}
    }
}

sub SystemC::Vregs::Bit::_create_defines_range {
    my $bitref = shift;
    my $typeref = shift;
    my $bitrange = shift;
    my $rnum = shift;
    my $wideword = shift;

    my ($msb,$lsb,$nbits,$srcbit) = @{$bitrange};
    my $bit_mnem = $bitref->{name};
    my $comment  = $bitref->{comment};
    (my $nor_mnem  = $typeref->{name}) =~ s/^R_//;

    # For multi-ranged fields, we append a _1 for the first range, _2, ...
    my $rstr = ""; $rstr = "_".$rnum if $rnum;

    # For multi-word structures, make verilog defines that include
    # the word number, and subtract 32* that value.  This allows for
    # easy extraction using multiple busses and/or multi-cycle transactions.
    for (my $word=-1; $word<$typeref->{words}; $word++) {
	# word=-1 indicates we are making the wide structure
	next if $word==-1 && !$wideword;
	next if $word!=-1 &&  $wideword;
	my $wstr = "";  $wstr = $word if $word>=0;

	# If a single field in word #0, CR0_ would be the same as a CR_, so suppress
	next if $msb<32 && $word!=-1 && $rnum==0;

	if ($word==-1
	    || ($msb>=($word*32) && $msb<($word*32+32))
	    || ($lsb>=($word*32) && $lsb<($word*32+32))) {
	    my $wlsb = $lsb;
	    my $wmsb = $msb;
	    $wlsb -= $word*32 if $word!=-1;
	    $wmsb -= $word*32 if $word!=-1;

	    new_push SystemC::Vregs::Define::Value
		(pack => $typeref->{pack},
		 name => "CR${wstr}_".$nor_mnem."_".$bit_mnem.$rstr,
		 rst_val => $wmsb.":".$wlsb,
		 is_verilog => 1,
		 desc => "Field Bit Range: $comment", );
	    new_push SystemC::Vregs::Define::Value
		(pack => $typeref->{pack},
		 name => "CB${wstr}_".$nor_mnem."_".$bit_mnem.$rstr,
		 rst_val => $wlsb,
		 desc => "Field Start Bit: $comment", );
	    new_push SystemC::Vregs::Define::Value
		(pack => $typeref->{pack},
		 name => "CE${wstr}_".$nor_mnem."_".$bit_mnem.$rstr,
		 rst_val  => $wmsb,
		 desc => "Field End Bit:   $comment", );
	    if ($wstr eq "" && $typeref->{attributes}{macros_32_bits}) {
		new_push SystemC::Vregs::Define::Value
		    (pack => $typeref->{pack},
		     name => "CBSZ${wstr}_".$nor_mnem."_".$bit_mnem.$rstr,
		     rst_val => $wmsb - $wlsb + 1,
		     desc => "Field Bit Size: $comment", );
	    }
	}
    }
    for (my $bitwidth=8; $bitwidth<=256; $bitwidth *=2) {
	my $bitword = int($lsb/$bitwidth);
	my $wlsb = $lsb - $bitword*$bitwidth;
	my $wmsb = $msb - $bitword*$bitwidth;
	if ($typeref->{attributes}{"macros_${bitwidth}_bits"}) {
	    new_push SystemC::Vregs::Define::Value
		(pack => $typeref->{pack},
		 name => "CRW${bitwidth}_".$nor_mnem."_".$bit_mnem.$rstr,
		 rst_val => $wmsb.":".$wlsb,
		 is_verilog => 1,
		 desc => "Field Bit Range for ${bitwidth}-bit extracts", );
	    new_push SystemC::Vregs::Define::Value
		(pack => $typeref->{pack},
		 name => "CAW${bitwidth}_".$nor_mnem."_".$bit_mnem.$rstr,
		 rst_val => $bitword,
		 desc => "Field Word Number for ${bitwidth}-bit extracts", );
	}
    }
    if ($bitref->{numbits}>1 && $bitref->{rst_val}) {
	new_push SystemC::Vregs::Define::Value
	    (pack => $typeref->{pack},
	     name => "CRESET_${nor_mnem}_${bit_mnem}",
	     rst_val => sprintf("%x",$bitref->{rst_val}),
	     bits => $bitref->{numbits},
	     is_verilog => 1,
	     desc => "Field Reset", );
    }
}

sub SystemC::Vregs::Enum::_create_defines {
    my $self = shift;

    foreach my $fieldref ($self->fields_sorted()) {
	new_push SystemC::Vregs::Define::Value
	    (pack => $self->{pack},
	     name => "E_".$self->{name}."_".$fieldref->{name},
	     bits => $fieldref->{bits},
	     rst_val => sprintf("%x",$fieldref->{rst_val}),
	     desc => "Enum Value: $fieldref->{desc}", );
    }
}

sub create_defines {
    my $pack = shift;
    my $skip_if_done = shift;
    # Make define addresses

    return if ($skip_if_done && $pack->{defines_computed});
    $pack->{defines_computed} = 1;

    my $bit4 = $pack->addr_const_vec($pack->{data_bytes});
    my $bit32 = $pack->addr_const_vec(0xffffffff);

    foreach my $regref ($pack->regs_sorted()) {
	my $classname   = $regref->{name};
	(my $nor_mnem  = $classname) =~ s/^R_//;
	my $addr       = $regref->{addr};
	my $spacing    = $regref->{spacing};
	my $range      = $regref->{range};
	my $range_high = $regref->{range_high};
	my $range_low  = $regref->{range_low};

	# Make master alias
	new_push SystemC::Vregs::Define::Value
	    (pack => $pack,
	     name => "RA_".$nor_mnem,
	     val => $addr,
	     rst_val => $addr->to_Hex, bits => $pack->{address_bits},
	     desc => "Address of $classname", );

	if ($range ne "" || 1) {
	    new_push SystemC::Vregs::Define::Value
		(pack => $pack,
		 name => "RAE_".$nor_mnem,
		 rst_val => $regref->{addr_end}->to_Hex,
		 bits => $pack->{address_bits},
		 desc => "Ending Address of Register + 1", );
	    new_push SystemC::Vregs::Define::Value
		(pack => $pack,
		 name => "RAC_".$nor_mnem,
		 rst_val => $regref->{range_ents},
		 bits => (($regref->{range_ents}->Lexicompare($bit32) > 0)
			  ? $pack->{address_bits} : 32),
		 desc => "Number of entries", );

	    if (! $regref->{spacing}->equal($bit4)) {
		new_push SystemC::Vregs::Define::Value
		    (pack => $pack,
		     name => "RRP_".$nor_mnem,
		     rst_val => $regref->{spacing}->to_Hex,
		     bits => $pack->{address_bits},
		     desc => "Range spacing", );
	    }
	}

	if ($range ne "" || $regref->{typeref}{words}>1) {
	    my $wordspace = $regref->{pack}->addr_const_vec($regref->{typeref}{words}*4);
	    if ($regref->{spacing}->equal($wordspace)) {
		my $val = Bit::Vector->new($regref->{pack}{address_bits});
		$val->subtract($regref->{addr_end},$addr,0);  #end-start
		new_push SystemC::Vregs::Define::Value
		    (pack => $pack,
		     name => "RRS_".$nor_mnem,
		     rst_val => $val->to_Hex,
		     bits => (($val != 0) ? $pack->{address_bits} : 32),
		     desc => "Range byte size", );
	    } else {
		new_push SystemC::Vregs::Define::Value
		    (pack => $pack,
		     name => "RRS_".$nor_mnem,
		     rst_val => "Non_Contiguous",
		     desc => "Range byte size: This register region contains gaps.");
	    }

	    my $delta = Bit::Vector->new($regref->{pack}{address_bits});
	    $delta->subtract($regref->{addr_end},$addr,1);  #end-start-1
	    if (_valid_mask ($pack, $addr, $delta)) {
		new_push SystemC::Vregs::Define::Value
		    (pack => $pack,
		     name => "RAM_".$nor_mnem,
		     rst_val => $delta->to_Hex,
		     bits => $pack->{address_bits},
		     desc => "Address Mask");
	    } else {
		# We could just leave it out, but that leads to a lot of "bug"
		# reports about the define being missing!
		new_push SystemC::Vregs::Define::Value
		    (pack => $pack,
		     name => "RAM_".$nor_mnem,
		     rst_val => "Not_Aligned",
		     desc => "Address Mask: This register is not naturally aligned, so a mask will not work.");
	    }
	}

	# If small range, make a alias per range
	if ($range ne ""
	    && $regref->{range_ents} < 17) {
	    for (my $range_val=$range_low; $range_val <= $range_high; $range_val++) {
		my $range_addr = Bit::Vector->new_Dec($regref->{pack}{address_bits},
						      $regref->{spacing} * $range_val);
		$range_addr->add($regref->{addr}, $range_addr, 0);
		new_push SystemC::Vregs::Define::Value
		    (pack => $pack,
		     name => "RA_".$nor_mnem.$range_val,
		     val => $range_addr,
		     rst_val => $range_addr->to_Hex,
		     bits => $regref->{pack}{address_bits},
		     desc => "Address of Entry ${classname}${range_val}", );
	    }
	}
    }

    my %moddef = ();
    foreach my $regref ($pack->regs_sorted()) {
	my $classname   = $regref->{name};
	(my $nor_mnem  = $classname) =~ s/^R_//;
	for (my $str=$nor_mnem; $str=~s/[A-Z][a-z0-9_]*$//;) {
	    #print "$nor_mnem\t$str\t",$regref->{addr},"\n";
	    next if $str eq "";
	    $moddef{$str}{count}++;
	    $moddef{$str}{addr}
	    = SystemC::Vregs::Number::min($moddef{$str}{addr},$regref->{addr});
	    $moddef{$str}{addr_end}
	    = SystemC::Vregs::Number::max($moddef{$str}{addr_end},$regref->{addr_end});
	}
    }

    foreach my $nor_mnem (sort (keys %moddef)) {
	my $modref = $moddef{$nor_mnem};
	next if $modref->{count} < 2;
	my $addr = $modref->{addr};
	my $addr_end = $modref->{addr_end};
	#print "$nor_mnem\t$addr\t$addr_end\n";

	# Make master alias
	new_push SystemC::Vregs::Define::Value
	    (pack => $pack,
	     name => "RBASEA_".$nor_mnem,
	     val => $addr,
	     rst_val => $addr->to_Hex, bits => $pack->{address_bits},
	     desc => "Base address of $nor_mnem registers", );
	new_push SystemC::Vregs::Define::Value
	    (pack => $pack,
	     name => "RBASEAE_".$nor_mnem,
	     val => $addr_end,
	     rst_val => $addr_end->to_Hex, bits => $pack->{address_bits},
	     desc => "Base address of $nor_mnem registers", );
	my $delta = Bit::Vector->new($pack->{address_bits});
	$delta->subtract($modref->{addr_end},$addr,1);  #end-start-1
	$delta = _force_mask ($pack, $delta);
	new_push SystemC::Vregs::Define::Value
	    (pack => $pack,
	     name => "RBASEAM_".$nor_mnem,
	     rst_val => $delta->to_Hex,
	     bits => $pack->{address_bits},
	     desc => "Address Mask (may be forced to power-of-two)");
    }

    foreach my $typeref ($pack->types_sorted) {
	$typeref->_create_defines();
    }

    foreach my $classref ($pack->enums_sorted) {
	$classref->_create_defines();
    }
}

######################################################################
######################################################################
#### Diags

sub dump {
    my $self = shift;
    my $fh = shift || \*STDOUT;
    my $indent = shift||"  ";
    print $fh $indent,"Pack: ",$self->{name},"\n";
    foreach my $typeref (values %{$self->{types}}) {
	$typeref->dump($fh,$indent."  ");
    }
    foreach my $regref (values %{$self->{regs}}) {
	$regref->dump($fh,$indent."  ");
    }
    foreach my $enumref (values %{$self->{enums}}) {
	$enumref->dump($fh,$indent."  ");
    }
    foreach my $defref ($self->defines_sorted) {
	$defref->dump($fh,$indent."  ");
    }
}

######################################################################
######################################################################
#### Saving

sub regs_write {
    # Dump register definitions
    my $self = shift;
    my $filename = shift;
    return SystemC::Vregs::Output::Layout->new->write
	(filename => $filename,
	 keep_timestamp => 1,
	 pack => $self,
	 );
}

######################################################################
#### Package return
package Vregs;
1;
__END__

=pod

=head1 NAME

SystemC::Vregs - Utility routines used by vregs

=head1 SYNOPSIS

  use SystemC::Vregs;

=head1 DESCRIPTION

A Vregs object contains a documentation "package" containing enumerations,
definitions, classes, and registers.

=head1 METHODS

See also SystemC::Vregs::Output::* for details on functions that write out
various header files.

=over 4

=item new

Creates a new Vregs package object and returns a reference to it.  The name
of the package should be passed as a "name" named parameter, likewise the
number of address bits should be passed as address_bits.

=item check

Checks the object for errors, and parses the object to create some derived
fields.

=item defines_sorted

Returns list of SystemC::Vregs::Define objects.

=item enums_sorted

Returns list of SystemC::Vregs::Enum objects.

=item exit_if_error

Exits if any errors were detected by check().

=item find_define

Returns SystemC::Vregs::Define object with a name matching the passed
parameter, or undef if not found.

=item find_enum

Returns SystemC::Vregs::Enum object with a name matching the passed
parameter, or undef if not found.

=item find_type

Returns SystemC::Vregs::Type object with a name matching the passed
parameter, or undef if not found.

=item find_type_regexp

Returns list of SystemC::Vregs::Type objects with a name matching the
passed wildcard, or undef if not found.

=item html_read

Reads the specified HTML filename, and creates internal objects.

=item regs_read

Reads the specified .vregs filename, and creates internal objects.

=item regs_read_check

Calls the normal sequence of commands to read a known-good vregs file;
regs_read, check, and exit_if_error.

=item regs_sorted

Returns list of SystemC::Vregs::Register objects.

=item regs_write

Creates the specified .vregs filename.

=item types_sorted

Returns list of SystemC::Vregs::Type objects.

=back

=head1 DISTRIBUTION

The latest version is available from CPAN and from L<http://www.veripool.com/>.

Copyright 2001-2006 by Wilson Snyder.  This package is free software; you
can redistribute it and/or modify it under the terms of either the GNU
Lesser General Public License or the Perl Artistic License.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=head1 SEE ALSO

L<vreg>,
L<SystemC::Vregs::Rules>

Low level objects:

L<SystemC::Vregs::Bit>,
L<SystemC::Vregs::Define>,
L<SystemC::Vregs::Enum>,
L<SystemC::Vregs::Language>,
L<SystemC::Vregs::Number>,
L<SystemC::Vregs::Register>,
L<SystemC::Vregs::Subclass>,
L<SystemC::Vregs::TableExtract>,
L<SystemC::Vregs::Type>
L<SystemC::Vregs::Output::Class>,
L<SystemC::Vregs::Output::Defines>,
L<SystemC::Vregs::Output::Hash>,
L<SystemC::Vregs::Output::Info>,
L<SystemC::Vregs::Output::Param>

=cut

# $Id: Vregs.pm,v 1.49 2001/06/27 16:10:19 wsnyder Exp $
# Author: Wilson Snyder <wsnyder@wsnyder.org>
######################################################################
#
# This program is Copyright 2001 by Wilson Snyder.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of either the GNU General Public License or the
# Perl Artistic License, with the exception that it cannot be placed
# on a CD-ROM or similar media for commercial distribution without the
# prior approval of the author.
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

package SystemC::Vregs;
use SystemC::Vregs::Number;

use SystemC::Vregs::TableExtract;
use SystemC::Vregs::Enum;
use SystemC::Vregs::Define;
use SystemC::Vregs::Register;
use SystemC::Vregs::Number;
use SystemC::Vregs::Rules;
use strict;
use Carp;
use vars qw($Debug $Bit_Access_Regexp @ISA $VERSION);
@ISA = qw (SystemC::Vregs::Subclass);	# In Vregs:: so we can get Vregs->warn()

$VERSION = '0.1';

######################################################################
#### Constants

# Regexp matching valid bit access
$Bit_Access_Regexp = '^(R|RW|W|RS|RSW|RWS|RSWS|RW1C|WS)L?'."\$";

######################################################################
######################################################################
######################################################################
######################################################################
#### Creation

sub new {
    my $class = shift;
    my $self = {address_bits => 32,
		data_bits => 32,	# Changing this isn't verified
		rebuild_comment => undef,
		attributes => {},
		@_};
    bless $self, $class;
    $self->{rules} = new SystemC::Vregs::Rules (package => $self, );
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

sub find_enum {
    my $pack = shift;
    my $typename = shift;
    foreach my $packref ($pack, @{$pack->{libraries}}) {
	my $enumref = $packref->{enums}{$typename};
	return $enumref if $enumref;
    }
    return undef;
}
sub find_type {
    my $pack = shift;
    my $typename = shift;
    foreach my $packref ($pack, @{$pack->{libraries}}) {
	my $enumref = $packref->{types}{$typename};
	return $enumref if $enumref;
    }
    return undef;
}

sub regs_sorted {
    my $pack = shift;
    return (sort {$a->{addr}->Lexicompare($b->{addr})}
	    (values %{$pack->{regs}}));
}
sub types_sorted {
    my $pack = shift;
    return (sort {($a->{inherits_level} <=> $b->{inherits_level})
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

######################################################################
#### html parsing

sub html_read {
    my $self = shift;
    my $filename = shift;

    my $te = new SystemC::Vregs::TableExtract(depth=>0, );
    $te->{_vregs_pack} = $self;
    $te->parse_file($filename);
}

######################################################################
#### Declaring registers/enums

sub new_package {
    my $self = shift;
    my $bittableref = shift;  my @bittable = @{$bittableref};
    my $flagref = shift;	# Hash of {heading} = value_of_heading
    # Create a new package

    ($flagref->{Package}) or die;
    (!$self->{_got_package_decl}) or return $self->warn($flagref, "Multiple Package attribute sections.\n");
    $self->{_got_package_decl} = 1;

    my $attr = $flagref->{Attributes}||"";
    while ($attr =~ s/-(\w+)//) {
	$self->{attributes}{$1} = $1;
	print "PACK ATTR -$1\n" if $Debug;
    }
    ($attr =~ /^\s*$/) or $self->warn($flagref, "Strange attributes $attr\n");
}

sub new_item {
    my $self = $_[0];
    my $bittableref = $_[1];
    my $flagref = $_[2];	# Hash of {heading} = value_of_heading
    #Create a new register/class/enum, called from the html parser
    #print ::Dumper(\$flagref, $bittableref);

    $flagref->{Register} = $flagref->{Class} if $flagref->{Class};
    if ($flagref->{Register}) {
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

    #print ::Dumper(\$flagref, $bittableref);
    ($flagref->{Defines}) or die;
    my $defname = $flagref->{Defines};
    $defname .= "_" if $defname ne "" && $defname !~ /_$/;
    $defname = "" if $defname eq "_";

    my ($const_col, $mnem_col, $def_col)
	 = _choose_columns ($flagref,
			    [qw(Constant Mnemonic Definition)],
			    $bittable[0]);
    defined $const_col or return $self->warn ($flagref, "Table is missing column headed 'Constant'\n");
    defined $mnem_col  or return $self->warn ($flagref, "Table is missing column headed 'Mnemonic'\n");
    defined $def_col   or return $self->warn ($flagref, "Table is missing column headed 'Definition'\n");

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

    #print ::Dumper(\$flagref, $bittableref);
    ($flagref->{Enum}) or die;
    my $classname = $flagref->{Enum};

    my ($const_col, $mnem_col, $def_col)
	= _choose_columns ($flagref,
			   [qw(Constant Mnemonic Definition)],
			   $bittable[0]);
    defined $const_col or return $self->warn ($flagref, "Table is missing column headed 'Constant'\n");
    defined $mnem_col  or return $self->warn ($flagref, "Table is missing column headed 'Mnemonic'\n");
    defined $def_col   or return $self->warn ($flagref, "Table is missing column headed 'Definition'\n");

    my $classref = new SystemC::Vregs::Enum
	(pack => $self,
	 name => $classname,
	 at => $flagref->{at},
	 );

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
	my $valref = new SystemC::Vregs::Enum::Value
	    (pack => $self,
	     name => $val_mnem,
	     class => $classref,
	     rst  => $row->[$const_col],
	     desc => $desc,
	     );
    }
}

sub new_register {
    my $self = shift;
    my $bittableref = shift;  my @bittable = @{$bittableref};
    my $flagref = shift;	# Hash of {heading} = value_of_heading
    # Create a new register

    ($flagref->{Register}) or die;
    my $classname = $flagref->{Register};

    #print "new_register!\n",::Dumper(\$flagref,\@bittable);

    my $range = "";
    $range = $1 if ($classname =~ s/(\[[^\]]+])//);
    $classname =~ s/\s+$//;

    my $is_register = ($classname =~ /^R_/ || $flagref->{Address});
    
    my $inherits = "";
    if ($classname =~ s/\s*:\s*(\S+)$//) {
	$inherits = $1;
    }

    my $typeref = new SystemC::Vregs::Type
	(pack => $self,
	 name => $classname,
	 at => $flagref->{at},
	 is_register => $is_register,	# Ok, perhaps I should have made a superclass
	 );
    $typeref->inherits($inherits);

    my $attr = $flagref->{Attributes}||"";
    while ($attr =~ s/-(\w+)//) {
	$typeref->{attributes}{$1} = $1;
    }
    ($attr =~ /^\s*$/) or $self->warn($flagref, "Strange attributes $attr\n");

    if ($is_register) {
	# Declare a register
	($classname =~ /^[R]_/) or return $self->warn($flagref, "Strange mnemonic name, doesn't begin with R_");

	my $addr = $flagref->{Address};
	my $spacingtext = 0;
	$spacingtext = 4 if $range;
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
	defined $rst_col or  return $self->warn ($flagref, "Table is missing column headed 'Reset'\n");
	defined $def_col or  return $self->warn ($flagref, "Table is missing column headed 'Definition'\n");
	if ($is_register) {
	    defined $acc_col or  return $self->warn ($flagref, "Table is missing column headed 'Access'\n");
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

	    my $rst = $row->[$rst_col];
	    $rst = 'X' if ($rst eq "" && !$is_register);
	    my $bitref = new SystemC::Vregs::Bit
		(pack => $self,
		 name => $bit_mnem,
		 typeref => $typeref,
		 bits => $row->[$bit_col],
		 access => (defined $acc_col ? $row->[$acc_col] : 'RW'),
		 overlaps => $overlaps,
		 rst  => $rst,
		 desc => $row->[$def_col],
		 type => defined $type_col && $row->[$type_col],
		 );

	    # Enter each bit into the table
	    $typeref->{fields}{$bit_mnem} = $bitref;
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
    my $ncol;
    # The list is short, so this is faster then forming a hash.
    # If things get wide, this may change
    for (my $h=0; $h<=$#{$headref}; $h++) {
	$headref->[$h] =~ s/\s*\(.*\)//;	# Strip comments in the header
    }
  headchk:
    foreach my $fld (@{$fieldref}) {
	for (my $h=0; $h<=$#{$headref}; $h++) {
	    if ($fld eq $headref->[$h]) {
		push @collist, $h;
		$ncol++;
		next headchk;
	    }
	}
	push @collist, undef;
    }
    if ($ncol != $#{$headref}+1) {
        SystemC::Vregs::Subclass::warn ($flagref, "Extra columns found:\n");
	print "Desired column headers: '",join("' '",@{$fieldref}),"'\n";
	print "Found   column headers: '",join("' '",@{$headref}),"'\n";
	print "("; foreach (@collist) { print (((defined $_)?$_:'-'),' '); }
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
	    $typeref->{attributes}{$1} = 1 while ($flags =~ s/-([a-z]+)\b//);
	    $regref->{typeref} = $typeref if $regref;
	    ($flags =~ /^\s*$/) or $typeref->warn("$fileline: Bad flags \"$flags\"\n");
	}
	elsif ($line =~ /^bit\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+"(.*)"$/ ) {
	    if (!$typeref) {
		die "%Error: $filename:$.: bit without previous type declaration\n";;
	    }
	    my $bit_mnem = $1;
	    my $bits = $2; my $acc = $3; my $type = $4; my $rst = $5; my $desc = $6;
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
	    $typeref->{fields}{$bit_mnem} = $bitref;
	}
	elsif ($line =~ /^enum\s+(\S+)$/) {
	    my $name = $1;
	    $classref = new SystemC::Vregs::Enum
		(pack => $self,
		 name => $name,
		 at => "${filename}:$.",
		 );
	}
	elsif ($line =~ /^const\s+(\S+)\s+(\S+)\s+"(.*)"$/ ) {
	    my $name = $1;  my $rst=$2;  my $desc=$3;
	    new SystemC::Vregs::Enum::Value
		(pack => $self,
		 name => $name,
		 class => $classref,
		 rst  => $rst,
		 desc => $desc,
		 at => "${filename}:$.",
		 );
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
	elsif ($line =~ /^package\s+(\S+)\s*(\S*)$/ ) {
	    my $flags = $2;
	    $self->{name} = $1;
	    $self->{attributes}{$1} = 1 while ($flags =~ s/-([a-z]+)\b//);
	}
	else {
	    die "%Error: $fileline: Can't parse \"$line\"\n";
	}
    }

    ($got_a_line) or die "%Error: File empty or cpp error in $filename\n";

    $fh->close();
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

sub _valid_mask {
    my $regref = shift;
    my $addr = shift;
    my $mask = shift;

    # if (($addr & ~$mask) != $addr)
    my $a = Bit::Vector->new($regref->{pack}{address_bits});
    my $b = Bit::Vector->new($regref->{pack}{address_bits});
    $a->Complement($mask);
    $b->Intersection($a,$addr);
    return 0 if !$b->equal($addr);

    my $one = 1;
    for (my $bit=0; $bit<$regref->{pack}{address_bits}; $bit++) {
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

    # Make bit alias
    my $typemnem = $typeref->{name};
    (my $nor_mnem  = $typemnem) =~ s/^R_//;
    foreach my $bitref (values %{$typeref->{fields}}) {
	my $bit_mnem = $bitref->{name};
	my $comment  = $bitref->{comment};

	my $rnum = "";
	$rnum = 1 if ($#{$bitref->{bitlist_range}});
	foreach my $bitrange (@{$bitref->{bitlist_range}}) {
	    my ($msb,$lsb,$nbits,$srcbit) = @{$bitrange};
	    new_push SystemC::Vregs::Define::Value
		(pack => $typeref->{pack},
		 name => "CR${rnum}_".$nor_mnem."_".$bit_mnem,
		 rst_val => $msb.":".$lsb,
		 is_verilog => 1,
		 desc => "Field Bit Range: $comment", );
	    new_push SystemC::Vregs::Define::Value
		(pack => $typeref->{pack},
		 name => "CB${rnum}_".$nor_mnem."_".$bit_mnem,
		 rst_val => $lsb,
		 desc => "Field Start Bit: $comment", );
	    new_push SystemC::Vregs::Define::Value
		(pack => $typeref->{pack},
		 name => "CE${rnum}_".$nor_mnem."_".$bit_mnem,
		 rst_val  => $msb,
		 desc => "Field End Bit:   $comment", );
	    $rnum = ($rnum||0) + 1;
	}
    }
}

sub SystemC::Vregs::Enum::_create_defines {
    my $self = shift;

    foreach my $fieldref ($self->fields_sorted()) {
	new_push SystemC::Vregs::Define::Value
	    (pack => $self->{pack},
	     name => "E_".$self->{name}."_".$fieldref->{name},
	     bits => $fieldref->{bits},
	     rst_val => $fieldref->{rst_val},
	     desc => "Enum Value: $fieldref->{desc}", );
    }
}

sub create_defines {
    my $pack = shift;
    my $skip_if_done = shift;
    # Make define addresses

    return if ($skip_if_done && $pack->{defines_computed});
    $pack->{defines_computed} = 1;

    my $bit32 = $pack->addr_const_vec(0xffffffff);

    my %moddef = ();
    foreach my $regref ($pack->regs_sorted()) {
	my $classname   = $regref->{name};
	(my $nor_mnem  = $classname) =~ s/^R_//;
	my $addr       = $regref->{addr};
	my $spacing    = $regref->{spacing};
	my $range      = $regref->{range};
	my $range_high = $regref->{range_high};
	my $range_low  = $regref->{range_low};
	my $mod        = $regref->{mod};

#	 if (!defined $moddef{$mod}
#	     && (($addr & 0xfff00000) == ($Register_Base | 0x00f00000))) {
#	     push @defs, { 'define' => "RA_" . uc $mod,
#			   'value' => $addr & 0xffff0000, 'hex' => 1,
#			   'comment' => "Address of Module Base", };
#	     $moddef{$mod} = 1;
#	 }

	# Make master alias
	new_push SystemC::Vregs::Define::Value
	    (pack => $pack,
	     name => "RA_".$nor_mnem,
	     rst_val => $addr->to_Hex, bits => $pack->{address_bits},
	     desc => "Address of $classname", );

	if ($range ne "") {
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

	    my $delta = Bit::Vector->new($regref->{pack}{address_bits});
	    $delta->subtract($regref->{addr_end},$addr,1);  #end-start-1
	    if (_valid_mask ($regref, $addr, $delta)) {
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
		     desc => "Address Mask: This register is not natually aligned, so a mask will not work.");
	    }

	    # If small range, make a alias per range
	    if ($regref->{range_ents} < 17) {
		for (my $range_val=$range_low; $range_val <= $range_high; $range_val++) {
		    my $range_addr = Bit::Vector->new_Dec($regref->{pack}{address_bits},
							  $regref->{spacing} * $range_val);
		    $range_addr->add($regref->{addr}, $range_addr, 0);
		    new_push SystemC::Vregs::Define::Value
			(pack => $pack,
			 name => "RA_".$nor_mnem.$range_val,
			 rst_val => $range_addr->to_Hex,
			 bits => $regref->{pack}{address_bits},
			 desc => "Address of Entry ${classname}${range_val}", );
		}
	    }
	}
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
#### Saving

sub SystemC::Vregs::Bit::_vregs_write_type {
    my $self = shift;
    my $fh = shift;
    my $descflags = "";
    $descflags = ".  Overlaps $self->{overlaps}." if $self->{overlaps};

    printf $fh "\tbit\t%-13s %s\t%-4s %-11s %-11s \"%s%s\"\n"
	,$self->{name},$self->{bits},$self->{access}
        ,$self->{type},$self->{rst},$self->{desc},$descflags;
}

sub SystemC::Vregs::Type::_vregs_write_type {
    my $self = shift;
    my $fh = shift;
    print $fh "   type\t$self->{name}";
    if ($self->{inherits}) {
	print $fh "\t:$self->{inherits}";
    }
    foreach my $var (keys %{$self->{attributes}}) {
	print $fh "\t-$var";
    }
    print $fh "\n";
    foreach my $fieldref ($self->fields_sorted()) {
	$fieldref->_vregs_write_type($fh);
    }
}

sub regs_write {
    # Dump register definitions
    my $self = shift;
    my $filename = shift;

    my $fh = IO::File->new(">$filename") or croak "%Error: $! $filename.";

    print $fh "// DESCR"."IPTION: Register Layout: Generated by vregs\n";
    print $fh "//\n";
    print $fh "// Format:\n";
    print $fh "//\tpackage {name}\n";
    print $fh "//\treg   {name} {type}[vec] 0x{address} {spacing}\n";
    print $fh "//\ttype  {name}\n";
    print $fh "//\tbit   {name} {bits} {access} {type} {reset} {description}\n";
    print $fh "//\tenum  {name}\n";
    print $fh "//\tconst {name} {value} {description}\n";
    print $fh "\n";
    print $fh "package $self->{name}";
    foreach my $var (keys %{$self->{attributes}}) {
	print $fh "\t-$var";
    }
    print $fh "\n";
    print $fh "//Rebuild with: $self->{rebuild_comment}\n" if $self->{rebuild_comment};
    print $fh "\n";

    print $fh "//",'*'x70,"\n// Registers\n";
    my %printed;
    foreach my $regref ($self->regs_sorted) {
	my $classname = $regref->{name} || "x";
	my $addr = $regref->{addr};
	my $range = $regref->{range} || "";
	if (!defined $addr) {
	    print "%Error: No address defined: ${classname}\n";
	} else {
	    (my $nor = $classname) =~ s/^R_//;
	    my $type = "Vregs${nor}";
	    printf $fh "  reg\t$classname\t$type$range\t0x%s\t0x%s\t"
		, $addr->to_Hex, $regref->{spacing}->to_Hex;
	    print $fh "\n";

	    my $typeref = $regref->{typeref};
	    if (!$printed{$typeref}) {
		$printed{$typeref} = 1;
		$typeref->_vregs_write_type ($fh);
	    }
	}
    }

    print $fh "//",'*'x70,"\n// Classes\n";
    foreach my $typeref ($self->types_sorted) {
	if (!$printed{$typeref}) {
	    $printed{$typeref} = 1;
	    $typeref->_vregs_write_type ($fh);
	}
    }

    print $fh "//",'*'x70,"\n// Enumerations\n";
    foreach my $classref ($self->enums_sorted) {
	my $classname = $classref->{name} || "x";
	printf $fh "   enum\t$classname\n";
	    
	foreach my $fieldref ($classref->fields_sorted()) {
	    printf $fh "\tconst\t%-13s\t%s\t\"%s\"\n"
		,$fieldref->{name},$fieldref->{rst},$fieldref->{desc};
	}
    }

    print $fh "//",'*'x70,"\n// Defines\n";
    foreach my $fieldref ($self->defines_sorted) {
	next if !$fieldref->{is_manual};
	printf $fh "\tdefine\t%-13s\t%s\t\"%s\"\n"
	    ,$fieldref->{name},$fieldref->{rst},$fieldref->{desc};
    }

    $fh->close();

    print "Wrote $filename\n";
}

######################################################################
#### Package return
package Vregs;
1;
__END__

=pod

=head1 NAME

Vregs - Utility routines used by vregs

=head1 SYNOPSIS

  use Vregs;

=head1 DESCRIPTION

A Vregs object contains a documentation "package" containing enumerations,
definitions, classes, and registers.

=head1 METHODS

=over 4

See also SystemC::Vregs::Outputs for details on functions that write out
various header files.

=item new

Creates a new Vregs package object and returns a reference to it.  The name
of the package should be passed as a "name" named parameter, likewise the
number of address bits should be passed as address_bits.

=item check

Checks the object for errors, and parses the object to create some derrived
fields.

=item defines_sorted

Returns list of SystemC::Vregs::Define objects.

=item enums_sorted

Returns list of SystemC::Vregs::Enum objects.

=item exit_if_error

Exits if any errors were detected by check().

=item find_enum

Returns SystemC::Vregs::Enum object with a name matching the passed
parameter, or undef if not found.

=item find_type

Returns SystemC::Vregs::Type object with a name matching the passed
parameter, or undef if not found.

=item html_read

Reads the specified HTML filename, and creates internal objects.

=item regs_read

Reads the specified .vregs filename, and creates internal objects.

=item regs_write

Creates the specified .vregs filename.

=item types_sorted

Returns list of SystemC::Vregs::Type objects.


=back

=head1 SEE ALSO

C<vregs>
C<SystemC::Vregs::Rules>
C<SystemC::Vregs::Outputs>

Low level objects:

C<SystemC::Vregs::Bit>
C<SystemC::Vregs::Define>
C<SystemC::Vregs::Enum>
C<SystemC::Vregs::Language>
C<SystemC::Vregs::Number>
C<SystemC::Vregs::Register>
C<SystemC::Vregs::Subclass>
C<SystemC::Vregs::TableExtract>
C<SystemC::Vregs::Type>

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=cut

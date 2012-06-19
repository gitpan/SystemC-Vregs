# See copyright, etc in below POD section.
######################################################################

package SystemC::Vregs;
use SystemC::Vregs::Number;

use SystemC::Vregs::Enum;
use SystemC::Vregs::Define;
use SystemC::Vregs::Register;
use SystemC::Vregs::Number;
use SystemC::Vregs::Rules;
use SystemC::Vregs::Input::Layout;
use SystemC::Vregs::Input::HTML;
use SystemC::Vregs::Output::Layout;
use strict;
use Carp;
use vars qw ($Debug $VERSION
	     $Bit_Access_Regexp %Ignore_Keywords);
use base qw (SystemC::Vregs::Subclass);	# In Vregs:: so we can get Vregs->warn()

$VERSION = '1.470';

######################################################################
#### Constants

# Regexp matching valid bit access
$Bit_Access_Regexp = '^(RS?|)(WS?|W1CS?|H|)L?'."\$";

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
#	{word_bits}
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
		word_bits => 32,	# Changing this isn't verified (change data_bits attribute instead)
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
    $self->{data_bytes} = $self->{word_bits}/8;
    return $self;
}

sub data_bits {
    my $self = shift;
    return $self->attribute_value("data_bits")||32;
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
    return (sort {(defined $a->{addr} && defined $b->{addr} && $a->{addr}->Lexicompare($b->{addr}))
		      || ( (defined $a->{addr} && !defined $b->{addr}) ? 1:0)  # IE any# > undef
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

    SystemC::Vregs::Input::HTML->new()->read
	(pack => $self,
	 filename => $filename);
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
#### Reading files

sub regs_read {
    my $self = shift;
    my $filename = shift;

    SystemC::Vregs::Input::Layout->new()->read
	(pack => $self,
	 filename => $filename);
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
#### Masking

sub remove_if_mismatch {
    my $self = shift;
    my $test_cb = shift || sub { return $self->is_mismatch($_[0]); };  # Default cb
    print "remove_if_mismatch($test_cb)\n" if $Debug;
    foreach my $typeref ($self->types_sorted) {
	$typeref->remove_if_mismatch($test_cb);
    }
    foreach my $regref ($self->regs_sorted) {  # Must do types before regs
	$regref->remove_if_mismatch($test_cb);
    }
    foreach my $enumref ($self->enums_sorted) {
	$enumref->remove_if_mismatch($test_cb);
    }
    foreach my $defref ($self->defines_sorted) {
	$defref->remove_if_mismatch($test_cb);
    }
}

sub is_mismatch {
    my $self = shift;
    my $itemref = shift;
    # Called by each object, return true if there's a mismatch
    my $mismatch;
    if (my $prod = $self->{if_product}) {
	if (my $itemprod = $itemref->attribute_value("Product")) {
	    $prod = lc $prod;
	    $itemprod = lc $itemprod;
	    #print "Prod check $prod =? $itemprod for $self->{name}\n";
	    if ($itemprod =~ /(.*)\+$/) {
		$mismatch = $prod lt $1;
	    } else {
		$mismatch = $prod ne $itemprod;
	    }
	    print "    ProductMismatch: deleting $itemref->{name}\n" if $mismatch && $Debug;
	}
    }
    return $mismatch;
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
    return if $typeref->attribute_value("nofielddefines");

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
	    for (my $bit=$word*$typeref->{pack}->{word_bits};
		 $bit<(($word+1)*$typeref->{pack}->{word_bits});
		 $bit++) {
		my $bitent = $typeref->{bitarray}[$bit];
		next if !$bitent;
		$wr_mask  |= (1<<($bit % $typeref->{pack}->{word_bits})) if ($bitent->{write});
	    }
	    my $wd=""; $wd=$word if $word;
	    new_push SystemC::Vregs::Define::Value
		(pack => $typeref->{pack},
		 name => "CM${wd}_".$nor_mnem."_WRITABLE",
		 rst_val  => sprintf("%08X",$wr_mask,),
		 bits=>$typeref->{pack}->{word_bits},
		 is_verilog => 1,	# In C++ use Class::BITMASK_WRITABLE
		 desc => "Writable mask", );
	}
    }

    # Make bit alias
    foreach my $bitref ($typeref->fields_sorted) {
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
		 desc => "Field Bit Range: $comment",
		 desc_trivial => 1,);
	    new_push SystemC::Vregs::Define::Value
		(pack => $typeref->{pack},
		 name => "CB${wstr}_".$nor_mnem."_".$bit_mnem.$rstr,
		 rst_val => $wlsb,
		 desc => "Field Start Bit: $comment",
		 desc_trivial => 0,);
	    new_push SystemC::Vregs::Define::Value
		(pack => $typeref->{pack},
		 name => "CE${wstr}_".$nor_mnem."_".$bit_mnem.$rstr,
		 rst_val  => $wmsb,
		 desc => "Field End Bit:   $comment",
		 desc_trivial => 1,);
	    if ($wstr eq "" && $typeref->{attributes}{macros_32_bits}) {
		new_push SystemC::Vregs::Define::Value
		    (pack => $typeref->{pack},
		     name => "CBSZ${wstr}_".$nor_mnem."_".$bit_mnem.$rstr,
		     rst_val => $wmsb - $wlsb + 1,
		     desc => "Field Bit Size: $comment",
		     desc_trivial => 1,);
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
		 desc => "Field Bit Range for ${bitwidth}-bit extracts",
		 desc_trivial => 1,);
	    new_push SystemC::Vregs::Define::Value
		(pack => $typeref->{pack},
		 name => "CAW${bitwidth}_".$nor_mnem."_".$bit_mnem.$rstr,
		 rst_val => $bitword,
		 desc => "Field Word Number for ${bitwidth}-bit extracts",
		 desc_trivial => 1,);
	}
    }
    if (($bitref->{numbits}>1 || $typeref->attribute_value("creset_one_bit"))
	&& ($bitref->{rst_val}
	    || ($typeref->attribute_value("creset_zero")
		&& (defined $bitref->{rst_val})))) {
	new_push SystemC::Vregs::Define::Value
	    (pack => $typeref->{pack},
	     name => "CRESET_${nor_mnem}_${bit_mnem}",
	     rst_val => sprintf("%x",$bitref->{rst_val}),
	     bits => $bitref->{numbits},
	     is_verilog => 1,
	     desc => "Field Reset",
	     desc_trivial => 1,);
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
	     desc => "Enum Value: $fieldref->{desc}",
	     desc_trivial => 0,);
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

	my $nofields = ($regref->attribute_value("nofielddefines")
			|| $regref->{typeref}->attribute_value("nofielddefines"));

	# Make master alias
	new_push SystemC::Vregs::Define::Value
	    (pack => $pack,
	     name => "RA_".$nor_mnem,
	     val => $addr,
	     rst_val => $addr->to_Hex, bits => $pack->{address_bits},
	     desc => "Address of $classname",
	     desc_trivial => 1,);

	if ($range ne "" || 1) {
	    new_push SystemC::Vregs::Define::Value
		(pack => $pack,
		 name => "RAE_".$nor_mnem,
		 rst_val => $regref->{addr_end}->to_Hex,
		 bits => $pack->{address_bits},
		 desc => "Ending Address of Register + 1",
		 desc_trivial => 1,);

	    if (!$nofields) {
		new_push SystemC::Vregs::Define::Value
		    (pack => $pack,
		     name => "RAC_".$nor_mnem,
		     rst_val => $regref->{range_ents},
		     bits => (($regref->{range_ents}->Lexicompare($bit32) > 0)
			      ? $pack->{address_bits} : 32),
		     desc => "Number of entries",
		     desc_trivial => 1,);
	    }

	    if (! $regref->{spacing}->equal($bit4)
		&& !$nofields) {
		new_push SystemC::Vregs::Define::Value
		    (pack => $pack,
		     name => "RRP_".$nor_mnem,
		     rst_val => $regref->{spacing}->to_Hex,
		     bits => $pack->{address_bits},
		     desc => "Range spacing",
		     desc_trivial => 1,);
	    }
	}

	if (!$nofields
	    && ($range ne ""
		|| ($regref->{typeref}{words}>1
		    && $regref->{typeref}{words} > ($pack->data_bits / 32)))) {
	    my $wordspace = $regref->{pack}->addr_const_vec($regref->{typeref}{words}*4);
	    if ($regref->{spacing}->equal($wordspace)) {
		my $val = Bit::Vector->new($regref->{pack}{address_bits});
		$val->subtract($regref->{addr_end},$addr,0);  #end-start
		new_push SystemC::Vregs::Define::Value
		    (pack => $pack,
		     name => "RRS_".$nor_mnem,
		     rst_val => $val->to_Hex,
		     bits => (($val != 0) ? $pack->{address_bits} : 32),
		     desc => "Range byte size",
		     desc_trivial => 1,);
	    } else {
		new_push SystemC::Vregs::Define::Value
		    (pack => $pack,
		     name => "RRS_".$nor_mnem,
		     rst_val => "Non_Contiguous",
		     desc => "Range byte size: This register region contains gaps.",
		     desc_trivial => 0,);
	    }

	    my $delta = Bit::Vector->new($regref->{pack}{address_bits});
	    $delta->subtract($regref->{addr_end},$addr,1);  #end-start-1
	    if (_valid_mask ($pack, $addr, $delta)) {
		new_push SystemC::Vregs::Define::Value
		    (pack => $pack,
		     name => "RAM_".$nor_mnem,
		     rst_val => $delta->to_Hex,
		     bits => $pack->{address_bits},
		     desc => "Address Mask",
		     desc_trivial => 1,);
	    } else {
		# We could just leave it out, but that leads to a lot of "bug"
		# reports about the define being missing!
		new_push SystemC::Vregs::Define::Value
		    (pack => $pack,
		     name => "RAM_".$nor_mnem,
		     rst_val => "Not_Aligned",
		     desc => "Address Mask: This register is not naturally aligned, so a mask will not work.",
		     desc_trivial => 0,);
	    }
	}

	# If small range, make a alias per range
	if (!$nofields
	    && $range ne ""
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
		     desc => "Address of Entry ${classname}${range_val}",
		     desc_trivial => 0,);
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
	     desc => "Base address of $nor_mnem registers",
	     desc_trivial => 1,);
	new_push SystemC::Vregs::Define::Value
	    (pack => $pack,
	     name => "RBASEAE_".$nor_mnem,
	     val => $addr_end,
	     rst_val => $addr_end->to_Hex, bits => $pack->{address_bits},
	     desc => "Ending base address of $nor_mnem registers",
	     desc_trivial => 1,);
	my $delta = Bit::Vector->new($pack->{address_bits});
	$delta->subtract($modref->{addr_end},$addr,1);  #end-start-1
	$delta = _force_mask ($pack, $delta);
	new_push SystemC::Vregs::Define::Value
	    (pack => $pack,
	     name => "RBASEAM_".$nor_mnem,
	     rst_val => $delta->to_Hex,
	     bits => $pack->{address_bits},
	     desc => "Address Mask (may be forced to power-of-two)",
	     desc_trivial => 1,);
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

Vregs is part of the L<http://www.veripool.org/> free Verilog software tool
suite.  The latest version is available from CPAN and from
L<http://www.veripool.org/vregs>.  /www.veripool.org/>.

Copyright 2001-2010 by Wilson Snyder.  This package is free software; you
can redistribute it and/or modify it under the terms of either the GNU
Lesser General Public License Version 3 or the Perl Artistic License
Version 2.0.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=head1 SEE ALSO

L<vreg>,
L<vreg_latex2html>,
L<SystemC::Vregs::Rules>

Low level objects:

L<SystemC::Vregs::Bit>,
L<SystemC::Vregs::Define>,
L<SystemC::Vregs::Enum>,
L<SystemC::Vregs::Language>,
L<SystemC::Vregs::Number>,
L<SystemC::Vregs::Register>,
L<SystemC::Vregs::Subclass>,
L<SystemC::Vregs::Type>
L<SystemC::Vregs::Input::TableExtract>,
L<SystemC::Vregs::Input::Layout>,
L<SystemC::Vregs::Input::HTML>,
L<SystemC::Vregs::Output::Class>,
L<SystemC::Vregs::Output::Defines>,
L<SystemC::Vregs::Output::Hash>,
L<SystemC::Vregs::Output::Info>,
L<SystemC::Vregs::Output::Layout>,
L<SystemC::Vregs::Output::Latex>,
L<SystemC::Vregs::Output::Param>

=cut

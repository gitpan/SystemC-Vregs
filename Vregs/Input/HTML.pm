# See copyright, etc in below POD section.
######################################################################

package SystemC::Vregs::Input::HTML;
use Carp;
use strict;

use SystemC::Vregs::Input::TableExtract;
use vars qw($VERSION $Debug);

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
# Reading

sub read {
    my $self = shift;
    my %params = (#filename =>
		  #pack =>
		  @_);
    my $pack = $params{pack} or croak "%Error: No pack=> parameter passed,";
    $self->{pack} = $pack;
    # Dump headers for class name based accessors

    my $te = new SystemC::Vregs::Input::TableExtract(depth=>0, );
    $te->{_vregs_inp} = $self;
    $te->parse_file($params{filename});
}

######################################################################
# Callbacks from table extract

sub new_item {
    my $self = $_[0];
    my $bittableref = $_[1];
    my $flagref = $_[2];	# Hash of {heading} = value_of_heading
    #Create a new register/class/enum, called from the html parser
    print "new_item:",::Dumper(\$flagref, $bittableref) if $SystemC::Vregs::Input::TableExtract::Debug;

    if ($flagref->{Register}) {
	new_register (@_);
    } elsif ($flagref->{Class}) {
	new_register (@_);
    } elsif ($flagref->{Enum}) {
	new_enum (@_);
    } elsif (defined $flagref->{Defines}) {  # Name not required, so defined.
	new_define (@_);
    } elsif ($flagref->{Package}) {
	new_package (@_);
    }
}

sub new_package {
    my $self = shift;
    my $bittableref = shift;  my @bittable = @{$bittableref};
    my $flagref = shift;	# Hash of {heading} = value_of_heading
    # Create a new package
    my $pack = $self->{pack};

    ($flagref->{Package}) or die;
    (!$self->{_got_package_decl}) or return $pack->warn($flagref, "Multiple Package attribute sections, previous at $self->{_got_package_decl}.\n");

    my $attr = $flagref->{Attributes}||"";
    print "PACK ATTR $attr\n" if $Debug;
    $pack->attributes_parse($attr);
    $self->{_got_package_decl} = $flagref->{at};
}

sub new_define {
    my $self = shift;
    my $bittableref = shift;  my @bittable = @{$bittableref};
    my $flagref = shift;	# Hash of {heading} = value_of_heading
    # Create a new enumeration
    return if $#bittable<0;   # Empty list of defines
    my $pack = $self->{pack};

    #print ::Dumper(\$flagref, $bittableref);
    (defined $flagref->{Defines}) or die;
    $flagref->{Defines} ||= "";
    my $defname = _cleanup_column($flagref->{Defines});
    $defname .= "_" if $defname ne "" && $defname !~ /_$/;
    $defname = "" if $defname eq "_";

    my $whole_table_attr = $flagref->{Attributes}||"";

    my ($const_col, $mnem_col, $def_col)
	= $self->_choose_columns ($flagref,
				  [qw(Constant Mnemonic Definition)],
				  [qw(Product)],
				  $bittable[0]);
    defined $const_col or return $pack->warn ($flagref, "Define table is missing column headed 'Constant'\n");
    defined $mnem_col  or return $pack->warn ($flagref, "Define table is missing column headed 'Mnemonic'\n");
    defined $def_col   or return $pack->warn ($flagref, "Define table is missing column headed 'Definition'\n");

    foreach my $row (@bittable) {
	 print "  Row:\n" if $Debug;
	 foreach my $col (@$row) {
	     print "    Ent:$col\n" if $Debug;
	     if (!defined $col) {
		 $pack->warn ($flagref, "Column ".($col+1)." is empty\n");
	     }
	 }
	 next if $row eq $bittable[0];	# Ignore header

	 my $val_mnem = $row->[$mnem_col];
	 my $desc     = $row->[$def_col];

	 # Skip blank/reserved values
	 next if ($val_mnem eq "" && ($desc eq "" || $desc =~ /^reserved/i));

	 # Check for empty field
	 my $defref = new SystemC::Vregs::Define::Value
	     (pack => $pack,
	      name => $defname . $val_mnem,
	      rst  => $row->[$const_col],
	      desc => $desc,
	      at   => $flagref->{at},
	      is_manual => 1,
	      );

	 # Take special user defined fields and add to table
	 for (my $colnum=0; $colnum<=$#{$bittable[0]}; $colnum++) {
	     my $col = $bittable[0][$colnum];
	     $col =~ s/\s+//;
	     if ($col =~ /^\s*\(([a-zA-Z_0-9]+)\)\s*$/) {
		 my $var = $1;
		 my $val = _cleanup_column($row->[$colnum]||"");
		 $defref->{attributes}{$var} = $val if $val =~ /^([][a-zA-Z._:0-9+]+)$/;
	     }
	 }
	 $defref->attributes_parse($whole_table_attr);
    }
}

sub new_enum {
    my $self = shift;
    my $bittableref = shift;  my @bittable = @{$bittableref};
    my $flagref = shift;	# Hash of {heading} = value_of_heading
    # Create a new enumeration
    my $pack = $self->{pack};

    ($flagref->{Enum}) or die;
    my $classname = _cleanup_column($flagref->{Enum});

    my ($const_col, $mnem_col, $def_col)
	= $self->_choose_columns ($flagref,
				  [qw(Constant Mnemonic Definition)],
				  [qw(Product)],
				  $bittable[0]);
    defined $const_col or return $pack->warn ($flagref, "Enum table is missing column headed 'Constant'\n");
    defined $mnem_col  or return $pack->warn ($flagref, "Enum table is missing column headed 'Mnemonic'\n");
    defined $def_col   or return $pack->warn ($flagref, "Enum table is missing column headed 'Definition'\n");

    my $classref = new SystemC::Vregs::Enum
	(pack => $pack,
	 name => $classname,
	 at => $flagref->{at},
	 );

    my $attr = $flagref->{Attributes}||"";
    while ($attr =~ s/-(\w+)//) {
	$classref->{attributes}{$1} = 1;
    }
    ($attr =~ /^\s*$/) or $pack->warn($flagref, "Strange attributes $attr\n");

    foreach my $row (@bittable) {
	print "  Row:\n" if $Debug;
	foreach my $col (@$row) {
	    print "    Ent:$col\n" if $Debug;
	    if (!defined $col) {
		$pack->warn ($flagref, "Column ".($col+1)." is empty\n");
	    }
	}
	next if $row eq $bittable[0];	# Ignore header

	my $val_mnem = _cleanup_column($row->[$mnem_col]);
	my $desc     = _cleanup_column($row->[$def_col]);

	# Skip blank/reserved values
	next if ($val_mnem eq "" && ($desc eq "" || $desc =~ /^reserved/i));

	# Check for empty field
	my $valref = new SystemC::Vregs::Enum::Value
	    (pack => $pack,
	     name => $val_mnem,
	     class => $classref,
	     rst  => _cleanup_column($row->[$const_col]),
	     desc => $desc,
	     at => $flagref->{at},
	     );


	# Take special user defined fields and add to table
	for (my $colnum=0; $colnum<=$#{$bittable[0]}; $colnum++) {
	    my $col = $bittable[0][$colnum];
	    $col =~ s/\s+//;
	    if ($col =~ /^\s*\(([a-zA-Z_0-9]+)\)\s*$/) {
		my $var = $1;
		my $val = _cleanup_column($row->[$colnum]||"");
		$valref->{attributes}{$var} = $val if $val =~ /^([][a-zA-Z._:0-9+]+)$/;
	    }
	}
    }
}

sub new_register {
    my $self = shift;
    my $bittableref = shift;  my @bittable = @{$bittableref};
    my $flagref = shift;	# Hash of {heading} = value_of_heading
    # Create a new register
    my $pack = $self->{pack};

    my $classname = _cleanup_column($flagref->{Register} || $flagref->{Class});
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
	(pack => $pack,
	 name => $classname,
	 at => $flagref->{at},
	 is_register => $is_register,	# Ok, perhaps I should have made a superclass
	 );
    $typeref->inherits($inherits);

    # See also $typeref->{attributes}{lcfirst}, below.
    while ($attr =~ s/-([a-zA-Z_0-9]+)\s*=?\s*([a-zA-Z._0-9+]+)?//) {
	$typeref->{attributes}{$1} = (defined $2 ? $2 : 1);
    }
    ($attr =~ /^\s*$/) or $pack->warn($flagref, "Strange attributes $attr\n");

    if ($is_register) {
	# Declare a register
	($classname =~ /^[R]_/) or return $pack->warn($flagref, "Strange mnemonic name, doesn't begin with R_");

	my $addr = $flagref->{Address};  # Don't _cleanup_column, as we have (Add 0x) text
	my $spacingtext = 0;
	$spacingtext = $pack->{data_bytes} if $range;
	if (!$addr) {
	    $pack->warn ($flagref, "No 'Address' Heading Found\n");
	    return;
	}
	$addr =~ s/[()]//g;
	$addr =~ s/\s*plus\s*base\s*address\s*//;
	$addr =~ s/\s*per\s+entry//g;
	if ($addr =~ s/\s*Add\s*(0x[a-f0-9_]+)\s*//i) {
	    $spacingtext = $1;
	}

	my $regref = new SystemC::Vregs::Register
	    (pack => $pack,
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
	    = $self->_choose_columns ($flagref,
				      [qw(Bit Mnemonic Type Definition),
				       qw(Access Reset),	# Register decls
				       qw(Constant),	# Class declarations
				       qw(Size),	# Ignored Optionals
				      ],
				      [qw(Product)],
				      $bittable[0]);
	$rst_col ||= $const_col;
	defined $bit_col or  return $pack->warn ($flagref, "Table is missing column headed 'Bit'\n");
	defined $mnem_col or return $pack->warn ($flagref, "Table is missing column headed 'Mnemonic'\n");
	defined $def_col or  return $pack->warn ($flagref, "Table is missing column headed 'Definition'\n");
	if ($is_register) {
	    defined $rst_col or  return $pack->warn ($flagref, "Table is missing column headed 'Reset'\n");
	    defined $acc_col or  return $pack->warn ($flagref, "Table is missing column headed 'Access'\n");
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
		    $pack->warn ($flagref, "Column ".($col+1)." is empty\n");
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

	    my $rst = _cleanup_column(defined $rst_col ? $row->[$rst_col] : "");
	    $rst = 'X' if ($rst eq "" && !$is_register);

	    my $type = _cleanup_column(defined $type_col && $row->[$type_col]);

	    my $acc = _cleanup_column(defined $acc_col ? $row->[$acc_col] : 'RW');

	    (!$typeref->{fields}{$bit_mnem}) or
		$pack->warn ($typeref->{fields}{$bit_mnem}, "Field defined twice in spec\n");
	    my $bitref = new SystemC::Vregs::Bit
		(pack => $pack,
		 name => $bit_mnem,
		 typeref => $typeref,
		 bits => $row->[$bit_col],
		 access => $acc,
		 overlaps => $overlaps,
		 rst  => $rst,
		 desc => $row->[$def_col],
		 type => $type,
		 expand => ($type && $desc =~ /expand class/i)?1:undef,
		 at => $flagref->{at},
		 );

	    # Take special user defined fields and add to table
	    for (my $colnum=0; $colnum<=$#{$bittable[0]}; $colnum++) {
		my $col = $bittable[0][$colnum];
		$col =~ s/\s+//;
		if ($col =~ /^\s*\(([a-zA-Z_0-9]+)\)\s*$/) {
		    my $var = $1;
		    my $val = _cleanup_column($row->[$colnum]||"");
		    $bitref->{attributes}{$var} = $val if $val =~ /^([][a-zA-Z._:0-9+]+)$/;
		}
	    }
	}
    }
}

######################################################################
#### Parsing

sub _choose_columns {
    my $self = shift;
    my $flagref = shift;
    my $fieldref = shift;
    my $attrfieldref = shift;
    my $headref = shift;
    # Look for the columns with the given headings.  Require them to exist.

    my @collist;
    my @colused = ();
    my @colheads;
    # The list is short, so this is faster than forming a hash.
    # If things get wide, this may change
    for (my $h=0; $h<=$#{$headref}; $h++) {
	$colheads[$h] = $headref->[$h];
	$colheads[$h] =~ s/\s*\(.*\)\s*//;  # Ignore comments in the header
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
    foreach my $fld (@{$attrfieldref}) {
	for (my $h=0; $h<=$#{$headref}; $h++) {
	    if ($fld eq $colheads[$h]) {
		# Convert to a attribute
		$headref->[$h] = "(".$headref->[$h].")";
		$colused[$h] = 1;
	    }
	}
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

sub _cleanup_column {
    my $text = shift;
    return undef if !defined $text;
    while ($text =~ s/\s*\([^\(\)]*\)//) {}	# Strip (comment)  Leave trailing space "foo (bar) x" becomes "foo x"
    $text =~ s/\s+$//;
    $text =~ s/^\s+//;
    return $text;
}

######################################################################
######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::Input::HTML - Inputting .html files

=head1 SYNOPSIS

SystemC::Vregs::Input::HTML->new->read(pack=>$VregsPackageObject, filename=>$fn);

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

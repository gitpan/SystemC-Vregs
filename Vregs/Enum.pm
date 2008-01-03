# $Id: Enum.pm 49231 2008-01-03 16:53:43Z wsnyder $
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

package SystemC::Vregs::Enum;
use SystemC::Vregs::Number;
use SystemC::Vregs::Subclass;
use Verilog::Language;	# For value parsing

use strict;
use vars qw ($VERSION);
use base qw (SystemC::Vregs::Subclass);

$VERSION = '1.450';

######################################################################
######################################################################
######################################################################
######################################################################
#### SystemC::Vregs::Enum

package SystemC::Vregs::Enum;
use strict;

#Fields: name, at, pack, fields

sub new {
    my $class = shift;
    my $self = {@_};
    bless $self, $class;
    $self->{pack} or die;  # Should have been passed as parameter
    $self->{pack}{enums}{$self->{name}} = $self;
    return $self;
}

sub delete {
    my $self = shift;
    $self->{deleted} = 1;   # So can see in any dangling refs.
    if ($self->{pack}) {
	delete $self->{pack}{enums}{$self->{name}};
    }
}

sub find_value {
    my $self = shift;
    my $name = shift;
    return $self->{fields}{$name};
}

sub attribute_value {
    my $self = shift;
    my $attr = shift;
    return $self->{attributes}{$attr} if defined $self->{attributes}{$attr};
    return $self->{pack}{attributes}{$attr} if defined $self->{pack}{attributes}{$attr};
    return undef;
}

#======

sub check_name {
    my $self = shift;
    my $field = $self->{name};
    if ($self->attribute_value('allowlc')) {
	if ($field !~ /^[a-zA-Z][a-zA-Z0-9_]*$/) {
	    return $self->warn ("Enum names must match [alpha][alphanumerics_]'\n: $field");
	}
    } else {
	if ($field !~ /^[A-Z][a-zA-Z0-9_]*$/) {
	    return $self->warn ("Enum names must match [capitals][alphanumerics_]'\n: $field");
	}
    }
    # Because the enum is always capitalized, we don't add the 'lc' here.
    my $lang = (SystemC::Vregs::Language::is_keyword($field)
		|| SystemC::Vregs::Language::is_keyword(uc $field));
    if ($lang) {
	$self->warn ("Name matches a $lang language keyword: ", lc $field, "\n");
    }
}

sub check {
    my $self = shift;
    #print ::Dumper($enumref);
    $self->check_name();
    foreach my $fieldref (values %{$self->{fields}}) {
	$fieldref->check();
    }
    $self->{bits} or $self->warn ("Enum has no entries");
}

sub remove_if_mismatch {
    my $self = shift;
    my $test_cb = shift;
    my $rm=0;  my $cnt=0;
    foreach my $fieldref (values %{$self->{fields}}) {
	$rm++ if $fieldref->remove_if_mismatch($test_cb);
	$cnt++;
    }
    if ($test_cb->($self) || ($rm && $rm == $cnt)) {
	$self->delete;
    }
}

sub fields_sorted {
    my $typeref = shift;
    return (sort {$a->{rst_val} <=> $b->{rst_val}
		  || $a->{name} cmp $b->{name} }
	    (values %{$typeref->{fields}}));
}

sub fields_first_name {
    my $self = shift;
    my @fields = $self->fields_sorted;
    if ($fields[0]) {
	return $fields[0]->name;
    } else {
	return undef;
    }
}

sub dump {
    my $self = shift;
    my $fh = shift || \*STDOUT;
    my $indent = shift||"  ";
    print $fh +($indent,"Enum: ",$self->{name},
		"\n");
    foreach my $fieldref ($self->fields_sorted) {
	$fieldref->dump($fh,$indent."  ");
    }
}

######################################################################
######################################################################
######################################################################
######################################################################
#### SystemC::Vregs::Enum::Value

package SystemC::Vregs::Enum::Value;
use strict;
use base qw (SystemC::Vregs::Subclass);

# Fields: 	name, at, class
sub name { return $_[0]->{name}; }

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{class} or die;  # Should have been passed as parameter
    $self->{class}{fields}{$self->{name}} = $self;
    return $self;
}

sub delete {
    my $self = shift;
    $self->{deleted} = 1;   # So can see in any dangling refs.
    if ($self->{class}) {
	delete $self->{class}{fields}{$self->{name}};
    }
}

sub attributes {
    my $self = shift;
    my $attr = shift;
    my $value = shift;
    $self->{attributes}{$attr} = $value if $value;
    return $self->{attributes}{$attr};
}

sub attribute_value {
    my $self = shift;
    my $attr = shift;
    return $self->{attributes}{$attr} if defined $self->{attributes}{$attr};
    return $self->{class}->attribute_value($attr);
}

sub clean_desc {
    my $self = shift;
    $self->{desc} = $self->clean_sentence($self->{desc});
}

sub clean_rst {
    my $self = shift;
    my $field = $self->{rst};

    my $bits = Verilog::Language::number_bits ($field);
    if (!$bits) { return $self->warn ("Number of bits in constant not specified: $field\n"); }
    $self->{bits} = $bits;
    my $val = Verilog::Language::number_value ($field);
    if (!defined $val) { return $self->warn ("Value of constant unparsable: $field\n"); }
    $self->{rst_val} = $val;

    if (defined $self->{class}{bits}
	&& ($self->{class}{bits} != $bits)) {
	return $self->warn ("Enum value doesn't match register width: $field != "
			    .$self->{class}{bits}."\n");
    }
    $self->{class}{bits} = $bits;

    if ($bits && $bits<32 && ($self->{rst_val}||0) >= (1<<$bits)) {
	$self->warn ("Enum value wider than width: ".$self->{rst}." > width "
		     .$self->{class}{bits}."\n");
    }
}

sub check_name {
    my $self = shift;
    my $field = $self->{name};
    my $class = $self->{class};

    if ($class->attribute_value('allowlc')) {
	if ($field !~ /^[a-zA-Z][a-zA-Z0-9_]*$/) {
	    return $self->warn ("Enum field names must match [capital][alphanumerics_]: $field\n");
	}
    } else {
	if ($field !~ /^[A-Z][A-Z0-9_]*$/) {
	    return $self->warn ("Enum field names must match [capital][capitalnumerics_]: $field\n");
	}
    }
}

sub expand_subenums {
    my $self = shift;
    if ($self->{desc} =~ /^(.*)ENUM:(\S+)(.*)/) {
	my $prefix = $1; my $subname = $2; my $postfix = $3;
	print "Expand Subenum '$prefix'  '$subname'  '$postfix'\n" if $SystemC::Vregs::Debug;
	my $suberef = $self->{pack}->find_enum($subname);
	if (!$suberef) {
	    $self->warn("Enum references sub-enum which isn't found: $subname\n");
	} else {
	    $suberef->check();
	    $self->{omit_description} = 1;
	    foreach my $subfieldref ($suberef->fields_sorted) {
		print "   FIELD ADD ".$subfieldref->{name}."\n" if $SystemC::Vregs::Debug;
		my $rst = $self->{bits}."'d".($self->{rst_val} + $subfieldref->{rst_val});
		my $valref = new SystemC::Vregs::Enum::Value
		    (pack => $self->{pack},
		     name => $self->{name}."_".$subfieldref->{name},
		     class => $self->{class},
		     rst  => $rst,
		     desc => $prefix . $subfieldref->{desc} . $postfix,
		     omit_from_vregs_file => 1,   # Else we'll add it every time we rebuild
		     );
		# Clone attributes too; higher ones first, so lower ones can override
		$valref->copy_attributes_from($subfieldref);  # Overrides whole enum attrs, so do first
		$valref->copy_attributes_from($self);
		$valref->check;
	    }
	}
    }
}

sub check {
    my $self = shift;
    $self->clean_desc();
    $self->clean_rst();
    $self->check_name();
    $self->expand_subenums();
    ($self->{desc}) or $self->warn("Empty description, please document it.\n");
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
    print $fh +($indent,"Value: ",$self->{name},
		"\n");
}

######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::Enum - Definition object

=head1 SYNOPSIS

    use SystemC::Vregs;

=head1 DESCRIPTION

This package contains a blessed hash object for each enumeration.

=head1 FIELDS

These fields may be specified with the new() function, and accessed
via the self hash: $self->{field}.

=over 4

=item bits

Number of bits wide the enumeration values are.

=item desc

Description comment for the object.

=item name

Name of the object.

=item pack

Reference to the package (SystemC::Vregs) object self is a member of.

=item fields

Hash containing SystemC::Vregs::Enum::Value objects.  Each value object
contains a name, desc, and rst field, just like the SystemC::Vregs::Define
objects.

=back

=head1 METHODS

=over 4

=item new

Creates a new enumeration object.

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

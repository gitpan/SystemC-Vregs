# $Id: Rules.pm,v 1.8 2001/09/04 02:06:21 wsnyder Exp $
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

package SystemC::Vregs::Rules;
use vars qw ($Default_Self $VERSION);
use Carp;
use strict;

$VERSION = '1.000';

######################################################################
# Default rules

sub _default_rules {
    before_file_body
	(text=>
	 "#include <iostream>\n"
	 ."#include <netinet/in.h>  /*ntoh*/\n"
	 ."#include <stdint.h>      /*uint32_t*/\n"
	 ."#include <VregsClass.h>\n"
	 );
}

######################################################################
# Rules the __rules.pl file calls

sub before_file_body    {_declare_rule (rule=>'file_body_before', @_); }
sub  after_file_body    {_declare_rule (rule=>'file_body_after', @_); }
sub before_class_begin { _declare_rule (rule=>'class_begin_before', @_); }
sub  after_class_begin { _declare_rule (rule=>'class_begin_after', @_); }
sub before_class_end {	 _declare_rule (rule=>'class_end_before', @_); }
sub  after_class_end {	 _declare_rule (rule=>'class_end_after', @_); }
sub before_enum_begin {	 _declare_rule (rule=>'enum_begin_before', @_); }
sub  after_enum_begin {	 _declare_rule (rule=>'enum_begin_after', @_); }
sub before_enum_end {	 _declare_rule (rule=>'enum_end_before', @_); }
sub  after_enum_end {	 _declare_rule (rule=>'enum_end_after', @_); }

######################################################################
# Functions that rule subroutines may call

sub fprint  { $Default_Self->{filehandle}->print (@_); }
sub fprintf { $Default_Self->{filehandle}->printf (@_); }

######################################################################
# Functions called by rest of vregs program

sub new {
    my $class = shift;
    my $self = {rules=>{},
		filenames=>[],
		#filehandle=>\*STDOUT,
		@_};
    bless $self, $class;
    $Default_Self = $self;

    _default_rules();

    return $self;
}

sub read {
    my $self = shift; ($self && ref $self) or croak "%Error: Not called as method,";
    my $filename = shift;
    $Default_Self = $self;

    push @{$self->{filenames}}, $filename;

    print "read_rule_file $filename\n" if $SystemC::Vregs::Debug;
    $! = $@ = undef;
    my $rtn = do $filename;
    (!$@) or die "%Error: $filename: $@\n";
    (defined $rtn || !$!) or die "%Error: $filename: $!\n";
    #use Data::Dumper; print Dumper(\%Rules);
}

sub filehandle {
    my $self = shift;
    $self->{filehandle} = shift;
}
sub filenames {
    my $self = shift;
    return (@{$self->{filenames}});
}

sub execute_rule {
    my $ruleself; $ruleself = (ref $_[0]) ? shift : $Default_Self;
    my $rule = shift;
    my $name = shift;
    my $invoke_self = shift;
    $Default_Self = $ruleself;

    print "exec_rule $rule, $name\n" if $SystemC::Vregs::Debug;
    foreach my $rvec (@{$ruleself->{rules}{$rule}}) {
	if ($name =~ $rvec->{name}) {
	    print "Rule execute $name (self=$invoke_self)\n" if $SystemC::Vregs::Debug;
	    {
		use vars qw ($self);
		local $self = $invoke_self;
		&{$rvec->{prog}};
	    }
	    if ($rvec->{replace}) {
		print "  Last rule (replace)\n" if $SystemC::Vregs::Debug;
		return;
	    }
	}
    }
}

sub _declare_rule {
    my $self; $self = (ref $_[0]) ? shift : $Default_Self;
    my %param = (replace=>0,
		  name => qr/.*/,
		  @_);
    $param{rule} or croak "%Error: no rule=> specified\n";
    (defined $param{text} || defined $param{prog})
	or croak "%Error: no text=> or prog=> specified\n";

    if (!defined $param{prog}) {
	# Turn {text} into a prog, so we only need to support {prog}
	my $closure_value = $param{text};
	$param{prog} = sub { fprint $closure_value; };
	delete $param{text};
    }

    if (!ref $param{name}) {
	# Turn name=>constant into a regexp
	my $nometa = quotemeta $param{name};
	$param{name} = qr/^$nometa/;
    }

    if ($param{replace}) {
	unshift @{$self->{rules}{$param{rule}}}, \%param;
    } else {
	push @{$self->{rules}{$param{rule}}}, \%param;
    }
}

######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::Rules - Rules for outputting class headers

=head1 SYNOPSIS

    In a I<package>__rules.pl file:

    before_file_body    (replace => 1,
	                 text => "#include \"myinclude.h\"\n",);
    before_enum_begin (  name => qr/_mine$/,
	                 text => "    const static bool  MINE = true\n", );
    after_enum_end (     name => 'Foo',
	                 prog => sub { fprint "   // enum foo\n"; }, );

=head1 DESCRIPTION

This package is used to execute Vregs rule files.  These files describe
execptions and additional text to be included in Vregs outputs.

=head1 RULE DECLARATIONS

These functions are used to describe a rule.  A rule has a number of rule
parameters, generally a name which must match, and a text or prog
parameter.

=over 4

=item after_file_body

Specifies a rule to be invoked at the bottom of the file.

=item before_file_body

Specifies a rule to be invoked to produce the #include and other text at
the top of the file.

=item after_class_begin

Specifies a rule to be invoked right after the 'class foo {' line.

=item before_class_end

Specifies a rule to be invoked right before the '}' ending a class declaration.

=item after_class_end

Specifies a rule to be invoked right after the '}' ending a class declaration.

=item after_enum_begin

Specifies a rule to be invoked right after the 'enum foo {' line.

=item before_enum_end

Specifies a rule to be invoked right before the '}' ending a enum declaration.

=item after_enum_end

Specifies a rule to be invoked right after the '}' ending a enum declaration.

=back

=head1 RULE PARAMETERS

=over 4

=item name => 'I<string>'
=item name => qr/I<regexp>/

Must be either a string which must match for the rule to be invoked, or a
rexexp reference (qr/regexp/) which if matches will invoke the rule.

=item replace => 1

Generally rules are cumulative, in that defining additional rules will
place additional cases to be tested.  With the replace flag, the rule will
replace all existing rules, including default rules.  This is generally useful
for replacing the default #include section with the before_file_body rule.

=item text => 'text'

A text string to output to the file.

=item prog => sub { I<subroutine> }

A reference to a subroutine that generates the code for the file.

=back

=head1 RULE SUBROUTINES

These functions and variables are useful when writing prog=> subroutines.

=over 4

=item $self

Reference to a SystemC::Vregs::Enum or SystemC::Vregs::Type, as appropriate.
This can be used to get information about the thing to be printed, for example
$self->{name} is the name of the object, and $self->{attributes}{foo} checks
for a specific attribute.

=item fprint

Print to the file.

=item fprintf

Formatted print to the file.

=back

=head1 SEE ALSO

C<vregs>, C<SystemC::Vregs>

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=cut

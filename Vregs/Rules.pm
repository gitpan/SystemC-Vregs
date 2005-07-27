# $Revision: 1.39 $$Date: 2005-07-27 09:55:32 -0400 (Wed, 27 Jul 2005) $$Author: wsnyder $
# Author: Wilson Snyder <wsnyder@wsnyder.org>
######################################################################
#
# Copyright 2001-2005 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
######################################################################

package SystemC::Vregs::Rules;
use vars qw ($Default_Self $VERSION);
use Carp;
use strict;

$VERSION = '1.301';

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
    before_enum_end
	(prog=> sub {
	    my ($self,$name) = @_;
	    fprint ("    enum en m_e;\n"
		    ."    inline ${name} () VREGS_ENUM_DEF_INITTER(MAX) {}\n"
		    ."    inline ${name} (en _e) : m_e(_e) {}\n"
		    ."    explicit inline ${name} (int _e) : m_e(static_cast<en>(_e)) {}\n"
		    ."    operator const char * () const { return ascii(); }\n"
		    ."    operator en () const { return m_e; }\n"
		    ."    const char * ascii () const;\n"
		    );
	    if ($self->attribute_value('descfunc')) {
		fprint ("    const char * description () const;\n");
	    }
	});
    before_class_dump
	(prog => sub {
	    $SystemC::Vregs::Do_Dump = 1;
	});
    after_class_dump
	(prog => sub {
	    my ($self,$name,$dumparef) = @_;  my @dumps = @{$dumparef};
	    unshift @dumps, "(($self->{inherits}*)(this))->dump(pf)" if $self->{inherits};
	    if ($#dumps>=0) {
		fprint("    lhs<<", join("\n\t<<pf<<",@dumps), ";\n");
	    }
	});
    after_enum_end
	(prog=> sub {
	    my ($self,$name) = @_;
	    fprint("  inline bool operator== (${name} lhs, ${name} rhs) { return (lhs.m_e == rhs.m_e); }\n",
		   "  inline bool operator== (${name} lhs, ${name}::en rhs) { return (lhs.m_e == rhs); }\n",
		   "  inline bool operator== (${name}::en lhs, ${name} rhs) { return (lhs == rhs.m_e); }\n",
		   "  inline bool operator!= (${name} lhs, ${name} rhs) { return (lhs.m_e != rhs.m_e); }\n",
		   "  inline bool operator!= (${name} lhs, ${name}::en rhs) { return (lhs.m_e != rhs); }\n",
		   "  inline bool operator!= (${name}::en lhs, ${name} rhs) { return (lhs != rhs.m_e); }\n",
		   "  inline bool operator< (${name} lhs, ${name} rhs) { return lhs.m_e < rhs.m_e; }\n",
		   "  inline OStream& operator<< (OStream& lhs, const ${name}& rhs) { return lhs << rhs.ascii(); }\n"
		   );});
}

######################################################################
# Rules the __rules.pl file calls

sub before_any_file {	 _declare_rule (rule=>'any_file_before', @_); }
sub  after_any_file {	 _declare_rule (rule=>'any_file_after', @_); }
sub before_info_cpp_file{_declare_rule (rule=>'info_cpp_file_before', @_); }
sub  after_info_cpp_file{_declare_rule (rule=>'info_cpp_file_after', @_); }
sub before_file_body    {_declare_rule (rule=>'file_body_before', @_); }
sub  after_file_body    {_declare_rule (rule=>'file_body_after', @_); }
sub before_class_cpp_file{_declare_rule (rule=>'class_cpp_file_before', @_); }
sub  after_class_cpp_file{_declare_rule (rule=>'class_cpp_file_after', @_); }
sub before_class_begin { _declare_rule (rule=>'class_begin_before', @_); }
sub  after_class_begin { _declare_rule (rule=>'class_begin_after', @_); }
sub before_class_end {	 _declare_rule (rule=>'class_end_before', @_); }
sub  after_class_end {	 _declare_rule (rule=>'class_end_after', @_); }
sub before_class_cpp {	 _declare_rule (rule=>'class_cpp_before', @_); }
sub  after_class_cpp {	 _declare_rule (rule=>'class_cpp_after', @_); }
sub before_class_dump {	 _declare_rule (rule=>'class_dump_before', @_); }
sub  after_class_dump {	 _declare_rule (rule=>'class_dump_after', @_); }
sub before_enum_begin {	 _declare_rule (rule=>'enum_begin_before', @_); }
sub  after_enum_begin {	 _declare_rule (rule=>'enum_begin_after', @_); }
sub before_enum_end {	 _declare_rule (rule=>'enum_end_before', @_); }
sub  after_enum_end {	 _declare_rule (rule=>'enum_end_after', @_); }
sub before_enum_cpp {	 _declare_rule (rule=>'enum_cpp_before', @_); }
sub  after_enum_cpp {	 _declare_rule (rule=>'enum_cpp_after', @_); }

######################################################################
# Functions that rule subroutines may call

sub fhandle { return $Default_Self->{filehandle}; }
sub fprint  { fhandle()->print (@_); }
sub fprintf { fhandle()->printf (@_); }
sub protect_rdwr_only { $Default_Self->{protect_rdwr_only} = shift; }

######################################################################
# Functions called by rest of vregs program

sub set_default_self {
    $Default_Self = shift;
}

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
    my @rest = @_;
    $Default_Self = $ruleself;

    print "exec_rule $rule, $name\n" if $SystemC::Vregs::Debug;
    foreach my $rvec (@{$ruleself->{rules}{$rule}}) {
	if ($name =~ $rvec->{name}) {
	    print "Rule execute $name (self=$invoke_self)\n" if $SystemC::Vregs::Debug;
	    {
		use vars qw ($self $name);
		local $self = $invoke_self;
		&{$rvec->{prog}}($invoke_self, $name, @rest);
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
	$param{name} = qr/^$nometa$/;
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
	                 text => "    static const bool  MINE = true\n", );
    after_enum_end (     name => 'Foo',
	                 prog => sub { fprint "   // enum foo\n"; }, );

=head1 DESCRIPTION

This package is used to execute Vregs rule files.  These files describe
exceptions and additional text to be included in Vregs outputs.

=head1 RULE DECLARATIONS

These functions are used to describe a rule.  A rule has a number of rule
parameters, generally a name which must match, and a text or prog
parameter.

=over 4

=item after_any_file

Specifies a rule to be invoked at the bottom of any type of file.

=item before_any_file

Specifies a rule to be invoked at the top of any type of file.

=item after_file_body

Specifies a rule to be invoked at the bottom of the class.h file.

=item before_file_body

Specifies a rule to be invoked to produce the #include and other text at
the top of the class.h file.

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
regexp reference (qr/regexp/) which if matches will invoke the rule.

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

=head1 DISTRIBUTION

The latest version is available from CPAN and from L<http://www.veripool.com/>.

Copyright 2001-2005 by Wilson Snyder.  This package is free software; you
can redistribute it and/or modify it under the terms of either the GNU
Lesser General Public License or the Perl Artistic License.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=head1 SEE ALSO

L<vreg>, L<SystemC::Vregs>

=cut

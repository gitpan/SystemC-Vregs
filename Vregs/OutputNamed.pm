# $Revision: #2 $$Date: 2002/12/13 $$Author: wsnyder $
# Author: Wilson Snyder <wsnyder@wsnyder.org>
######################################################################
#
# This program is Copyright 2001 by Wilson Snyder.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of either the GNU General Public License or the
# Perl Artistic License.
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

package SystemC::Vregs::OutputNamed;
use File::Basename;
use Carp;
use vars qw($VERSION);
$VERSION = '1.240';

use SystemC::Vregs::Outputs;
use SystemC::Vregs::Number;
use SystemC::Vregs::Language;
use strict;

# We simply add to the existing package...
package SystemC::Vregs;

######################################################################

sub named_h_write {
    my $self = shift;
    # Dump headers for class name based accessors

    my $fl = SystemC::Vregs::File->open(language=>'C', @_);
    $fl->include_guard();
    $fl->print ("\n");

    $fl->print ("class $self->{name}_named {\n"
		,"public:\n"
		,"    static bool   isClassName(const char* className);\n"
		,"    static int    numClassNames();\n"
		,"    static const char** classNames();\n"
		,"    static void   dumpClass(const char* className, void* datap, OStream& ost=COUT, const char* pf=\"\n\t\");\n"
	        ,"};\n\n");

    $fl->close();
}

sub named_cpp_write {
    my $self = shift;
    # Dump headers for class name based accessors

    my $fl = SystemC::Vregs::File->open(rules => $self->{rules},
					language=>'C', @_);

    $fl->print ("#include \"$self->{name}_named.h\"\n"
	        ."\n");
    $fl->print ("#include \"$self->{name}_class.h\"\n");
		
    $fl->print ("//".('='x68)."\n\n");

    $fl->print ("static const char* $self->{name}_named_classNames[] = {\n");
    my $nclasses=0;
    foreach my $typeref (sort { $a->{name} cmp $b->{name}}  # Else sorted by need of base classes
			 $self->types_sorted) {
	$fl->print ("\t\"$typeref->{name}\",\n");
	$nclasses++;
    }
    $fl->print ("};\n\n");

    $fl->print ("const char** $self->{name}_named::classNames() {\n");
    $fl->print ("    return $self->{name}_named_classNames;\n\n");
    $fl->print ("}\n\n");
    $fl->print ("int $self->{name}_named::numClassNames() {\n"
		,"    return ${nclasses};\n"
		,"}\n\n");

    $fl->print ("bool $self->{name}_named::isClassName(const char* className) {\n");
    $fl->print ("    for (int i=0; i<numClassNames(); i++) {\n"
		,"\tif (0==strcmp(className, $self->{name}_named_classNames[i])) return true;\n"
		,"    }\n");
    $fl->print ("    return false;\n");
    $fl->print ("}\n\n");

    $fl->print ("void $self->{name}_named::dumpClass(const char* className, void* datap, OStream& ost, const char* pf) {\n");
    #$fl->print ("    // Must call .w() functions on each, as each class may have differing endianness\n");
    my $else = "";
    foreach my $typeref ($self->types_sorted) {
	$fl->print ("    ${else}if (0==strcmp(className,\"$typeref->{name}\")) {\n"
		    ,"\t$typeref->{name}* p = ($typeref->{name}*)datap; \n"
		    ,"\tost<<p->dump(pf);\n"
		    ,"    }\n");
	$else = "else "; 
    }
    $fl->print ("}\n\n");

    $self->{rules}->execute_rule ('named_cpp_file_after', 'file_body', $self);

    $fl->close();
}

######################################################################
#### Package return
1;
__END__
=pod

=head1 NAME

SystemC::Vregs::OutputDump - Outputting Vregs _dump Code

=head1 SYNOPSIS

    use SystemC::Vregs::OutputDump;

=head1 DESCRIPTION

This package contains additional SystemC::Vregs methods.  These methods
are used to output various types of files.

=item METHODS

=over 4

=item dump_h_write

Creates a header file for use with dump_named_write.

=item dump_cpp_write

Creates a C++ file which allows textual class names to be mapped
to appopriate pointer types for dumping to a stream.

=back

=head1 SEE ALSO

C<SystemC::Vregs::Output>

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=cut

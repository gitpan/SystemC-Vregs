#// $Revision: #1 $$Date: 2002/09/16 $$Author: lab $ -*- C++ -*-
#// DESCRIPTION: SystemC::Vregs::Rules file: Perl code Vregs parses to produce .h file
#// ** This is a PERL file, but highlighted as C++ instead of Perl
#//    since there's more C++ code here then perl code!

before_file_body (text => <<EOT
#define INSERTED__before_file_body
EOT
    );

#//======================================================================
#// Enums

before_enum_end (
    name => 'ExEnum',
    text => <<EOT
#define INSERTED__ENUM
EOT
    );

#//======================================================================
#// Classes

before_class_begin (
    name => qr/.*/,
    prog => sub {
	fprintf("#define INSERTED__before_class_top__%s\n",
		$self->{name});
    },);

after_class_begin (
    name => qr/.*/,
    prog => sub {
	fprintf("#define INSERTED__after_class_top__%s\n",
		$self->{name});
    },);

before_class_end (
    name => qr/.*/,
    prog => sub {
	fprintf("#define INSERTED__before_class_end__%s\n",
		$self->{name});
    },);

after_class_end (
    name => qr/.*/,
    prog => sub {
	fprintf("#define INSERTED__after_class_end__%s\n",
		$self->{name});
    },);

before_class_cpp (
    name => qr/.*/,
    prog => sub {
	fprintf("#define INSERTED__before_class_cpp__%s\n",
		$self->{name});
    },);

after_class_cpp (
    name => qr/.*/,
    prog => sub {
	fprintf("#define INSERTED__after_class_cpp__%s\n",
		$self->{name});
    },);

#// Good exit status
1;

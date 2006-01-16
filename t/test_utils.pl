# $Id: test_utils.pl 12022 2006-01-16 21:55:21Z wsnyder $
# DESCRIPTION: Perl ExtUtils: Common routines required by package tests
#
# Copyright 2001-2006 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.

use vars qw($PERL $GCC $GCCC);

$PERL = "$^X -Iblib/arch -Iblib/lib";
$GCC  = "g++ -Wall -Werror -I. -I../t -I../include ";
$GCCC = "gcc -Wall -Werror -I. -I../t -I../include ";

mkdir 'test_dir',0777;

use lib "../Verilog/blib/lib";	# For maintainer testing in project areas
use lib "../Verilog/blib/arch";	# For maintainer testing in project areas
if (!$ENV{HARNESS_ACTIVE}) {
    use lib "blib/lib";
    use lib "blib/arch";
}

sub run_system {
    # Run a system command, check errors
    my $command = shift;
    print "\t$command\n";
    system "$command";
    my $status = $?;
    ($status == 0) or die "%Error: Command Failed $command, $status, stopped";
}

1;

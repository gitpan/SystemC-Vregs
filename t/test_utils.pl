# $Revision: #13 $$Date: 2004/07/22 $$Author: ws150726 $
# DESCRIPTION: Perl ExtUtils: Common routines required by package tests
#
# Copyright 2001-2004 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.

use vars qw($PERL $GCC);

$PERL = "$^X -Iblib/arch -Iblib/lib";
$GCC  = "g++ -Wall -Werror -I. -I../include ";

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

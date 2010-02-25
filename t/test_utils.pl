# DESCRIPTION: Perl ExtUtils: Common routines required by package tests
#
# Copyright 2001-2010 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License Version 3 or the Perl Artistic License Version 2.0.

use IO::File;
use vars qw($PERL $GCC $GCCC);

$PERL = "$^X -Iblib/arch -Iblib/lib -I../Verilog/blib/lib -I../Verilog/blib/arch";
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

sub wholefile {
    my $file = shift;
    my $fh = IO::File->new ($file) or die "%Error: $! $file";
    my $wholefile = join('',$fh->getlines());
    $fh->close();
    return $wholefile;
}

1;

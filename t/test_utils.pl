#!/usr/local/bin/perl -w
# $Revision: #8 $$Date: 2002/07/16 $$Author: wsnyder $
#DESCRIPTION: Perl ExtUtils: Common routines required by package tests

use vars qw($PERL $GCC);

$PERL = "$^X -Iblib/arch -Iblib/lib";
$GCC  = "g++ -Wall -Werror -I. -I../include ";

mkdir 'test_dir',0777;

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

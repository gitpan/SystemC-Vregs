#!/usr/local/bin/perl -w
# $Id: test_utils.pl,v 1.7 2002/03/11 14:07:22 wsnyder Exp $
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

# $Id: TableExtract.pm,v 1.11 2001/06/27 16:10:23 wsnyder Exp $
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

package SystemC::Vregs::TableExtract;

@ISA = qw(HTML::TableExtract);
$VERSION = '0.1';

use strict;
use vars qw($Debug %Find_Start_Headers %Find_Headers);
use HTML::TableExtract;

%Find_Start_Headers = (Class=>1,
		       Package=>1,
		       Defines=>1,
		       Enum=>1,
		       Register=>1,
		       );
%Find_Headers = (%Find_Start_Headers,
		 Address=>1,
		 Attributes=>1,
		 );

######################################################################
#### Parsing

sub parse_file {
    my $self = shift;
    my $filename = shift;
    my $fh = IO::File->new ($filename) or die "%Error: $! $filename\n";
    $self->{_fh} = $fh;
    $self->{_vregs_filename} = $filename;
    $self->{_vregs_num_tables} = -1;
    $self->SUPER::parse_file ($fh);
    $fh->close();
}

sub clean_html_text {
    $_ = shift;
    s/[\t\n\r ]+/ /g;
    s/^\s+//;
    s/\s+$//;
    s/\222/\'/g;
    s/\226/-/g;
    s/\240//g;	# Nonbreakable space
    return $_;
}

sub end {
    my $self = shift;
    if ($_[0] eq 'p') {
	if (!$self->{_vregs_first_endp}) {
	    $self->{_vregs_first_endp} = 1;
	} else {
	    $self->{_vregs_next_tag} = undef;
	}
    }
    $self->SUPER::end (@_);
}

sub text {
    my $self = shift;
    # Don't bother if we are in a table
    if (! $self->{_in_a_table}) {
	$_ = $_[0];
	my $text = clean_html_text($_);
	if ($text ne ""
	    && $text !~ /^</) {
	    if ($Find_Headers{$text}) {
		if ($Find_Start_Headers{$text}) {
		    # Process previous entry, and prepare for next discovery
		    my $pack = $self->{_vregs_pack};
		    $pack->new_item([], $self->{_vregs_next});  # note no table
		    $self->{_vregs_next} = undef;
		}
		# If anyone knows how to get line #, do tell.
		$self->{_vregs_next}{at} = ($self->{_vregs_filename}
					    .":char#".$self->{_fh}->tell());
		$self->{_vregs_next_tag} = $text;
                $self->{_vregs_next}{$self->{_vregs_next_tag}} = "";
                $self->{_vregs_first_endp} = 0;
	    }
	    elsif ($self->{_vregs_next_tag}) {
		print "TAG $self->{_vregs_next_tag} $text\n" if $Debug;
		$self->{_vregs_next}{$self->{_vregs_next_tag}} .= $text;
	    }
	}
	my @tables = $self->table_states();
	my $numtables = ();
	if ($#tables != $self->{_vregs_num_tables}) {
	    $self->{_vregs_num_tables} = $#tables;
	    my $table = $tables[$#tables];
	    # Clean up the table to remove extra spaces in the tables
	    my @bittable = ($table->rows);
	    foreach my $row (@bittable) {
		@$row = map {
		    $_ = clean_html_text($_);
		    $_ =~ s/<[^>]+>//ig; #$_="" if /SupportEmptyParas/i;  # Microsloth Word junk
		    $_ =~ s/[ \t\n\r]+$//sig;
		    $_;
		} @$row;
	    }
	    # Process this, and prepare for next discovery
	    my $pack = $self->{_vregs_pack};
	    $pack->new_item(\@bittable, $self->{_vregs_next});
	    $self->{_vregs_next} = undef;
	}
    }
    $self->SUPER::text (@_);
}

######################################################################
#### HTML cleaning

sub clean_html_file {
    my $filename = shift;
    # Word puts so much XML &*(#@$ in the file... Strip it so it's more obvious.

    my $wholefile;
    {
	my $fh = IO::File->new($filename) or die "%Error: $! $filename\n";
	local $/;
	undef $/;
	$wholefile = <$fh>;
	$fh->close;
    }

    $wholefile =~ s%\r%%smg;
    $wholefile =~ s%<!--.*?-->%%smg;
    $wholefile =~ s%[ \n]style='.*?'%%smg;
    $wholefile =~ s%[ \n]style=".*?"%%smg;
    $wholefile =~ s% border=0 % border=1 %smg;
    $wholefile =~ s%<\/?span\s*>%%smg;
    $wholefile =~ s%<\/?o:p>%%smg;
    $wholefile =~ s% width=\d+ % %smg;

    my $fh = IO::File->new(">$filename") or die "%Error: $! writing $filename\n";
    print $fh $wholefile;
    $fh->close;
}

######################################################################
#### Package return
1;
__END__

=pod

=head1 NAME

SystemC::Vregs::TableExtract - Superclass of HTML::TableExtract for vregs usage

=head1 SYNOPSIS


=head1 DESCRIPTION

SystemC::Vregs::TableExtract is a superclass of HTML::TableExtract which
understands how to extract text and tables from HTML documents, and invoke
callbacks as Vregs sections are encountered.

It is designed to be used by SystemC::Vregs only.

=head1 SEE ALSO

HTML::TableExtract

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=cut

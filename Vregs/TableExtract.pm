# $Revision: #30 $$Date: 2003/09/04 $$Author: wsnyder $
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

package SystemC::Vregs::TableExtract;

@ISA = qw(HTML::TableExtract);
$VERSION = '1.242';

use strict;
use vars qw($Debug %Find_Start_Headers %Find_Headers);
use IO::File;
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
    $self->start("p");
    $self->text("Register");
    $fh->close();
}

sub clean_html_text {
    $_ = shift;
    s/\&nbsp;/ /g;	# Why didn't HTML::TableExtract handle this?
    s/\&\#8209;/-/g;	# Unicode nonbreaking hyphen (0x2011)
    s/\240/ /g;		# ISO-Latin1 nonbreaking space
    s/\255//g;		# ISO-Latin1 soft hyphen
    s/[\t\n\r ]+/ /g;
    s/^\s+//;
    s/\s+$//;
    s/\`/\'/g;
    # HTML escapes
    s/&ldquo;/\'/g;	# ISO-Latin1 left single-quote
    s/&rdquo;/\'/g;	# ISO-Latin1 right single-quote
    # Substituting 2 or 3 periods for 'elipses' causes Vspecs to truncate
    # the field description at the periods, so use dashes.
    s/\205/--/g;	# ISO-Latin1 horizontal elipses (0x85)
    s/\221/\'/g;	# ISO-Latin1 left single-quote
    s/\222/\'/g;	# ISO-Latin1 right single-quote
    s/\223/\"/g;	# ISO-Latin1 left double-quote
    s/\224/\"/g;	# ISO-Latin1 right double-quote
    s/\225/\*/g;	# ISO-Latin1 bullet
    s/\226/-/g;		# ISO-Latin1 en-dash (0x96) (Unicode &#8211;)
    s/\227/--/g;	# ISO-Latin1 em-dash (0x97) (Unicode &#8212;)
    s/\267/\*/g;	# ISO-Latin1 middle dot (0xB7)
    return $_;
}

sub start {
    my $self = shift;
    if ($_[0] eq 'p') {
	#print "<p>\n" if $Debug;
	$self->{_vregs_first_word_in_p} = 1;
    }
    $self->SUPER::start (@_);
}

sub end {
    my $self = shift;
    if ($_[0] eq 'p') {
	print "<\/p>\n" if $Debug;
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
	printf "Text %s: %s: %s",$self->{_fh}->tell()
	    ,($self->{_vregs_first_word_in_p}?"FW":"  "),"$_\n" if $Debug;
	my $text = clean_html_text($_);
	if ($text !~ /^\s*$/
	    && $text !~ /^</) {
	    if ($self->{_vregs_first_word_in_p}
		&& $Find_Headers{$text}) {
		print "Keyword $text\n" if $Debug;
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
	$self->{_vregs_first_word_in_p} = 0 if ($text !~ /^\s*$/);
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
	    print ::Dumper(\@bittable, $self->{_vregs_next}) if $Debug;
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

    # Microsoft Word changebars
    $wholefile =~ s%<a href=\"#author\d+">\[Author\s+\S+:\s+at\s+\S+\s+\S+\s+\d+\s+\S+\s+\d+\s*\]\s*</a>%%smg;

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

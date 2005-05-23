# $Revision: 1.48 $$Date: 2005-05-23 10:23:27 -0400 (Mon, 23 May 2005) $$Author: wsnyder $
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

package SystemC::Vregs::TableExtract;

@ISA = qw(HTML::TableExtract);
$VERSION = '1.261';

use strict;
use vars qw($Debug %Find_Start_Headers %Find_Headers);
use IO::File;
use HTML::TableExtract;
use HTML::Entities ();

%Find_Start_Headers = (Class=>1,
		       Package=>1,
		       Defines=>1,
		       Enum=>1,
		       Register=>1,
		       TableExtract_End_Of_File=>1,
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
    $self->text("TableExtract_End_Of_File");
    $fh->close();
}

sub clean_html_text {
    $_ = shift;
    # HTML escapes to normal Latin1 ASCII
    $_ = HTML::Entities::decode($_);
    # Hack: Decode two-byte UTF-8 chars without checking that the HTML body
    # uses UTF-8 encoding.  wvHtml writes HTML in UTF-8 encoding when the
    # .doc file comes from StarOffice7.
    s{[\302\303].}{
	my ($a, $b) = unpack("CC", $&);
	(($b & 0xC0) != 0x80 ? $&	# Not a 2-byte UTF-8 char.
	 : pack("C", ($a & 0x3)<<6 | ($b & 0x3f) ))
    }eg;
    # Latin1 decoding
    # Substituting 2 or 3 periods for 'elipses' causes Vspecs to truncate
    # the field description at the periods, so use dashes.
    s/\205/-/g;		# ISO-Latin1 horizontal elipses (0x85)
    s/\221/\'/g;	# ISO-Latin1 left single-quote
    s/\222/\'/g;	# ISO-Latin1 right single-quote
    s/\223/\"/g;	# ISO-Latin1 left double-quote
    s/\224/\"/g;	# ISO-Latin1 right double-quote
    s/\225/\*/g;	# ISO-Latin1 bullet
    s/\226/-/g;		# ISO-Latin1 en-dash (0x96)
    s/\227/-/g;		# ISO-Latin1 em-dash (0x97)
    s/\230/~/g;		# ISO-Latin1 small tilde
    s/\233/>/g;		# ISO-Latin1 single right angle quote
    s/\240/ /g;		# ISO-Latin1 nonbreaking space
    s/\246/\|/g;	# ISO-Latin1 broken vertical bar
    s/\255//g;		# ISO-Latin1 soft hyphen (0xAD)
    s/\264/\'/g;	# ISO-Latin1 spacing acute
    s/\267/\*/g;	# ISO-Latin1 middle dot (0xB7)
    # These are automatically removed by HTML::Entities in Perl 5.7 and greater
    # Also decode unicode sequences decoded by perl 5.8.*
    s/\&\#8209;/-/g;	# ISOpub nonbreaking hyphen (U+2011, &#8209;)
    s/\&\#8211;/-/g;	s/\&ndash;/-/g;  s/\342\200\041/\-/g;	# ISOpub en-dash (U+2013, &#8211;)
    s/\&\#8212;/-/g;	s/\&mdash;/-/g;  s/\342\200\042/\-/g;	# ISOpub em-dash (U+2014, &#8212;)
    s/\&\#8216;/\'/g;	s/\&lsquo;/\'/g; s/\342\200\176/\`/g;	# ISOnum left single-quote (U+2018, &#8216;)
    s/\&\#8217;/\'/g;	s/\&rsquo;/\'/g; s/\342\200\177/\`/g;	# ISOnum right single-quote (U+2019, &#8217;)
    ; 					 s/\342\200\230/\`/g;	# ISOnum left single-quote (U+2018, &#8216;)
    ; 					 s/\342\200\231/\`/g;	# ISOnum right single-quote (U+2019, &#8217;)
    s/\&\#8220;/\"/g;	s/\&ldquo;/\"/g; s/\342\200\234/\"/g;	# ISOnum left double-quote (U+201C, &#8220;)
    s/\&\#8221;/\"/g;	s/\&rdquo;/\"/g; s/\342\200\235/\"/g;	# ISOnum right double-quote (U+201D, &#8221;)
    s/\&\#8230;/-/g;	s/\&hellip;/-/g; s/\342\200\174/-/g;	# ISOpub horizontal elipses (U+2026, &#8230;)
    # Compress spacing
    s/\`/\'/g;
    s/[\t\n\r ]+/ /g;
    s/^ *//g;
    return $_;
}

sub start {
    my $self = shift;
    if ($_[0] eq 'p' || $_[0] =~ /^h[0-9]/) {
	#print "<p>\n" if $Debug;
	$self->{_vregs_first_word_in_p} = 1;
    }
    $self->SUPER::start (@_);
}

sub end {
    my $self = shift;
    if ($_[0] eq 'p') {
	print "<\/$_[0]>\n" if $Debug;
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
	my $text = $_[0];
	if ($Debug) {
	    (my $printtext = $text) =~ s/[\n \t]+/ /g;
	    printf +("Text %s: %s:|%s|\n", $self->{_fh}->tell(),
		     ($self->{_vregs_first_word_in_p}?"FW":"  "),$printtext);
	}
	$text = clean_html_text($text);
	if ($text !~ /^\s*$/
	    && $text !~ /^</) {
	    my $nosp_text = $text;
	    if ($self->{_vregs_first_word_in_p}) {
		$nosp_text =~ s/^\s+//; $nosp_text =~ s/\s+$//;
		# Per W3C HTML spec, "SGML specifies that a line break immediately
		# following a start tag must be ignored, as must a line break
		# immediately before an end tag.  This applies to all HTML elements
		# without exception."
		# And, "For all HTML elements except PRE, sequences of white space
		# separate words."
		# Sadly, the HTML parser did not take care of this for us.
		$text = $nosp_text;
	    }
	    if ($self->{_vregs_first_word_in_p}
		&& $Find_Headers{$nosp_text}) {
		print "Keyword '$text'\n" if $Debug;
		if ($Find_Start_Headers{$text}
		    && $self->{_vregs_next}) {
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
                $self->{_vregs_next} = undef if $text eq 'TableExtract_End_Of_File';
	    }
	    elsif ($self->{_vregs_next_tag}) {
		print "TAG '$self->{_vregs_next_tag}' '$text'\n" if $Debug;
		$self->{_vregs_next}{$self->{_vregs_next_tag}} .= $text;
	    }
	}
	$self->{_vregs_first_word_in_p} = 0 if ($text !~ /^\s*$/);
	my @tables = $self->table_states();
	my $numtables = ();
	if ($#tables != $self->{_vregs_num_tables}) {
	    $self->{_vregs_num_tables} = $#tables;
	    if ($self->{_vregs_next}) {  # else a table outside of a register decl
		my $table = $tables[$#tables];
		# Clean up the table to remove extra spaces in the tables
		my @bittable = ($table->rows);
		foreach my $row (@bittable) {
		    @$row = map {
			$_ = clean_html_text($_);
			$_ =~ s/<[^>]+>//ig; #$_="" if /SupportEmptyParas/i;  # Microsloth Word junk
			$_ =~ s/^[ \t\n\r]+//sig;
			$_ =~ s/[ \t\n\r]+$//sig;
			$_;
		    } @$row;
		}
		# Process this, and prepare for next discovery
		my $pack = $self->{_vregs_pack};
		print ::Dumper(\@bittable, $self->{_vregs_next}) if $Debug;
		$pack->new_item(\@bittable, $self->{_vregs_next});
		$self->{_vregs_next} = undef;
		$self->{_vregs_next_tag} = undef;
	    }
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
    $wholefile =~ s%<!\[if !supportEmptyParas\]>\&nbsp;<!\[endif\]>%%smg;

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

=head1 DISTRIBUTION

The latest version is available from CPAN and from L<http://www.veripool.com/>.

Copyright 2001-2005 by Wilson Snyder.  This package is free software; you
can redistribute it and/or modify it under the terms of either the GNU
Lesser General Public License or the Perl Artistic License.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=head1 SEE ALSO

L<HTML::TableExtract>

=cut

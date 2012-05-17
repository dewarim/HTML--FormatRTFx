package HTML::FormatRTFx;

use strict;
use warnings;
use base 'HTML::FormatRTF';
use Data::Dumper;

my $PAGE_PX_WIDTH = 800; # assume a base page width of 800px (for wkhtml2pdf)

# mapping for fonts: use {\f$font_map{lc(font_name)} text} to add a font.
my %font_map = (
	"courier new" => 3,
	"lucida console" => 4,
	"arial"	=> 5,
	"times new roman" => 6,
	"bookman" => 7,
	"georgia" => 8,
	"tahoma" => 9,
	"lucida sans" => 10,
	"verdana" => 11
);

# ------------------------------------------------------------------------
# replace Format::RTF->begin() so we can set the page width etc.
sub begin {
    my $self = shift;

    ### Start document...
    $self->HTML::Formatter::begin;

    $self->collect( $self->doc_init, $self->font_table, $self->stylesheet, $self->color_table, $self->doc_info,
    	$self->doc_format,
	$self->doc_really_start, "\n" )
	unless $self->{'no_prolog'};

    $self->{'Para'}       = '';
    $self->{'quotelevel'} = 0;

    return;
}

sub default_values {
    (   shift->SUPER::default_values(),
		paperw => 11906, # A4 page width
		paperh => 16839, # A4 page height
		margl => 1800, # default margin left
		margr => 1800, # default margin right
		margt => 1440, # default top margin
		margb => 1440, # default bottom margin
    );
}

sub doc_format{
	my $self = shift;
	$self->out(\'\paperw'.$self->{'paperw'});
	$self->out(\'\paperh'.$self->{'paperh'});
	$self->out(\'\margl'.$self->{'margl'});
	$self->out(\'\margr'.$self->{'margr'});
	$self->out(\'\margt'.$self->{'margt'});
	$self->out(\'\margb'.$self->{'margb'});
}

sub table_start{
	my $self = shift;

	# print STDERR Dumper($self);
	$self->out(\'');
}

sub tr_start{
	my $self = shift;

	my $node = shift;
	my $tag = $node->tag;

	my @cells = grep { $_->tag =~ /td|th/   } $node->descendants();
	my $cell_count = @cells;
	my $twips_width = $self->{'paperw'} - $self->{'margr'} - $self->{'margl'}; # page width - left and right margin.
	my $cell_padding = 10;
	$twips_width = $twips_width - 20 - $cell_count * $cell_padding ; # subtract 20twips left border, minus 10 for each cellpadding.

	# debugging.
	# pard: reset paragraph style to default
	# trowd: begin table row
	# trgaphN: "Half the space between the cells of a table row in twips."
	# trleftN: "Position of the leftmost edge of the table with respect to the left edge of its column."
#	$self->out( \"{\\pard\\trowd\\trgaph10\\trleft10");
	$self->out( \"{\\trowd\\trgaph10\\trleft10");

	my $current_cell_end = 0;
	foreach my $cell (@cells){
		my $width = $cell->attr('width');
#		if($cell_count == 1){
#			$width = 100;
#		}
		my $base_cell_width = $twips_width / $cell_count;
		if($width =~ m/.+/){
		  if($width =~ m/\%/){
			$width =~ s/\%//;
			$base_cell_width = $twips_width * $width / 100;
		      }
		  else{
		    $width =~ s/(?:\.00)px//; # remove irrelvant part of 240.00px
		    my $factor = ($width / $PAGE_PX_WIDTH);
#		    print "factor: $factor\n";
		    $base_cell_width = $twips_width * $factor;

		  }
		}
#		print "width: $width // $base_cell_width\n";
		$current_cell_end = $current_cell_end + int ($base_cell_width) + $cell_padding;
		$self->out( \"\\cellx$current_cell_end" );
	}
	$self->out(\"\n");
}

sub tr_end{
	my $self = shift;
	$self->out( \"\\row\\pard\\par}\n");
}

sub td_start{
	my $self = shift;
	my $node = shift;
	$self->out( \'\pard\intbl' );
#	$self->out( \'\pard\par\intbl' );
	$self->{'insideTable'} = 1;
	my $alignment = $node->attr('align');
	if($alignment){
		# use if-else, because it seems like the webserver is still on perl 5.8
		if($alignment eq 'left'){
			$self->out(\'\ql');
		}
		elsif($alignment eq 'right'){
			$self->out(\'\qr');
		}
		elsif($alignment eq 'center'){
			$self->out(\'\qc');
		}
		elsif($alignment eq 'justify'){
			$self->out(\'\qj');
		}
		# html has attribute value 'char', rtf has possible align "qd (distributed)"
		# both do not have an obvious match to the other side.
	}

	$self->out(' ');
}

sub td_end{
	my $self = shift;
	$self->{'insideTable'} = 0;
	$self->out( \" \\cell\n");
}

sub th_start{
	my $self = shift;
	$self->{'insideTable'} = 1;
	$self->out( \'\pard\intbl \b ' );
}

sub th_end{
	my $self = shift;
	$self->{'insideTable'} = 0;
	$self->out( \" \\cell\n");
}

# param is style string like 'font-size: 16pt; color:black;'
# return font size in pt
sub determine_font_size{
	my $style = shift;
#	use CSS;
#	$css->read_string($style); # does not work.
#	my $css = CSS->new();
#	print STDERR $css->output();

	# currently, we expect font-size to be in pt and not in px etc.
	my ($font_size) = $style =~ m{font-size:\s*(\d+)\s*pt};
	return $font_size;
}

# param is style string like 'font-size: 16pt;font-family: Arial;'
# return font name if it's contained in font_map.
sub determine_font{
	my $style = shift;

	my @fonts = $style =~ m{font-family:
		\s*
		(?:
		'? #'Times New Roman'
		([^,]+) # no , like in "Times, serif"
		'?
		,?
		)+;
	}gx;
	@fonts = map {lc($_)} @fonts;
	# font-family: verdana, sans-serif;
	# font-family: 'Times New Roman',Times,serif
	my $font_number;
	foreach my $font_name (@fonts){
		if($font_map{$font_name}){
			$font_number = $font_map{$font_name};
			last;
		}
	}

	return $font_number;
}

sub add_font_size{
	my $self = shift;
	my $size = shift;
	$self->out( \("{\\fs".($size*2)." ")); # point size * 2 = twips size.
}

sub add_font{
	my $self = shift;
	my $font_number = shift;
	$self->out( \("{\\f".$font_number." "));
}


sub start_style_check{
	my $self = shift;
	my $node = shift;

	my $style = $node->attr('style');
	if( $style ){
		my $font_number = determine_font($style);
		if($font_number){
			$self->add_font($font_number);
		}
		my $font_size = determine_font_size($style);
		if($font_size){
			$self->add_font_size($font_size);
		}
		if(! $font_number && ! $font_size){
			$self->out(\'');
		}
	}
	$self->out(\'');

}

sub end_style_check{
	my $self = shift;
	my $node = shift;

	my $style = $node->attr('style');
	if($style){
		my $font_number = determine_font($style);
		if($font_number){
			$self->out(\"}\n");
		}
		my $font_size =determine_font_size($style);
		if($font_size){
			# close font size block.
			$self->out(\"}\n");
		}
	}
	$self->out(\'');
}

sub div_start{
	my $self = shift;
	my $node = shift;
	$self->start_style_check($node);
}

sub div_end{
	my $self = shift;
	my $node = shift;
	$self->end_style_check($node);
}

# overridden from Format::RTF
# added font list taken from RTF Pocket Guide
sub font_table {
    my $self = shift;

    return sprintf <<'END' ,    # text font, code font, heading font
{\fonttbl
{\f0\froman %s;}
{\f1\fmodern %s;}
{\f2\fswiss %s;}
{\f3\fmodern Courier New;}
{\f4\fmodern Lucida Console;}
{\f5\froman Arial;}
{\f6\froman Times;}
{\f7\froman Bookman;}
{\f8\froman Georgia;}
{\f9\fswiss Tahoma;}
{\f10\fswiss Lucida Sans;}
{\f11\fswiss Verdana;}
}

END

	map {
	;                       # custom-dumb escaper:
	my $x = $_;
	$x =~ s/([\x00-\x1F\\\{\}\x7F-\xFF])/sprintf("\\'%02x", $1)/g;
	$x =~ s/([^\x00-\xFF])/'\\uc1\\u'.((ord($1)<32768)?ord($1):(ord($1)-65536)).'?'/eg;
	$x;
	}
	$self->{'fontname_body'}     || 'Times',
	$self->{'fontname_code'}     || 'Courier New',
	$self->{'fontname_headings'} || 'Arial',
	;
}


# ------------------------------------------------------------------------
sub emit_para {    # rather like showline in FormatPS
    my $self = shift;

    my $para = $self->{'Para'};
    $self->{'Para'} = undef;

    #### emit_para called by: (caller(1) )[3];

    unless ( defined $para ) {
        #### emit_para with empty buffer...
        return;
    }
    
    $para =~ s/^ +//s;
    $para =~ s/ +$//s;

    # And now: a not terribly clever algorithm for inserting newlines
    # at a guaranteed harmless place: after a block of whitespace
    # after the 65th column.  This was copied from RTF::Writer.
    $para =~ s/(
       [^\cm\cj\n]{65}        # Snare 65 characters from a line
       [^\cm\cj\n\x20]{0,50}  #  and finish any current word
      )
      (\x20{1,10})(?![\cm\cj\n]) # capture some spaces not at line-end
     /$1$2\n/gx    # and put a NL before those spaces
        ;

    # if the paragraph is in a table, we need \intbl
    my $intbl = "";

# if emit_para had the node param, we could use this:
#    my $lineage = join(" ", $node->lineage_tag_names());
#    if($lineage =~ m/td|th/){
#     # $self->out(\'\\intbl');
#      $intbl = "\\intbl";
#    }
# because to get $node through several layers of subroutine calls, 
# I would have to rewrite the parent module.
    if($self->{'insideTable'}){
      $intbl = "\\intbl";
    }

    #print "para: $para\n";
    $self->collect(
        sprintf(
            '{\pard\sa%d\li%d\ri%d%s\plain' . "\n",
#            '\pard\sa%d\li%d\ri%d%s\plain' . "\n",
            #100 +
            10 * $self->{'normal_halfpoint_size'} * ( $self->{'vspace'} || 0 ),

            $self->{'lm'},
            $self->{'rm'},

            $self->{'center'} ? '\qc' : '\ql',
        ),

        defined( $self->{'next_bullet'} )
        ? do {
            my $bullet = $self->{'next_bullet'};
            $self->{'next_bullet'} = undef;
            sprintf "\\fi-%d\n%s",
                4.5 * $self->{'normal_halfpoint_size'},
                ( $bullet eq '*' ) ? "\\'95 " : ( rtf_esc($bullet) . ". " );
            }
        : (),

        $para,
        "\n\\par$intbl}\n\n",
#        "\n\\par$intbl\n\n",
    );

    $self->{'vspace'} = undef;    # we finally get to clear it here!

    return;
}



1;

=head1 DESCRIPTION

This is an extension to HTML::FormatRTF which provides support for tables, some fonts and
some simple heuristics to evaluate style and align attributes in HTML.

Based on L<HTML::FormatRTF>, look there for additional information.

=head2 TODO

=over

=item *

Add documentation

=item *

Add more configuration options

=item *

Parse more CSS features and external CSS files

=item *

Add tests

=item *

Add to Format::RTF and submit to CPAN / current maintainer.

=back

=head1 SEE ALSO

L<HTML::Formatter>, L<HTML::FormatRTF>

=head1 AUTHORS

Ingo Wiarda <ingo_wiarda@dewarim.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Ingo Wiarda

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

__END__

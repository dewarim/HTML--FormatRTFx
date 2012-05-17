use warnings;
use strict;
use feature 'unicode_strings';
use lib '.';
use File::Slurp;
use HTML::FormatRTFx;


if(@ARGV < 2){
    print "Usage: perl HtmlToRtf.pl inputFile outputFile\n";
    exit;
}

my $inputFile = $ARGV[0];
my $outputFile = $ARGV[1];

my $utf_text = read_file( $inputFile, binmode => ':utf8' ) ;

open(my $fh, '>', $outputFile) or die("Could not open file $outputFile for output: $!");

# remove extra whitespace, otherwise HTML::FormatRTF will try to insert it as verbatim whitespace:
$utf_text =~ s/\s{2,}/ /gm;
#print $utf_text;
my $result = HTML::FormatRTFx->format_string($utf_text);

print $fh $result;

close($fh) or die("Could not close file $outputFile. $!");
print $result;
#my $formatter = HTML::FormatRTFx->new;
#$formatter->format_string($utf_text);


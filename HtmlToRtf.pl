use warnings;
use strict;
use feature 'unicode_strings';
use lib '.';
use File::Slurp;
use HTML::FormatRTFx;


my $utf_text = read_file( 'test/test.html', binmode => ':utf8' ) ;
print HTML::FormatRTFx->format_string($utf_text);



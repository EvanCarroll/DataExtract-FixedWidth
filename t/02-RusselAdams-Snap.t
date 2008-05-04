#!/usr/bin/env perl
## AIX Example provided by Russel Adams
## .....    lspv -p hdisk0
## Column headers explicitly provided
use strict;
use warnings;

use feature ':5.10';

use Test::More tests => 12;
use DataExtract::FixedWidth;

my $fw;
while ( my $line = <DATA> ) {

	if ( $. == 1 ) {
		$fw = DataExtract::FixedWidth->new({
			header_row => $line
			, cols     => [
				qw/STATE REGION TYPE/
				, 'PP RANGE'
				, 'MOUNT POINT'
				, 'LV NAME'
			]
		});
	}
	else {
		my $arrRef = $fw->parse( $line );
		my $hashRef = $fw->parse_hash( $line );

		given ( $. ) {
			when ( 2 ) {
				ok ( $hashRef->{'PP RANGE'} eq '1-1', "Testing output (->parse_hash)" );
				ok ( $hashRef->{'REGION'} eq 'outer edge', "Testing output (->parse_hash)" );
				ok ( $hashRef->{'MOUNT POINT'} eq 'N/A', "Testing output (->parse_hash)" );
				
				ok ( $arrRef->[0] eq '1-1', "Testing output (->parse)" );
				ok ( $arrRef->[2] eq 'outer edge', "Testing output (->parse)" );
				ok ( $arrRef->[5] eq 'N/A', "Testing output (->parse)" );
			};
			when ( 8 ) {
				ok ( $hashRef->{'PP RANGE'} eq '205-217', "Testing output (->parse_hash)" );
				ok ( $hashRef->{'REGION'} eq 'outer middle', "Testing output (->parse_hash)" );
				ok ( $hashRef->{'MOUNT POINT'} eq '', "Testing output (->parse_hash)" );
				
				ok ( $arrRef->[0] eq '205-217', "Testing output (->parse)" );
				ok ( $arrRef->[2] eq 'outer middle', "Testing output (->parse)" );
				ok ( $arrRef->[5] eq '', "Testing output (->parse)" );
			};
		};

	}

}

__DATA__
PP RANGE  STATE   REGION        LV NAME             TYPE       MOUNT POINT
  1-1     used    outer edge    hd5                 boot       N/A
  2-109   free    outer edge                                   
110-117   used    outer middle  hd6                 paging     N/A
118-164   used    outer middle  fslv00              jfs2       /images
165-188   used    outer middle  hd6                 paging     N/A
189-204   used    outer middle  fslv00              jfs2       /images
205-217   free    outer middle                                 
218-218   used    center        hd8                 jfs2log    N/A
219-219   used    center        hd4                 jfs2       /
220-220   used    center        hd2                 jfs2       /usr
221-221   used    center        hd9var              jfs2       /var
222-222   used    center        hd3                 jfs2       /tmp
223-223   used    center        hd1                 jfs2       /home
224-224   used    center        hd10opt             jfs2       /opt
225-229   used    center        hd2                 jfs2       /usr
230-230   used    center        hd10opt             jfs2       /opt
231-232   used    center        hd2                 jfs2       /usr
233-235   used    center        hd3                 jfs2       /tmp
236-264   used    center        hd10opt             jfs2       /opt
265-325   free    center                                       
326-433   free    inner middle                                 
434-542   free    inner edge                                   

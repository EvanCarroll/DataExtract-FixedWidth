#!/usr/bin/env perl
## Example from http://en.wikipedia.org/w/index.php?title=Flat_file_database&oldid=209112999
## Default options with column header name deduction
use strict;
use warnings;

use feature ':5.10';

use Test::More tests => 18;
use DataExtract::FixedWidth;

my $fw;
while ( my $line = <DATA> ) {

	if ( $. == 1 ) {
		$fw = DataExtract::FixedWidth->new({
			header_row => $line
		});
	}
	else {
		my $arrRef = $fw->parse( $line );
		my $hashRef = $fw->parse_hash( $line );

		given ( $. ) {
			when ( 2 ) {
				ok ( $hashRef->{name} eq 'Amy', "Testing output (->parse_hash)" );
				ok ( $hashRef->{team} eq 'Blues', "Testing output (->parse_hash)" );
				ok ( $hashRef->{id} eq '1', "Testing output (->parse_hash)" );
				
				ok ( $arrRef->[0] eq '1', "Testing output (->parse)" );
				ok ( $arrRef->[1] eq 'Amy', "Testing output (->parse)" );
				ok ( $arrRef->[2] eq 'Blues', "Testing output (->parse)" );
			};
			when ( 6 ) {
				ok ( $hashRef->{id} eq '5', "Testing output (->parse_hash)" );
				ok ( $hashRef->{name} eq 'Ethel', "Testing output (->parse_hash)" );
				ok ( $hashRef->{team} eq 'Reds', "Testing output (->parse_hash)" );
				
				ok ( $arrRef->[0] eq '5', "Testing output (->parse)" );
				ok ( $arrRef->[1] eq 'Ethel', "Testing output (->parse)" );
				ok ( $arrRef->[2] eq 'Reds', "Testing output (->parse)" );
			};
			when ( 9 ) {
				ok ( $hashRef->{id} eq '8', "Testing output (->parse_hash)" );
				ok ( $hashRef->{name} eq 'Hank', "Testing output (->parse_hash)" );
				ok ( $hashRef->{team} eq 'Reds', "Testing output (->parse_hash)" );
				
				ok ( $arrRef->[0] eq '8', "Testing output (->parse)" );
				ok ( $arrRef->[1] eq 'Hank', "Testing output (->parse)" );
				ok ( $arrRef->[2] eq 'Reds', "Testing output (->parse)" );
			};
		};

	}

}

__DATA__
id    name    team
1     Amy     Blues
2     Bob     Reds
3     Chuck   Blues
4     Dick    Blues
5     Ethel   Reds
6     Fred    Blues
7     Gilly   Blues
8     Hank    Reds


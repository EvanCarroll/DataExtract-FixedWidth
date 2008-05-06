#!/usr/bin/env perl
## All code shameless ripped, with slight modifications
## from BrowserUK's pm post http://perlmonks.org/?node_id=628059
use strict;
use warnings;
use feature ':5.10';

use Test::More tests => 5;

use DataExtract::FixedWidth;

my @lines = <DATA>;
my $de = DataExtract::FixedWidth->new({
	heuristic => \@lines
});

foreach my $lineidx ( 1 .. @lines ) {
	my $line = $lines[$lineidx];
	my $arr = $de->parse( $line );

	given ( $lineidx ) {
		when ( 1 ) {
			ok( $arr->[0] cmp 'The First One Here Is Longer.', "Testing response (parse)" );
			ok( $arr->[5] cmp 'MVP', "Testing response (parse)" );
			ok( $arr->[4] cmp '93871', "Testing response (parse)" );
		}
		when ( 5 ) {
			ok( $arr->[1] cmp 'Twin 200 SH', "Testing response (parse)" );
			ok( $arr->[5] cmp 'VRE', "Testing response (parse)" );
		}
	}

}


__DATA__
The First One Here Is Longer. Collie SN      262287630  77312    93871  MVP
A  Second (PART) here         First In 20 MT 169287655  506666   61066  RTD
3rd Person "Something"        X&Y No SH      564287705  45423    52443  RTE
The Fourth Person 20          MLP 4000       360505504  3530     72201  VRE
The Fifth Name OR Something   Twin 200 SH    469505179  3530     72201  VRE
The Sixth Person OR Item      MLP            260505174  3,530   72,201  VRE
70 The Seventh Record         MLP            764205122  3530     72201  VRE
The Eighth Person MLP         MLP            160545154  3530      7220  VRE


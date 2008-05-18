package DataExtract::FixedWidth;
use Moose;
use Carp;

our $VERSION = '0.05';

sub BUILD {
	my $self = shift;

	confess 'You must either send either a "header_row" or data for "heuristic"'
		unless $self->has_header_row || $self->has_heuristic
	;
	confess 'You must send a "header_row" if you send "cols"'
		if $self->has_cols && !$self->has_header_row
	;

}

has 'unpack_string' => (
	isa          => 'Str'
	, is         => 'rw'
	, lazy_build => 1
);

has 'cols' => (
	isa            => 'ArrayRef'
	, is           => 'rw'
	, auto_deref   => 1
	, lazy_build   => 1
);

has 'colchar_map' => (
	isa          => 'HashRef'
	, is         => 'rw'
	, lazy_build => 1
);

has 'header_row' => (
	isa          => 'Maybe[Str]'
	, is         => 'rw'
	, lazy_build => 1
);

has 'first_col_zero' => (
	isa       => 'Bool'
	, is      => 'ro'
	, default => 1
);

has 'fix_overlay' => (
	isa       => 'Bool'
	, is      => 'ro'
	, default => 0
);

has 'trim_whitespace' => (
	isa       => 'Bool'
	, is      => 'ro'
	, default => 1
);

has 'sorted_colstart' => (
	isa          => 'ArrayRef'
	, is         => 'ro'
	, lazy_build => 1
	, auto_deref => 1
);

has 'null_as_undef' => (
	isa       => 'Bool'
	, is      => 'ro'
	, default => 0
);

has 'heuristic' => (
	isa          => 'ArrayRef'
	, is         => 'rw'
	, predicate  => 'has_heuristic'
	, auto_deref => 1
	, trigger    => sub { chomp @{$_[1]} }
);

has 'skip_header_data' => (
	isa       => 'Bool'
	, is      => 'rw'
	, default => 1
);

sub _build_header_row {
	my $self = shift;

	$self->has_heuristic
		? return ${$self->heuristic}[0]
		: undef
	;

}

sub _build_cols {
	my $self = shift;

	my @cols;

	## If we have the unpack string and the header_row parse it all out on our own
	if (
		( $self->header_row && $self->has_unpack_string )
		|| ( $self->header_row && $self->has_heuristic )
	) {
		my $skd = $self->skip_header_data;
		$self->skip_header_data( 0 );
		
		@cols = @{ $self->parse( $self->header_row ) };
		
		$self->skip_header_data( $skd );
	}

	## We only the header_row
	elsif ( $self->header_row ) {
		@cols = split ' ', $self->header_row;
	}

	else {
		croak 'Need some method to calculate cols';
	}

	\@cols;

}

sub _build_colchar_map {
	my $self = shift;

	croak 'Can not render the map of columns to start-chars without the header_row'
		unless defined $self->header_row
	;

	my $ccm = {};
	foreach my $col ( $self->cols ) {

		my $pos = 0;
		$pos = index( $self->header_row, $col, $pos );

		croak "Failed to find a column '$col' in the header row"
			unless defined $pos
		;

		unless ( exists $ccm->{ $pos } ) {
			$ccm->{ $pos } = $col;
		}

		## We have two like-named columns
		else {

			until ( not exists $ccm->{$pos} ) {
				$pos = index( $self->header_row, $col, $pos+1 );

				croak "Failed to find another column '$col' in the header row"
					unless defined $pos
				;

			}

			$ccm->{ $pos } = $col;

		}

	}

	$ccm;

}

sub _build_unpack_string {
	my $self = shift;

	my @unpack;
	if ( $self->has_heuristic ) {
		my @lines = $self->heuristic;

		my $mask = ' ' x length $lines[ 0 ];

		$mask |= $_ for @lines;

		push @unpack, length($1)
			while $mask =~ m/(\S+\s+|$)/g
		;

		## Remove last row, (to be replaced with A*)
		pop @unpack;

	}
	else {
		my @startcols = $self->sorted_colstart;
		$startcols[0] = 0 if $self->first_col_zero;
		foreach my $idx ( 0 .. $#startcols ) {

			if ( exists $startcols[$idx+1] ) {
				push @unpack, ( $startcols[$idx+1] - $startcols[$idx] );
			}

		}
	}

	my $unpack;
	if ( @unpack ) {
		$unpack = 'a' . join 'a', @unpack;
	}
	$unpack .= 'A*';

	$unpack;

}

sub parse {
	my ( $self, $data ) = @_;

	return undef if !defined $data;
	
	chomp $data;

	## skip_header_data
	return undef
		if $self->skip_header_data 
		&& ( defined $self->header_row && $data eq $self->header_row )
	;

	#printf "\nData:|%s|\tHeader:|%s|", $data, $self->header_row;

	my @cols = unpack ( $self->unpack_string, $data );

	## If we bleed over a bit we can fix that.
	if ( $self->fix_overlay ) {
		foreach my $idx ( 0 .. $#cols ) {
			if (
				$cols[$idx] =~ m/\S+$/
				&& exists $cols[$idx+1]
				&& $cols[$idx+1] =~ s/^(\S+)//
			) {
					$cols[$idx] .= $1;
			}
		}
	}

	## Get rid of whitespaces
	if ( $self->trim_whitespace ) {
		for ( @cols ) { s/^\s+//; s/\s+$//; }
	}

	## Swithc nulls to undef
	if ( $self->null_as_undef ) {
		croak 'This ->null_as_undef option mandates ->trim_whitespace be true'
			unless $self->trim_whitespace
		;
		for ( @cols ) { undef $_ unless length($_) }
	}

	\@cols;

}

sub parse_hash {
	my ( $self, $data ) = @_;
	
	my $row = $self->parse( $data );

	my $colstarts = $self->sorted_colstart;

	my $results;
	foreach my $idx ( 0 .. $#$row ) {
		my $col = $self->colchar_map->{ $colstarts->[$idx] };
		$results->{ $col } = $row->[$idx];
	}

	$results;

}

sub _build_sorted_colstart {
	my $self = shift;

	my @startcols = map { $_->[0] }
		sort { $a->[1] <=> $b->[1] }
		map { [$_, sprintf( "%10d", $_ ) ] }
		keys %{ $self->colchar_map }
	;

	\@startcols;

}

1;

__END__

=head1 NAME

DataExtract::FixedWidth - The one stop shop for parsing static column width text tables!

=head1 SYNOPSIS

	## We assume the columns have no spaces in the header.	
	my $de = DataExtract::FixedWidth->new({ header_row => $header_row });

	## We explicitly tell what column names to pick out of the header.
	my $de = DataExtract::FixedWidth->new({
		header_row => $header_row
		cols       => [qw/COL1NAME COL2NAME COL3NAME/, 'COL WITH SPACE IN NAME']
	});

	## We supply data to heuristically determine header. Here we assume the first
	## row is the header (if we need the first row to avoid this possible assumption set
	## the header_row to undef. And the result of the heurisitic applied to the first row
	## is the columns
	my $de = DataExtract::FixedWidth->new({ heuristic => \@datarows });

	$de->parse( $data_row );

	$de->parse_hash( $data_row );

=head1 DESCRIPTION

This module parses any type of fixed width table -- these types of tables are often outputed by ghostscript, printf() displays with string padding (i.e. %-20s %20s etc), and most screen capture mechanisms. This module is using Moose all methods can be specified in the constructor.


In the below example, this module can discern the column names from the header. Or, you can supply them explicitly in the constructor; or, you can supply the rows in an ArrayRef to heuristic and pray for the best luck.

	SAMPLE FILE
	HEADER:  'COL1NAME       COL2NAME       COL3NAMEEEEE'
	DATA1:   'FOOBARBAZ      THIS IS TEXT   ANHER COL   '
	DATA2:   'FOOBAR FOOBAR  IS TEXT        ANOTHER COL '

After you have constructed, you can C<-E<gt>parse> which will return an ArrayRef
	$de->parse('FOOBARBAZ THIS IS TEXT    ANOTHER COL');

Or, you can use C<-E<gt>parse_hash()> which returns a HashRef of the data indexed by the column header

=head2 Constructor

The class constructor -- C<-E<gt>new> -- provides numerious features. Some options it has are:

=over 12

=item heuristics => \@lines

This will deduce the unpack format string from data. If you opt to use this method, and need parse_hash, the first row of the heurisitic is assumed to be the header_row. The unpack_string that results for the heuristic is applied to the header_row to determine the columns.

=item cols => \@cols

This will permit you to explicitly list the columns in the header row. This is especially handy if you have spaces in the column header. This option will make the C<header_row> mandatory.

=item header_row => $string

If a C<cols> option is not provided the assumption is that there are no spaces in the column header. The module can take care of the rest. The only way this column can be avoided is if we deduce the header from heuristics, or if you explicitly supply the unpack string and only use C<-E<gt>parse($line)>. If you are not going to supply a header, and you do not want to waste the first line on a header assumption, set the C<header_row =E<gt> undef> in the constructor.

=back

=head2 Methods

B<An astrisk, (*) in the option means that is the default.>

=over 12

=item ->parse( $data_line )

Parses the data and returns an ArrayRef

=item ->parse_hash( $data_line )

Parses the data and returns a HashRef, indexed by the I<cols> (headers)

=item ->first_col_zero(1*|0)

This option forces the unpack string to make the first column assume the characters to the left of the header column. So, in the below example the first column also includes the first char of the row, even though the word stock begins at the second character.

	CHAR NUMBERS: |1|2|3|4|5|6|7|8|9|10
	HEADER ROW  : | |S|T|O|C|K| |V|I|N

=item ->trim_whitespace(*1|0)

Trim the whitespace for the elements that ->parse() outputs

=item ->fix_overlay(1|0*)

Fixes columns that bleed into other columns, move over all non-whitespace characters preceding the first whitespace of the next column.

So if ColumnA as is 'foob' and ColumnB is 'ar Hello world'

* ColumnA becomes 'foobar', and ColumnB becomes 'Hello world'

=item ->null_as_undef(1|0*)

Simply undef all elements that return C<length(element) = 0>, requires C<-E<gt>trim_whitespace>

=item ->skip_header_data(1*|0)

Skips duplicate copies of the header_row if found in the data

=item ->colchar_map

Returns a hash ref that sisplays the results of each column header and the character position the column starts at.

=item ->unpack_string

Returns the CORE::unpack() template string that will be used internally by ->parse()

=back

=head1 AVAILABILITY

CPAN.org

=head1 COPYRIGHT & LICENSE

Copyright 2008 Evan, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=head1 AUTHOR

	Evan Carroll <me at evancarroll.com>
	System Lord of the Internets

=head1 BUGS

Please report any bugs or feature requests to C<bug-dataexract-fixedwidth at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DataExtract-FixedWidth>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=cut

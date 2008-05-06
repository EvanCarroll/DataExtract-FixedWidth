package DataExtract::FixedWidth;
use Moose;
##
## Fix is to use BrowserUK's code for the heuristic from data
## 
## 
use Carp;

our $VERSION = '0.03';

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
	isa         => 'Str'
	, is        => 'rw'
	, predicate => 'has_header_row'
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
);

sub _build_cols {
	my $self = shift;
	return [ split ' ', $self->header_row ]
}

sub _build_colchar_map {
	my $self = shift;
	
	croak 'Can not render the map of columns to start-chars without the header_row'
		unless $self->has_header_row
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
		
		push @unpack, 'a' . length($1)
			while $mask =~ m/(\S+\s*+|$)/g
		;

	}
	else {
		my @startcols = $self->sorted_colstart;
		$startcols[0] = 0 if $self->first_col_zero;
		foreach my $idx ( 0 .. $#startcols ) {
			
			if ( exists $startcols[$idx+1] ) {
				push @unpack, 'a' . ( $startcols[$idx+1] - $startcols[$idx] );
			}
			else {
				push @unpack, 'A*'
			}
		
		}
	}
	

	join '', @unpack;

}

sub parse {
	my ( $self, $data ) = @_;
	
	return undef
		unless defined $data
	;

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

	my @data = @{ $self->parse( $data ) };
	my $colstarts = $self->sorted_colstart;
	
	my $results;
	foreach my $idx ( 0 .. $#data ) {
		my $col = $self->colchar_map->{ $colstarts->[$idx] };
		$results->{ $col } = $data[$idx];
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

	SAMPLE FILE
	HEADER:  'COL1NAME  COL2NAME       COL3NAMEEEEE'
	DATA1:   'FOOBARBAZ THIS IS TEXT      ANHER COL'
	DATA2:   'FOOBAR FOOBAR IS TEXT    ANOTHER COL'

In the above example, this module can discern the column names from the header. It will then parse out DATA1 and DATA2 appropriatly. If the column bleeds into another column you can use the option C<-E<gt>fix_overlay(1)>


	my $de = DataExtract::FixedWidth->new({
		header_row => 'COL1NAME  COL2NAME       COL3NAMEEEEE'
		## You can optionally be explicit about the column names
		## This is required if your column names have spaces
		cols       => [qw/COL1NAME COL2NAME COL3NAMEEEEE/]
	});

After you have constructed, you can C<-E<gt>parse> which will return an ArrayRef
	C<$de-E<gt>parse('FOOBARBAZ THIS IS TEXT    ANOTHER COL');>

Or, you can use C<-E<gt>parse_hash()> which returns a HashRef of the data indexed by the column header


=head1 DESCRIPTION

This module parses any type of fixed width table -- these types of tables are often outputed by ghostscript, printf() displays with string padding (i.e. %-20s %20s etc), and most screen capture mechanisms.

=head2 Constructor

The class constructor -- C<-E<gt>new> -- provides numerious features. Some options it has are:

=over 12

=item heuristics => \@lines

This will deduce the unpack format string from data. If you opt to use this method parse_hash will be unavailble to you.

=item cols => \@cols

This will permit you to explicitly list the columns in the header row. This is especially handy if you have spaces in the column header. This option will make the C<header_string> mandatory.

=item header_string => $string

If a C<cols> option is not provided the assumption is that there are no spaces in the column header. The module can take care of the rest. The only way this column can be avoided is if we deduce the header from heuristics, or if you explicitly supply the unpack string and only use C<-E<gt>parse($line)>

=back

=head2 Methods

=over 12

=item ->parse( $data_line )

Parses the data and returns an ArrayRef

=item ->parse_hash( $data_line )

Parses the data and returns a HashRef

=item ->first_col_zero(1/0)

On by default, this option forces the unpack string to make the first column assume the characters to the left of the header column. So, in the below example the first column also includes the first char of the row, even though the word stock begins at the second character.

	CHAR NUMBERS: |1|2|3|4|5|6|7|8|9|10
	HEADER ROW  : | |S|T|O|C|K| |V|I|N

=item ->trim_whitespace(1/0)

On by default, simply trims the whitespace for the elements that ->parse() outputs

=item ->fix_overlay(1/0)

Off by default, fixes columns that bleed into other columns, move over all non-whitespace characters preceding the first whitespace of the next column.

So if ColumnA as is 'foob' and ColumnB is 'ar Hello world'

* ColumnA becomes 'foobar', and ColumnB becomes 'Hello world'

=item ->null_as_undef(1/0)

Simply undef all elements that return C<length(element) = 0>

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

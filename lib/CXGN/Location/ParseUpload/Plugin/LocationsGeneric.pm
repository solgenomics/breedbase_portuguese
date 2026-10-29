package CXGN::Location::ParseUpload::Plugin::LocationsGeneric;

use utf8;
use Moose;
use CXGN::Location;
use CXGN::File::Parse;
use JSON;
use Data::Dumper;

sub name {
    return "location generic";
}

sub parse {
    my $self = shift;
    my $filename = shift;
    my $schema = shift;

    my $check = CXGN::Location->new({ bcs_schema => $schema });
    my (@errors, @rows, %parse_result);

    my $parser = CXGN::File::Parse->new(
      file => $filename,
      required_columns => [ 'Name', 'Abbreviation', 'Country Code', 'Country Name', 'Program', 'Type', 'Latitude', 'Longitude', 'Elevation' ],
      optional_columns => [ 'NOAA Station ID' ],
      column_aliases => {
        'Elevation' => [ 'Altitude' ],
        'Latitude' => [ 'Lat' ],
        'Longitude' => [ 'Lon', 'Long' ]
      },
      column_arrays => {
        'Program' => '&'
      },
      unique_only_columns => [ 'Name', 'Abbreviation' ]
    );
    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{errors};
    my $parsed_columns = $parsed->{columns};
    my $parsed_data = $parsed->{data};
    my $parsed_values = $parsed->{values};

    if ( $parsed_errors && scalar(@$parsed_errors) > 0 ) {
      $parse_result{'error'} = [ map { _translate_parser_error($_) } @$parsed_errors ];
      return \%parse_result;
    }


    for my $row (@$parsed_data) {
        my $row_num = $row->{_row};
        our($name,$abbreviation,$country_code,$country_name,$programs,$type,$latitude,$longitude,$altitude,$noaa_station_id) = undef;

        # check that name is defined and isn't already in database
        $name = $row->{'Name'};
        if (!$check->_is_valid_name($name)) {
            push @errors, "Linha $row_num: o nome $name já existe no banco de dados.\n";
        }

        # check that abbreviation is defined and isn't already in database
        $abbreviation = $row->{'Abbreviation'};
        if (!$check->_is_valid_abbreviation($abbreviation)) {
            push @errors, "Linha $row_num: a abreviação $abbreviation já existe no banco de dados.\n";
        }

        # check that country code is defined, is all uppercase letters, and is 3 chars long
        $country_code = $row->{'Country Code'};
        if (($country_code !~ m/^[^a-z]*$/) || (length($country_code) != 3 )) {
            push @errors, "Linha $row_num: o código de país $country_code não é um código ISO Alfa-3 válido.\n";
        }

        # check that country name is defined and is not numeric
        $country_name = $row->{'Country Name'};
        if ($country_name =~ m/[0-9]/) {
            push @errors, "Linha $row_num: o nome de país $country_name não é válido conforme o padrão ISO.\n";
        }

        # check that program is defined, is in database
        $programs = $row->{'Program'};
        foreach my $bp (@$programs) {
            if (!$check->_is_valid_program($bp)) {
                push @errors, "Linha $row_num: o programa $bp não existe no banco de dados.\n";
            }
        }
        my $program_string = join("&", @$programs);

        # check that type is defined, is one of approved types
        $type = $row->{'Type'};
        if(!$check->_is_valid_type($type)) {
            push @errors, "Linha $row_num: $type não é um tipo de local válido.\n";
        }

        # check lat has length, is number between 90 and -90
        $latitude = $row->{'Latitude'};
        if( ($latitude !~ /^-?[0-9.]+$/) || ($latitude < -90) || ($latitude > 90) ) {
            push @errors, "Linha $row_num: a latitude $latitude não é um número entre -90 e 90.\n";
        }

        # check lon has length, is number between 180 and -180
        $longitude = $row->{'Longitude'};
        if( ($longitude !~ /^-?[0-9.]+$/) || ($longitude < -180) || ($longitude > 180) ) {
            push @errors, "Linha $row_num: a longitude $longitude não é um número entre -180 e 180.\n";
        }

        # check has length, is number between -418 and 8,848
        $altitude = $row->{'Elevation'};
        if( ($altitude !~ /^-?[0-9.]+$/) || ($altitude < -418) || ($altitude > 8848) ) {
            push @errors, "Linha $row_num: a elevação $altitude não é um número entre -418 (Mar Morto) e 8.848 (Monte Everest).\n";
        }

        $noaa_station_id = $row->{'NOAA Station ID'};

        print STDERR "Row is $name, $abbreviation, $country_code, $country_name, $program_string, $type, $latitude, $longitude, $altitude, $noaa_station_id\n";
        push @rows, [$name,$abbreviation,$country_code,$country_name,$program_string,$type,$latitude,$longitude,$altitude,$noaa_station_id];
    }

    if (scalar @errors > 0) {
        $parse_result{'error'} = \@errors;
    }
    else {
        print STDERR "Parsed file with no errors, returning with valid new location data.\n";
        $parse_result{'success'} = \@rows;
    }
    return \%parse_result;
}

sub _translate_parser_error {
    # CXGN::File::Parse messages are already in Portuguese; just tidy them up.
    my $message = shift // '';
    $message =~ s/\s+$//;
    return $message;
}

1;

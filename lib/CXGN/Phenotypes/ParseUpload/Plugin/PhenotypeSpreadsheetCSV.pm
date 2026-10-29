package CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheetCSV;

use utf8;
# Validate Returns %validate_result = (
#   error => 'error message'
#)

# Parse Returns %parsed_result = (
#   data => {
#       plotname1 => {
#           varname1 => [12, '2015-06-16T00:53:26Z']
#           varname2 => [120, '']
#       }
#   },
#   units => [plotname1],
#   variables => [varname1, varname2]
#)

use Moose;
use JSON;
use Data::Dumper;
use Text::CSV;

sub name {
    return "phenotype spreadsheet csv";
}

sub validate {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $zipfile = shift; #not relevant for this plugin
    my $nd_protocol_id = shift; #not relevant for this plugin
    my $nd_protocol_filename = shift; #not relevant for this plugin
    my $delimiter = ',';
    my %parse_result;

    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '< :encoding(UTF-8)', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        $parse_result{'error'} = "Não foi possível ler o arquivo.";
        print STDERR "Could not read file.\n";
        return \%parse_result;
    }

    my $header_row = <$fh>;
    my @columns;
    if ($csv->parse($header_row)) {
        @columns = $csv->fields();
    } else {
        $parse_result{'error'} = "Não foi possível analisar a linha de cabeçalho.";
        print STDERR "Could not parse header.\n";
        return \%parse_result;
    }

    my $num_cols = scalar(@columns);
    if ($num_cols < 16){
        $parse_result{'error'} = 'A linha de cabeçalho deve conter:  "studyYear","studyDbId","studyName","studyDesign","locationDbId","locationName","germplasmDbId","germplasmName","germplasmSynonyms","observationLevel","observationUnitDbId","observationUnitName","replicate","blockNumber","plotNumber" seguido de pelo menos uma característica.';
        print STDERR "Incorrect header.\n";
        return \%parse_result;
    }

    if ( $columns[0] ne "studyYear" &&
        $columns[1] ne "studyDbId" &&
        $columns[2] ne "studyName" &&
        $columns[3] ne "studyDesign" &&
        $columns[4] ne "locationDbId" &&
        $columns[5] ne "locationName" &&
        $columns[6] ne "germplasmDbId" &&
        $columns[7] ne "germplasmName" &&
        $columns[8] ne "germplasmSynonyms" &&
        $columns[9] ne "observationLevel" &&
        $columns[10] ne "observationUnitDbId" &&
        $columns[11] ne "observationUnitName" &&
        $columns[12] ne "replicate" &&
        $columns[13] ne "blockNumber" &&
        $columns[14] ne "plotNumber" ) {
            $parse_result{'error'} = 'Conteúdo do arquivo incorreto. A linha de cabeçalho deve conter:  "studyYear","studyDbId","studyName","studyDesign","locationDbId","locationName","germplasmDbId","germplasmName","germplasmSynonyms","observationLevel","observationUnitDbId","observationUnitName","replicate","blockNumber","plotNumber" seguido de todas as características medidas.';
            print STDERR "File contents incorrect.\n";
            return \%parse_result;
    }

    my $num_col_before_traits = 15;
    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            $parse_result{'error'} = "Não foi possível analisar a linha $row.";
            print STDERR "Could not parse row $row.\n";
            return \%parse_result;
        }

        if (scalar(@columns) != $num_cols){
            $parse_result{'error'} = 'Todas as linhas devem ter o mesmo número de colunas que o cabeçalho! Erro na linha: '.$row;
            print STDERR "Line $row does not have complete columns.\n";
            return \%parse_result;
        }

        for my $col_num ($num_col_before_traits .. $num_cols-1) {
            my $value_string = $columns[$col_num];
            #print STDERR $value_string."\n";
            if ($timestamp_included) {
                my ($value, $timestamp) = split /,/, $value_string;
                if (!$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
                    $parse_result{'error'} = "A data e hora deve estar no formato YYYY-MM-DD HH:MM:SS-0000 ou YYYY-MM-DD HH:MM:SS+0000";
                    print STDERR "value: $timestamp\n";
                    return \%parse_result;
                }
            }
        }
    }

    return 1;
}

sub parse {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $zipfile = shift; #not relevant for this plugin
    my $user_id = shift; #not relevant for this plugin
    my $c = shift; #not relevant for this plugin
    my $nd_protocol_id = shift; #not relevant for this plugin
    my $nd_protocol_filename = shift; #not relevant for this plugin
    my $delimiter = ',';
    my %parse_result;

    my $csv = Text::CSV->new({ sep_char => ',' });
    my $header;
    my @header_row;
    my $header_column_number = 0;
    my %header_column_info; #column numbers of key info indexed from 0;
    my %observation_units_seen;
    my %traits_seen;
    my @observation_units;
    my @traits;
    my %data;

    open(my $fh, '< :encoding(UTF-8)', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        $parse_result{'error'} = "Não foi possível ler o arquivo.";
        print STDERR "Could not read file.\n";
        return \%parse_result;
    }

    my $header_row = <$fh>;
    my @header_columns;
    if ($csv->parse($header_row)) {
        @header_columns = $csv->fields();
    } else {
        $parse_result{'error'} = "Não foi possível analisar a linha de cabeçalho.";
        print STDERR "Could not parse header row.\n";
        return \%parse_result;
    }
    my $num_cols = scalar(@header_columns);

    my $num_col_before_traits = 15;
    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            $parse_result{'error'} = "Não foi possível analisar a linha $row.";
            print STDERR "Could not parse row $row.\n";
            return \%parse_result;
        }

        my $observation_unit_name = $columns[11];
        $observation_units_seen{$observation_unit_name} = 1;

        for my $col_num ($num_col_before_traits .. $num_cols-1) {

            my $trait_name = $header_columns[$col_num];
            if ($trait_name) {
                $traits_seen{$trait_name} = 1;
                my $value_string = '';
                if ($columns[$col_num] || $columns[$col_num] == 0){
                    $value_string = $columns[$col_num];
                }
                #print STDERR $value_string."\n";
                my $timestamp = '';
                my $value = '';
                if ($timestamp_included){
                    ($value, $timestamp) = split /,/, $value_string;
                } else {
                    $value = $value_string;
                }
                if (!defined($timestamp)){
                    $timestamp = '';
                }
                #print STDERR $trait_value." : ".$timestamp."\n";

                if ( defined($value) && defined($timestamp) ) {
                    if ($value ne '.'){
                        $data{$observation_unit_name}->{$trait_name} = [$value, $timestamp];
                    }
                } else {
                    $parse_result{'error'} = "Valor ou data e hora ausente.";
                    return \%parse_result;
                }
            }
        }

    }

    foreach my $p (sort keys %observation_units_seen) {
        push @observation_units, $p;
    }
    foreach my $trait (sort keys %traits_seen) {
        push @traits, $trait;
    }

    $parse_result{'data'} = \%data;
    $parse_result{'units'} = \@observation_units;
    $parse_result{'variables'} = \@traits;
    #print STDERR Dumper \%parse_result;

    return \%parse_result;
}

1;

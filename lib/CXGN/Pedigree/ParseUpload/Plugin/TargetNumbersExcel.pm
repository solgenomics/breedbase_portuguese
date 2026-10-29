package CXGN::Pedigree::ParseUpload::Plugin::TargetNumbersExcel;

use utf8;
use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use Data::Dumper;
use CXGN::List::Validate;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my @error_messages;
    my %errors;

    # Match a dot, extension .xls / .xlsx
    my ($extension) = $filename =~ /(\.[^.]+)$/;
    my $parser;

    if ($extension eq '.xlsx') {
        $parser = Spreadsheet::ParseXLSX->new();
    }
    else {
        $parser = Spreadsheet::ParseExcel->new();
    }

    my $excel_obj;
    my $worksheet;

    #try to open the excel file and report any errors
    $excel_obj = $parser->parse($filename);
    if (!$excel_obj){
        push @error_messages, $parser->error();
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $worksheet = ($excel_obj->worksheets())[0]; #support only one worksheet
    if (!$worksheet){
        push @error_messages, "A planilha deve estar na 1ª aba do arquivo Excel (.xls)";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my ($row_min, $row_max) = $worksheet->row_range();
    my ($col_min, $col_max) = $worksheet->col_range();
    if (($col_max - $col_min)  < 3 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of target number info
        push @error_messages, "A planilha não tem cabeçalho ou não contém dados de números-alvo";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $female_accession_head;
    my $male_accession_head;
    my $seed_target_number_head;
    my $progeny_target_number_head;

    if ($worksheet->get_cell(0,0)) {
        $female_accession_head  = $worksheet->get_cell(0,0)->value();
        $female_accession_head =~ s/^\s+|\s+$//g;
    }

    if ($worksheet->get_cell(0,1)) {
        $male_accession_head  = $worksheet->get_cell(0,1)->value();
        $male_accession_head =~ s/^\s+|\s+$//g;
    }

    if ($worksheet->get_cell(0,2)) {
        $seed_target_number_head  = $worksheet->get_cell(0,2)->value();
        $seed_target_number_head =~ s/^\s+|\s+$//g;
    }

    if ($worksheet->get_cell(0,3)) {
        $progeny_target_number_head  = $worksheet->get_cell(0,3)->value();
        $progeny_target_number_head =~ s/^\s+|\s+$//g;
    }

    if (!$female_accession_head || $female_accession_head ne 'female_accession' ) {
        push @error_messages, "Célula A1: female_accession está ausente do cabeçalho";
    }

    if (!$male_accession_head || $male_accession_head ne 'male_accession' ) {
        push @error_messages, "Célula A2: male_accession está ausente do cabeçalho";
    }

    if (!$seed_target_number_head || $seed_target_number_head ne 'seed_target_number' ) {
        push @error_messages, "Célula A3: seed_target_number está ausente do cabeçalho";
    }

    if (!$progeny_target_number_head || $progeny_target_number_head ne 'progeny_target_number' ) {
        push @error_messages, "Célula A4: progeny_target_number está ausente do cabeçalho";
    }


    my %seen_female_accessions;
    my %seen_male_accessions;

    for my $row (1 .. $row_max){
        my $row_name = $row+1;
        my $female_accession;
        my $male_accession;
        my $seed_target_number;
        my $progeny_target_number;

        if ($worksheet->get_cell($row,0)) {
            $female_accession = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $male_accession = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $seed_target_number = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $progeny_target_number = $worksheet->get_cell($row,3)->value();
        }

        if (!$female_accession || $female_accession eq '') {
            push @error_messages, "Célula A$row_name: acesso feminino ausente";
        } else {
            $female_accession =~ s/^\s+|\s+$//g;
            $seen_female_accessions{$female_accession}++;
        }

        if (!$male_accession || $male_accession eq '') {
            push @error_messages, "Célula B$row_name: acesso masculino ausente";
        } else {
            $male_accession =~ s/^\s+|\s+$//g;
            $seen_male_accessions{$male_accession}++;
        }

        if ((!$seed_target_number || $seed_target_number eq '') && (!$progeny_target_number || $progeny_target_number eq '')) {
            push @error_messages, "Célula C/D$row_name: deve ter número-alvo de sementes e/ou número-alvo de progênies";
        }
    }

    my @female_accessions = keys %seen_female_accessions;
    my $female_accession_validator = CXGN::List::Validate->new();
    my @female_accession_missing = @{$female_accession_validator->validate($schema,'uniquenames',\@female_accessions)->{'missing'}};

    if (scalar(@female_accession_missing) > 0){
        push @error_messages, "Os seguintes acessos femininos não estão no banco de dados como nomes únicos : ".join(',',@female_accession_missing);
    }

    my @male_accessions = keys %seen_male_accessions;
    my $male_accession_validator = CXGN::List::Validate->new();
    my @male_accession_missing = @{$male_accession_validator->validate($schema,'uniquenames',\@male_accessions)->{'missing'}};

    if (scalar(@male_accession_missing) > 0){
        push @error_messages, "Os seguintes acessos masculinos não estão no banco de dados como nomes únicos : ".join(',',@male_accession_missing);
    }

    #store any errors found in the parsed file to parse_errors accessor
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    return 1; #returns true if validation is passed

}


sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();

    # Match a dot, extension .xls / .xlsx
    my ($extension) = $filename =~ /(\.[^.]+)$/;
    my $parser;

    if ($extension eq '.xlsx') {
        $parser = Spreadsheet::ParseXLSX->new();
    }
    else {
        $parser = Spreadsheet::ParseExcel->new();
    }

    my $excel_obj;
    my $worksheet;

    $excel_obj = $parser->parse($filename);
    if (!$excel_obj){
        return;
    }

    $worksheet = ($excel_obj->worksheets())[0];
    my ($row_min, $row_max) = $worksheet->row_range();
    my ($col_min, $col_max) = $worksheet->col_range();

    my %target_number_info;

    for my $row (1 .. $row_max){
        my $female_accession;
        my $male_accession;
        my $seed_target_number;
        my $progeny_target_number;

        if ($worksheet->get_cell($row,0)){
            $female_accession = $worksheet->get_cell($row,0)->value();
            $female_accession =~ s/^\s+|\s+$//g;
        }

        if ($worksheet->get_cell($row,1)){
            $male_accession = $worksheet->get_cell($row,1)->value();
            $male_accession =~ s/^\s+|\s+$//g;
        }

        if ($worksheet->get_cell($row,2)){
            $seed_target_number = $worksheet->get_cell($row,2)->value();
            $seed_target_number =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,3)){
            $progeny_target_number = $worksheet->get_cell($row,3)->value();
            $progeny_target_number =~ s/^\s+|\s+$//g;
        }

        if ($seed_target_number) {
            $target_number_info{$female_accession}{$male_accession}{'target_number_of_seeds'} = $seed_target_number;
        }
        if ($progeny_target_number) {
            $target_number_info{$female_accession}{$male_accession}{'target_number_of_progenies'} = $progeny_target_number;
        }

    }

    $self->_set_parsed_data(\%target_number_info);

    return 1;
}

1;

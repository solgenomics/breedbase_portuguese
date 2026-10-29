package CXGN::Pedigree::ParseUpload::Plugin::ProgeniesExcel;

use utf8;
use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
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
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of progeny
        push @error_messages, "A planilha não tem cabeçalho ou não contém dados de progênies";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $cross_name_head;
    my $progeny_name_head;

    if ($worksheet->get_cell(0,0)) {
        $cross_name_head  = $worksheet->get_cell(0,0)->value();
        $cross_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $progeny_name_head  = $worksheet->get_cell(0,1)->value();
        $progeny_name_head =~ s/^\s+|\s+$//g;
    }

    if (!$cross_name_head || $cross_name_head ne 'cross_unique_id' ) {
        push @error_messages, "Célula A1: cross_unique_id está ausente do cabeçalho";
    }
    if (!$progeny_name_head || $progeny_name_head ne 'progeny_name') {
        push @error_messages, "Célula B1: progeny_name está ausente do cabeçalho";
    }

    my %seen_cross_names;
    my %seen_progeny_names;

    for my $row (1 .. $row_max){
        my $row_name = $row+1;
        my $cross_name;
        my $progeny_name;

        if ($worksheet->get_cell($row,0)) {
            $cross_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $progeny_name = $worksheet->get_cell($row,1)->value();
        }

        if (!$cross_name || $cross_name eq '') {
            push @error_messages, "Célula A$row_name: ID único do cruzamento ausente";
        } else {
            $cross_name =~ s/^\s+|\s+$//g;
            $seen_cross_names{$cross_name}++;
        }

        if (!$progeny_name || $progeny_name eq '') {
            push @error_messages, "Célula B$row_name: nome da progênie ausente";
        } else {
            $progeny_name =~ s/^\s+|\s+$//g;
            $seen_progeny_names{$progeny_name}++;
        }
    }

    my @crosses = keys %seen_cross_names;
    my $cross_validator = CXGN::List::Validate->new();
    my @crosses_missing = @{$cross_validator->validate($schema,'crosses',\@crosses)->{'missing'}};

    if (scalar(@crosses_missing) > 0){
        push @error_messages, "Os seguintes IDs únicos de cruzamento não estão no banco de dados como nomes únicos ou sinônimos: ".join(',',@crosses_missing);
    }

    my @progenies = keys %seen_progeny_names;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@progenies }
    });
    while (my $r=$rs->next){
        push @error_messages, "O nome da progênie já existe no banco de dados: ".$r->uniquename;
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

    my %cross_progenies_hash;

    for my $row (1 .. $row_max){
        my $cross_name;
        my $progeny_name;

        if ($worksheet->get_cell($row,0)){
            $cross_name = $worksheet->get_cell($row,0)->value();
            $cross_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)){
            $progeny_name = $worksheet->get_cell($row,1)->value();
            $progeny_name =~ s/^\s+|\s+$//g;
        }
        #skip blank lines or lines with no name, type and parent
        if (!$cross_name && !$progeny_name) {
            next;
        }

        push @{$cross_progenies_hash{$cross_name}}, $progeny_name;
    }

    $self->_set_parsed_data(\%cross_progenies_hash);
    return 1;
}

1;

package CXGN::Stock::Seedlot::ParseUpload::Plugin::SeedlotsToPlots;

use utf8;
use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Stock::Seedlot;

sub _validate_with_plugin {
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

    my @error_messages;
    my %errors;
    my %missing_accessions;

    #try to open the excel file and report any errors
    my $excel_obj = $parser->parse($filename);
    if (!$excel_obj) {
        push @error_messages, $parser->error();
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    if (!$worksheet) {
        push @error_messages, "A planilha deve estar na 1ª aba do arquivo Excel (.xls)";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 2 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of transaction data
        push @error_messages, "A planilha não tem cabeçalho ou não contém linhas";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $from_seedlot_name_head;
    my $to_plot_name_head;
    my $amount_head;
    my $weight_head;
    my $operator_name_head;
    my $transaction_description_head;

    if ($worksheet->get_cell(0,0)) {
        $from_seedlot_name_head  = $worksheet->get_cell(0,0)->value();
        $from_seedlot_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $to_plot_name_head  = $worksheet->get_cell(0,1)->value();
        $to_plot_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,2)) {
        $amount_head  = $worksheet->get_cell(0,2)->value();
        $amount_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,3)) {
        $weight_head  = $worksheet->get_cell(0,3)->value();
        $weight_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,4)) {
        $operator_name_head  = $worksheet->get_cell(0,4)->value();
        $operator_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,5)) {
        $transaction_description_head  = $worksheet->get_cell(0,5)->value();
        $transaction_description_head =~ s/^\s+|\s+$//g;
    }

    if (!$from_seedlot_name_head || $from_seedlot_name_head ne 'from_seedlot_name' ) {
        push @error_messages, "Célula A1: from_seedlot_name está ausente do cabeçalho";
    }
    if (!$to_plot_name_head || $to_plot_name_head ne 'to_plot_name') {
        push @error_messages, "Célula B1: to_plot_name está ausente do cabeçalho";
    }
    if (!$amount_head || $amount_head ne 'amount') {
        push @error_messages, "Célula C1: amount está ausente do cabeçalho";
    }
    if (!$weight_head || $weight_head ne 'weight(g)') {
        push @error_messages, "Célula D1: weight(g) está ausente do cabeçalho";
    }
    if (!$operator_name_head || $operator_name_head ne 'operator_name') {
        push @error_messages, "Célula E1: operator_name está ausente do cabeçalho";
    }
    if (!$transaction_description_head || $transaction_description_head ne 'transaction_description') {
        push @error_messages, "Célula F1: transaction_description está ausente do cabeçalho";
    }

    my %seen_seedlot_names;
    my %seen_plot_names;
    my @seedlot_plot_pairs;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $from_seedlot_name;
        my $to_plot_name;
        my $amount = 'NA';
        my $weight = 'NA';
        my $operator_name;
        my $transaction_description;

        if ($worksheet->get_cell($row,0)) {
            $from_seedlot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $to_plot_name = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $amount =  $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $weight =  $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $operator_name = $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $transaction_description =  $worksheet->get_cell($row,5)->value();
        }

        if (!defined $from_seedlot_name && !defined $to_plot_name) {
            last;
        }

        if (!$from_seedlot_name || $from_seedlot_name eq '' ) {
            push @error_messages, "Célula A$row_name: from_seedlot_name ausente.";
        } else {
            $from_seedlot_name =~ s/^\s+|\s+$//g;
            $seen_seedlot_names{$from_seedlot_name}++;
        }

        if (!$to_plot_name || $to_plot_name eq '') {
            push @error_messages, "Célula B:$row_name: to_plot_name ausente.";
        } else {
            $to_plot_name =~ s/^\s+|\s+$//g;
            $seen_plot_names{$to_plot_name}++;
        }

        if (!defined($amount) || $amount eq '') {
            push @error_messages, "Célula C$row_name: amount ausente";
        }
        if (!defined($weight) || $weight eq '') {
            push @error_messages, "Célula D$row_name: weight(g) ausente";
        }
        if ($amount eq 'NA' && $weight eq 'NA') {
            push @error_messages, "Na linha $row_name, você deve informar um peso em gramas ou uma quantidade de sementes.";
        }

        if (!defined($operator_name) || $operator_name eq '') {
            push @error_messages, "Célula E$row_name: operator_name ausente";
        }

        push @seedlot_plot_pairs, [$from_seedlot_name, $to_plot_name];
    }

    my @seedlots = keys %seen_seedlot_names;
    my $seedlot_validator = CXGN::List::Validate->new();
    my $validation = $seedlot_validator->validate($schema,'seedlots',\@seedlots);
    my @all_seedlots_missing = @{$validation->{missing}};
    my @seedlots_discarded = @{$validation->{discarded}};
    my @seedlots_missing;
    foreach my $seedlot (@all_seedlots_missing) {
        if ($seedlot ~~ @seedlots_discarded) {
            next;
        } else {
            push @seedlots_missing, $seedlot;
        }
    }

    if (scalar(@seedlots_missing) > 0) {
        push @error_messages, "Os seguintes lotes de sementes não estão no banco de dados: ".join(',',@seedlots_missing);
    }

    if (scalar(@seedlots_discarded) > 0) {
        push @error_messages, "Os seguintes lotes de sementes estão marcados como DESCARTADOS: ".join(',',@seedlots_discarded);
    }

    my @plots = keys %seen_plot_names;
    my $plots_validator = CXGN::List::Validate->new();
    my @plots_missing = @{$plots_validator->validate($schema,'plots',\@plots)->{'missing'}};

    if (scalar(@plots_missing) > 0) {
        push @error_messages, "As seguintes parcelas não estão no banco de dados: ".join(',',@plots_missing);
    }

    my $pairs_error = CXGN::Stock::Seedlot->verify_seedlot_plot_compatibility($schema, \@seedlot_plot_pairs);
    if (exists($pairs_error->{error})){
        push @error_messages, $pairs_error->{error};
    }

    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    return 1;
}


sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my %parsed_data;

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
    my %parsed_seedlots;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();


    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();

    my @transactions;
    for my $row ( 1 .. $row_max ) {
        my $from_seedlot_name;
        my $to_plot_name;
        my $amount = 'NA';
        my $weight = 'NA';
        my $operator_name;
        my $transaction_description;

        if ($worksheet->get_cell($row,0)) {
            $from_seedlot_name = $worksheet->get_cell($row,0)->value();
            $from_seedlot_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $to_plot_name = $worksheet->get_cell($row,1)->value();
            $to_plot_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,2)) {
            $amount =  $worksheet->get_cell($row,2)->value();
            $amount =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,3)) {
            $weight =  $worksheet->get_cell($row,3)->value();
            $weight =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,4)) {
            $operator_name =  $worksheet->get_cell($row,4)->value();
            $operator_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,5)) {
            $transaction_description =  $worksheet->get_cell($row,5)->value();
        }

        if (!defined $from_seedlot_name && !defined $to_plot_name) {
            last;
        }

        my $from_seedlot_rs = $schema->resultset("Stock::Stock")->find({
            'uniquename' => $from_seedlot_name,
            'type_id' => $seedlot_cvterm_id,
        });
        my $from_seedlot_id = $from_seedlot_rs->stock_id();

        my $to_plot_rs = $schema->resultset("Stock::Stock")->find({
            'uniquename' => $to_plot_name,
            'type_id' => $plot_cvterm_id,
        });
        my $to_plot_id = $to_plot_rs->stock_id();

        push @transactions, {
            from_seedlot_name => $from_seedlot_name,
            from_seedlot_id => $from_seedlot_id,
            to_plot_name => $to_plot_name,
            to_plot_id => $to_plot_id,
            amount => $amount,
            weight => $weight,
            transaction_description => $transaction_description,
            operator => $operator_name
        }
    }

    $parsed_data{transactions} = \@transactions;

    $self->_set_parsed_data(\%parsed_data);
    return 1;
}


1;

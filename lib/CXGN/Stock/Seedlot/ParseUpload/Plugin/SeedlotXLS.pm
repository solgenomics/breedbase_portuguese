package CXGN::Stock::Seedlot::ParseUpload::Plugin::SeedlotXLS;

use utf8;
use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;

#
# DEPRECATED: This plugin has been replaced by the SeedlotFromAccessionGeneric plugin
#

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
    if (($col_max - $col_min)  < 2 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
        push @error_messages, "A planilha não tem cabeçalho ou não contém linhas";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $seedlot_name_head;
    my $accession_name_head;
    my $operator_name_head;
    my $amount_head;
    my $weight_head;
    my $description_head;
    my $box_name_head;
    my $seedlot_quality;
    my $seedlot_source;

    if ($worksheet->get_cell(0,0)) {
        $seedlot_name_head  = $worksheet->get_cell(0,0)->value();
        $seedlot_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $accession_name_head  = $worksheet->get_cell(0,1)->value();
        $accession_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,2)) {
        $operator_name_head  = $worksheet->get_cell(0,2)->value();
        $operator_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,3)) {
        $amount_head  = $worksheet->get_cell(0,3)->value();
        $amount_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,4)) {
        $weight_head  = $worksheet->get_cell(0,4)->value();
        $weight_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,5)) {
        $description_head  = $worksheet->get_cell(0,5)->value();
        $description_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,6)) {
        $box_name_head  = $worksheet->get_cell(0,6)->value();
        $box_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,7)) {
	$seedlot_quality = $worksheet->get_cell(0,7)->value();
    }
    if ($worksheet->get_cell(0,8)) {
	$seedlot_source = $worksheet->get_cell(0, 8)->value();
    }

    if (!$seedlot_name_head || $seedlot_name_head ne 'seedlot_name' ) {
        push @error_messages, "Célula A1: seedlot_name está ausente do cabeçalho";
    }
    if (!$accession_name_head || $accession_name_head ne 'accession_name') {
        push @error_messages, "Célula B1: accession_name está ausente do cabeçalho";
    }
    if (!$operator_name_head || $operator_name_head ne 'operator_name') {
        push @error_messages, "Célula C1: operator_name está ausente do cabeçalho";
    }
    if (!$amount_head || $amount_head ne 'amount') {
        push @error_messages, "Célula D1: amount está ausente do cabeçalho";
    }
    if (!$weight_head || $weight_head ne 'weight(g)') {
        push @error_messages, "Célula E1: weight(g) está ausente do cabeçalho";
    }
    if (!$description_head || $description_head ne 'description') {
        push @error_messages, "Célula F1: description está ausente do cabeçalho";
    }
    if (!$box_name_head || $box_name_head ne 'box_name') {
        push @error_messages, "Célula G1: box_name está ausente do cabeçalho";
    }

    # (seedlot quality and seedlot source are not required fields)

    my %seen_seedlot_names;
    my %seen_accession_names;
    my %seen_source_names;

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $seedlot_name;
        my $accession_name;
        my $operator_name;
        my $amount = 'NA';
        my $weight = 'NA';
        my $description;
        my $box_name;
        my $quality;
        my $source;

        if ($worksheet->get_cell($row,0)) {
            $seedlot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $accession_name = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $operator_name = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $amount =  $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $weight =  $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $description =  $worksheet->get_cell($row,5)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $box_name =  $worksheet->get_cell($row,6)->value();
        }
        if ($seedlot_quality && $worksheet->get_cell($row, 7)) {
            $quality = $worksheet->get_cell($row, 7)-> value();
        }
        if ($seedlot_source && $worksheet->get_cell($row, 8)) {
            $source = $worksheet->get_cell($row, 8)->value();
            $source =~ s/^\s+|\s+$//g;
        }

        if (!defined $seedlot_name && !defined $accession_name) {
            last;
        }

        if (!$seedlot_name || $seedlot_name eq '' ) {
            push @error_messages, "Célula A$row_name: seedlot_name ausente.";
        }
        elsif ($seedlot_name =~ /\s/ || $seedlot_name =~ /\// || $seedlot_name =~ /\\/ ) {
            push @error_messages, "Célula A$row_name: seedlot_name não deve conter espaços nem barras.";
        }
        else {
            #file must not contain duplicate plot names
            if ($seen_seedlot_names{$seedlot_name}) {
                push @error_messages, "Célula A$row_name: seedlot_name duplicado na célula A".$seen_seedlot_names{$seedlot_name}.": $seedlot_name";
            }
            $seedlot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_seedlot_names{$seedlot_name}=$row_name;
        }

        if (!$accession_name || $accession_name eq '') {
            push @error_messages, "Célula B:$row_name: você deve informar um accession_name para o conteúdo do lote de sementes.";
        } else {
            if ($accession_name){
                $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
                $seen_accession_names{$accession_name}++;
            }
        }

        if (!defined($operator_name) || $operator_name eq '') {
            push @error_messages, "Célula C$row_name: operator_name ausente";
        }

        if (!defined($amount) || $amount eq '') {
            push @error_messages, "Célula D$row_name: amount ausente";
        }
        if (!defined($weight) || $weight eq '') {
            push @error_messages, "Célula E$row_name: weight(g) ausente";
        }
        if ($amount eq 'NA' && $weight eq 'NA') {
            push @error_messages, "Na linha $row_name, você deve informar um peso em gramas ou uma quantidade de sementes.";
        }

        if (!defined($box_name) || $box_name eq '') {
            push @error_messages, "Célula G$row_name: box_name ausente";
        }

	if ($source) {
	    $seen_source_names{$source}++;
	}
    }

    my @accessions = keys %seen_accession_names;
    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'accessions',\@accessions)->{'missing'}};

    if (scalar(@accessions_missing) > 0) {
        push @error_messages, "Os seguintes acessos não estão no banco de dados como uniquenames ou sinônimos: ".join(',',@accessions_missing);
        $errors{'missing_accessions'} = \@accessions_missing;
    }

    if (scalar(@accessions_missing) > 0) {
        push @error_messages, "Os seguintes acessos não estão no banco de dados como uniquenames ou sinônimos: ".join(',',@accessions_missing);
        $errors{'missing_accessions'} = \@accessions_missing;
    }

    my @sources = keys %seen_source_names;
    my $source_validator = CXGN::List::Validate->new();
    my @sources_missing = @{$source_validator->validate($schema,'seedlots_or_plots_or_subplots_or_plants_or_crosses_or_accessions',\@sources)->{'missing'}};

    if (scalar(@sources_missing) > 0) {
	push @error_messages, "Os seguintes lotes de sementes de origem não foram encontrados no banco de dados: ".join(',',@sources_missing);
	$errors{'missing_sources'} = \@sources_missing;
    }

    # Check if Seedlot names already exist as other stock names
    my @seedlots = keys %seen_seedlot_names;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'uniquename' => { -in => \@seedlots }
    });
    while (my $r=$rs->next) {
        if ( $r->type->name ne 'seedlot' ) {
            push @error_messages, "Célula A".$seen_seedlot_names{$r->uniquename}.": o nome de material já existe no banco de dados: ".$r->uniquename.".  O nome do lote de sementes deve ser único.";
        }
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
    my %parsed_seedlots;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    my %seen_accession_names;
    my %seen_seedlot_names;
    for my $row ( 1 .. $row_max ) {
        my $seedlot_name;
        my $accession_name;
        if ($worksheet->get_cell($row,0)) {
            $seedlot_name = $worksheet->get_cell($row,0)->value();
            $seedlot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_seedlot_names{$seedlot_name}++;
        }
        if ($worksheet->get_cell($row,1)) {
            $accession_name = $worksheet->get_cell($row,1)->value();
            $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_accession_names{$accession_name}++;
        }

        if (!defined $seedlot_name && !defined $accession_name) {
            last;
        }

    }

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();

    my @accessions = keys %seen_accession_names;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@accessions },
        'type_id' => $accession_cvterm_id,
    });
    my %accession_lookup;
    while (my $r=$rs->next){
        $accession_lookup{$r->uniquename} = $r->stock_id;
    }
    my $acc_synonym_rs = $schema->resultset("Stock::Stock")->search({
        'me.is_obsolete' => { '!=' => 't' },
        'stockprops.value' => { -in => \@accessions},
        'me.type_id' => $accession_cvterm_id,
        'stockprops.type_id' => $synonym_cvterm_id
    },{join => 'stockprops', '+select'=>['stockprops.value'], '+as'=>['synonym']});
    my %acc_synonyms_lookup;
    while (my $r=$acc_synonym_rs->next){
        $acc_synonyms_lookup{$r->get_column('synonym')}->{$r->uniquename} = $r->stock_id;
    }
    my @seedlots = keys %seen_seedlot_names;
    my $seedlot_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@seedlots },
        'type_id' => $seedlot_cvterm_id
    });
    my %seedlot_lookup;
    while (my $r=$seedlot_rs->next){
        $seedlot_lookup{$r->uniquename} = $r->stock_id;
    }

    for my $row ( 1 .. $row_max ) {
        my $seedlot_name;
        my $accession_name;
        my $operator_name;
        my $amount = 'NA';
        my $weight = 'NA';
        my $description;
        my $box_name;
        my $quality;
        my $source;

        if ($worksheet->get_cell($row,0)) {
            $seedlot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $accession_name = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $operator_name =  $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $amount =  $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $weight =  $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $description =  $worksheet->get_cell($row,5)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $box_name =  $worksheet->get_cell($row,6)->value();
        }
        if ($worksheet->get_cell($row,7)) {
            $quality = $worksheet->get_cell($row,7)->value();
        }
        if ($worksheet->get_cell($row,8)) {
            $source = $worksheet->get_cell($row, 8)->value();
        }

        if (!defined $seedlot_name && !defined $accession_name) {
            last;
        }

        $seedlot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $source =~ s/^\s+|\s+$//g; # also trim

        my $accession_stock_id;
        if ($acc_synonyms_lookup{$accession_name}){
            my @accession_names = keys %{$acc_synonyms_lookup{$accession_name}};
            if (scalar(@accession_names)>1){
                print STDERR "There is more than one uniquename for this synonym $accession_name. this should not happen!\n";
            }
            $accession_stock_id = $acc_synonyms_lookup{$accession_name}->{$accession_names[0]};
            $accession_name = $accession_names[0];
        } else {
            $accession_stock_id = $accession_lookup{$accession_name};
        }

        my $source_id;

        if ($source) {
            my $source_row = $self->get_chado_schema->resultset("Stock::Stock")->find( { uniquename => $source });
            if ($source_row) {
                $source_id = $source_row->stock_id();
            }
        }

        $parsed_seedlots{$seedlot_name} = {
            seedlot_id => $seedlot_lookup{$seedlot_name}, #If seedlot name already exists, this will allow us to update information for the seedlot
            accession => $accession_name,
            accession_stock_id => $accession_stock_id,
            cross_name => undef,
            cross_stock_id => undef,
            amount => $amount,
            weight_gram => $weight,
            description => $description,
            box_name => $box_name,
            operator_name => $operator_name,
            quality => $quality,
            source => $source,
            source_id => $source_id,
        };

    }
    #print STDERR Dumper \%parsed_seedlots;

    $self->_set_parsed_data(\%parsed_seedlots);
    return 1;
}


1;

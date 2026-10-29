package CXGN::Pedigree::ParseUpload::Plugin::IntercrossCSV;

use utf8;
use File::Slurp;
use Text::CSV;
use Moose::Role;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;


sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $delimiter = ',';
    my @error_messages;
    my %errors;

    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        $errors{'error_messages'} = "Não foi possível ler o arquivo.";
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $header_row = <$fh>;
    my @columns;
    if ($csv->parse($header_row)) {
        @columns = $csv->fields();
    } else {
        $errors{'error_messages'} = "Não foi possível analisar a linha de cabeçalho.";
        $self->_set_parse_errors(\%errors);
        return;
    }

    #  Check headers
    if ($columns[0] ne 'crossDbId'){
        push @error_messages, "Conteúdo do arquivo incorreto. A primeira coluna deve ser crossDbId.";
    }

    if ($columns[1] ne 'femaleObsUnitDbId'){
        push @error_messages, "Conteúdo do arquivo incorreto. A segunda coluna deve ser femaleObsUnitDbId.";
    }

    if ($columns[2] ne 'maleObsUnitDbId'){
        push @error_messages, "Conteúdo do arquivo incorreto. A terceira coluna deve ser maleObsUnitDbId.";
    }

    if ($columns[3] ne 'timestamp'){
        push @error_messages, "Conteúdo do arquivo incorreto. A quarta coluna deve ser timestamp.";
    }

    if ($columns[4] ne 'person'){
        push @error_messages, "Conteúdo do arquivo incorreto. A quinta coluna deve ser person.";
    }

    if ($columns[5] ne 'experiment'){
        push @error_messages, "Conteúdo do arquivo incorreto. A sexta coluna deve ser experiment.";
    }

    if ($columns[6] ne 'type'){
        push @error_messages, "Conteúdo do arquivo incorreto. A sétima coluna deve ser type.";
    }

    if ($columns[7] ne 'fruits'){
        push @error_messages, "Conteúdo do arquivo incorreto. A oitava coluna deve ser fruits.";
    }

    if ($columns[8] ne 'flowers'){
        push @error_messages, "Conteúdo do arquivo incorreto. A nona coluna deve ser flowers.";
    }

    if ($columns[9] ne 'seeds'){
        push @error_messages, "Conteúdo do arquivo incorreto. A décima coluna deve ser seeds.";
    }

    my %parent_names;
    my %experiment;
    while ( my $row = <$fh> ){
        my @column_values;
        if ($csv->parse($row)) {
            @column_values = $csv->fields();
        } else {
            $errors{'error_messages'} = "Não foi possível analisar a linha $row.";
            $self->_set_parse_errors(\%errors);
            return;
        }

        my $crossing_experiment_name = $column_values[5];
        $experiment{$crossing_experiment_name}++;
        my $crossing_experiment_rs = $schema->resultset("Project::Project")->find( { name => $crossing_experiment_name });

        if (!$crossing_experiment_rs) {
            push @error_messages, "Erro! Experimento de cruzamento: $crossing_experiment_name não foi encontrado no banco de dados.\n";
    	}

        my $female_parent = $column_values[1];
        $parent_names{$female_parent}++;

        my $male_parent = $column_values[2];
        $parent_names{$male_parent}++;

    }

    my @experiment_list = keys %experiment;
    if (scalar(@experiment_list) > 1) {
        push @error_messages, "Todos os cruzamentos de cada arquivo Intercross devem estar no mesmo crossing_experiment";
    }

    my @parent_list = keys %parent_names;
    my $parent_validator = CXGN::List::Validate->new();

    my @parents_missing = @{$parent_validator->validate($schema,'accessions_or_populations_or_crosses_or_plots_or_plants',\@parent_list)->{'missing'}};

    if (scalar(@parents_missing) > 0) {
        push @error_messages, "Os seguintes genitores não estão no banco de dados, ou não estão no banco de dados como nomes de acessos, nomes de populações, IDs únicos de cruzamento, nomes de parcelas ou nomes de plantas: ".join(',',@parents_missing);
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
    my $delimiter = ',';

    my $csv = Text::CSV->new({ sep_char => ',' });
    my %data;

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        return;
    }

    my $header_row = <$fh>;
    my @header_columns;
    if ($csv->parse($header_row)) {
        @header_columns = $csv->fields();
    } else {
        return;
    }

    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            return;
        }

        my $transaction_id = $columns[0];
        my $female_parent = $columns[1];
        my $male_parent = $columns[2];
        my $timestamp = $columns[3];
        my $person = $columns[4];
        my $crossing_experiment = $columns[5];
        my $cross_type = $columns[6];
        my $number_of_fruits = $columns[7];
        my $number_of_flowers = $columns[8];
        my $number_of_seeds = $columns[9];

        my $crossing_experiment_id = $schema->resultset("Project::Project")->find({ name => $crossing_experiment })->project_id();
        my $female_parent_id = $schema->resultset("Stock::Stock")->find({ name => $female_parent })->stock_id();
        my $male_parent_id = $schema->resultset("Stock::Stock")->find({ name => $male_parent })->stock_id();

        my $cross_identifier = $crossing_experiment_id.'_'.$female_parent_id.'_'.$male_parent_id;
#        print STDERR "CROSS IDENTIFIER =".Dumper($cross_identifier)."\n";
        $data{'crossing_experiment_name'} = $crossing_experiment;
        $data{'crosses'}{$cross_identifier}{'intercross_female_parent'} = $female_parent;
        $data{'crosses'}{$cross_identifier}{'intercross_male_parent'} = $male_parent;
        $data{'crosses'}{$cross_identifier}{'cross_type'} = $cross_type;
        $data{'crosses'}{$cross_identifier}{'activities'}{$transaction_id}{'Timestamp'} = $timestamp;
        $data{'crosses'}{$cross_identifier}{'activities'}{$transaction_id}{'Operator'} = $person;
        $data{'crosses'}{$cross_identifier}{'activities'}{$transaction_id}{'Number of Fruits'} = $number_of_fruits;
        $data{'crosses'}{$cross_identifier}{'activities'}{$transaction_id}{'Number of Flowers'} = $number_of_flowers;
        $data{'crosses'}{$cross_identifier}{'activities'}{$transaction_id}{'Number of Seeds'} = $number_of_seeds;
    }

    my $parsed_result = \%data;
#    print STDERR "DATA =".Dumper($parsed_result)."\n";

    $self->_set_parsed_data($parsed_result);

    return 1;

}

1;

package CXGN::Pedigree::ParseUpload::Plugin::PedigreesGeneric;

use utf8;
use Moose::Role;
use CXGN::File::Parse;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Pedigree::AddPedigrees;

sub _validate_with_plugin {
    my $self = shift;

    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();

    my @error_messages;
    my %errors;

    my $parser = CXGN::File::Parse->new (
        file => $filename,
        required_columns => [ 'progeny name', 'female parent accession', 'type' ],
        optional_columns => [ 'male parent accession' ],
        column_aliases => {
            'progeny name' => ['progeny_name', 'progeny'],
            'female parent accession' => ['female_parent_accession', 'female_parent', 'female parent'],
            'type' => ['cross_type', 'cross type'],
            'male parent accession' => ['male_parent_accession', 'male_parent', 'male parent']
        },
        unique_only_columns => [ 'progeny name' ]
    );
    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{errors};
    my $parsed_columns = $parsed->{columns};
    my $parsed_data = $parsed->{data};
    my $parsed_values = $parsed->{values};
    my $additional_columns = $parsed->{additional_columns};

    # return if parsing error
    if ( $parsed_errors && scalar(@$parsed_errors) > 0 ) {
        $errors{'error_messages'} = $parsed_errors;
        $self->_set_parse_errors(\%errors);
        return;
    }

    if ( $additional_columns && scalar(@$additional_columns) > 0 ) {
        $errors{'error_messages'} = [
            "As seguintes colunas não são reconhecidas: " . join(', ', @$additional_columns) . ". Verifique o formato da planilha para as colunas permitidas."
        ];
        $self->_set_parse_errors(\%errors);
        return;
    }

    my %supported_cross_types = ( biparental => 1, open => 1, self => 1, sib => 1, polycross => 1, backcross => 1, reselected => 1, doubled_haploid => 1, dihaploid_induction => 1 );
    my $seen_cross_types = $parsed_values->{'type'};
    my $seen_progenies = $parsed_values->{'progeny name'};
    my $seen_female_parents = $parsed_values->{'female parent accession'};
    my $seen_male_parents = $parsed_values->{'male parent accession'};
    my @all_stocks;
    push @all_stocks, @$seen_progenies;
    push @all_stocks, @$seen_female_parents;
    push @all_stocks, @$seen_male_parents;

    foreach my $type (@$seen_cross_types) {
        if (!exists $supported_cross_types{$type}) {
            push @error_messages, "Tipo de cruzamento não suportado: $type. O tipo de cruzamento deve ser biparental, self, open, sib, backcross, reselected, polycross, doubled_haploid ou dihaploid_induction";
        }
    }

    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'accessions_or_populations_or_vector_constructs',\@all_stocks)->{'missing'}};
    my $cross_validator = CXGN::List::Validate->new();
    my @stocks_missing = @{$cross_validator->validate($schema,'crosses',\@accessions_missing)->{'missing'}};
    if (scalar(@stocks_missing) > 0) {
        push @error_messages, "Os seguintes acessos não estão no banco de dados, ou não estão no banco de dados como nomes únicos: ".join(',',@stocks_missing);
    }

    my @pedigrees;
    foreach my $row (@$parsed_data) {
        my $female_parent;
        my $male_parent;

        my $progeny = $row->{'progeny name'};
        my $female = $row->{'female parent accession'};
        my $male = $row->{'male parent accession'};
        my $cross_type = $row->{'type'};
        my $line_number = $row->{'_row'};

        if ($female eq $male) {
            if ($cross_type ne 'self' && $cross_type ne 'sib' && $cross_type ne 'reselected' && $cross_type ne 'doubled_haploid' && $cross_type ne 'dihaploid_induction'){
                push @error_messages, "O genitor feminino e o genitor masculino são iguais na linha $line_number, mas o tipo de cruzamento não é self, sib, reselected, doubled_haploid ou dihaploid_induction.";
            }
        }
        if (($female && !$male) && ($cross_type ne 'open')) {
            push @error_messages, "Para $progeny na linha $line_number nenhum genitor masculino foi especificado e o cross_type não é open...";
        }
        if ($cross_type eq 'biparental') {
            if (!$male){
                push @error_messages, "Para $progeny o tipo de cruzamento é biparental, mas nenhum genitor masculino foi informado";
            }
        }
        if($cross_type eq 'backcross') {
            if (!$male){
                push @error_messages, "Para $progeny o tipo de cruzamento é backcross, mas nenhum genitor masculino foi informado";
            }
        }
        elsif($cross_type eq "sib") {
            if (!$male){
                push @error_messages, "Para $progeny o tipo de cruzamento é sib, mas nenhum genitor masculino foi informado";
            }
        }
        elsif($cross_type eq "polycross") {
            if (!$male){
                push @error_messages, "Para $progeny o tipo de cruzamento é polycross, mas nenhum genitor masculino foi informado";
            }
        }
    }

    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $self->_set_parsed_data($parsed);
    return 1;

}

sub _parse_with_plugin {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $parsed = $self->_parsed_data();
    my $parsed_data = $parsed->{data};

    my $pedigrees = CXGN::Pedigree::AddPedigrees->new({ schema => $schema });
    my $generated_pedigrees = $pedigrees->generate_pedigrees($parsed_data);

    my $validate = CXGN::Pedigree::AddPedigrees->new({ schema => $schema, pedigrees => $generated_pedigrees });
    my $error;
    my $pedigree_check = $validate->validate_pedigrees();

    my %return;
    if (!$pedigree_check){
        $return{'error_messages'} = "Houve um problema ao validar os pedigrees. Os pedigrees não foram armazenados.";
        $self->_set_parse_errors(\%return);
        return;
    } else {
        $return{'pedigree_check'} = $pedigree_check->{error};
        $return{'pedigree_data'} = $parsed_data;
    }

    $self->_set_parsed_data(\%return);
    return 1;
}


1;

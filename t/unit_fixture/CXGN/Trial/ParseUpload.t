
use strict;
use utf8;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use CXGN::Trial::ParseUpload;
use Data::Dumper;

my $f = SGN::Test::Fixture->new();

for my $extension ("xls", "xlsx", "csv") {

    my $p = CXGN::Trial::ParseUpload->new({ filename => "t/data/genotype_trial_upload/CASSAVA_GS_74Template.csv", chado_schema => $f->bcs_schema() });
    $p->load_plugin("ParseIGDFile");

    my $results = $p->parse();
    my $errors = $p->get_parse_errors();

    ok(scalar(@{$errors->{'error_messages'}}) == 0, "no parse errors");

    is_deeply($results, { trial_name => "CASSAVA_GS_74", blank_well => "F05", user_id => 'I.Rabbi@cgiar.org', project_name => 'NEXTGENCASSAVA' }, "parse results test");

    #print STDERR join ",", @{$errors->{'error_messages'}};

    $p = CXGN::Trial::ParseUpload->new({ filename => "t/data/genotype_trial_upload/CASSAVA_GS_74Template_missing_blank.csv", chado_schema => $f->bcs_schema() });
    $p->load_plugin("ParseIGDFile");

    $results = $p->parse();
    $errors = $p->get_parse_errors();

    ok($errors->{'error_messages'}->[0] eq "Nenhum poço em branco encontrado na planilha", "detect missing blank entry");

    $p = CXGN::Trial::ParseUpload->new({ filename => "t/data/genotype_trial_upload/CASSAVA_GS_74Template_messed_up_trial_name.csv", chado_schema => $f->bcs_schema() });
    $p->load_plugin("ParseIGDFile");

    $results = $p->parse();
    $errors = $p->get_parse_errors();

    ok($errors->{'error_messages'}->[0] eq "Todos os nomes de ensaio na coluna de ensaio devem ser idênticos", "detect messed up trial name");

    $p = CXGN::Trial::ParseUpload->new({ filename => "t/data/trial/trial_layout_bad_accessions.$extension", chado_schema => $f->bcs_schema() });
    $p->load_plugin("TrialGeneric");

    $results = $p->parse();
    $errors = $p->get_parse_errors();
    #print STDERR Dumper $errors;
    ok($errors->{'error_messages'}->[0] =~ /Os seguintes nomes de entrada não estão no banco de dados como nomes únicos ou sinônimos/, 'check that accessions not in db');
    ok(scalar(@{$errors->{'error_messages'}}) == 1, 'check that accessions not in db');
    ok(scalar(@{$errors->{'missing_stocks'}}) == 8, 'check that accessions not in db');

    $p = CXGN::Trial::ParseUpload->new({ filename => "t/data/genotype_trial_upload/CASSAVA_GS_74Template_messed_up_trial_name.csv", chado_schema => $f->bcs_schema() });
    $p->load_plugin("TrialGeneric");

    $results = $p->parse();
    $errors = $p->get_parse_errors();
    my $expected = {
        'error_messages' => [
            'A coluna obrigatória stock_name está ausente',
            'A coluna obrigatória plot_number está ausente',
            'A coluna obrigatória block_number está ausente'
        ]
    };
    is_deeply($errors, $expected, 'check file format errors');

    $f->clean_up_db();
}

done_testing();

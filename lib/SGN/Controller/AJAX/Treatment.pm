package SGN::Controller::AJAX::Treatment;
use utf8;

use Moose;
use CXGN::Trait::Treatment;

BEGIN {extends 'Catalyst::Controller::REST'};

use strict;
use warnings;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

sub create_treatment :Path('/ajax/treatment/create') {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if (!($c->user() && $c->user->check_roles('curator'))) {
        $c->stash->{rest} = {error => "Você não tem permissão para criar novos tratamentos.\n"};
        return;
    }

    if (! $c->config->{allow_treatment_edits}) {
        $c->stash->{rest} = {error => "Você não tem permissão para criar novos tratamentos.\n"};
        return;
    }

    my $name = $c->req->param('name') ? $c->req->param('name') : undef;
    my $definition = $c->req->param('definition') ? $c->req->param('definition') : undef;
    my $format = $c->req->param('format') ? $c->req->param('format') : undef;
    my $default_value = $c->req->param('default_value') ? $c->req->param('default_value') : undef;
    my $minimum = $c->req->param('minimum') ? $c->req->param('minimum') : undef;
    my $maximum = $c->req->param('maximum') ? $c->req->param('maximum') : undef;
    my $categories = $c->req->param('categories') ? $c->req->param('categories') : undef;
    my $category_details = $c->req->param('category_details') ? $c->req->param('category_details') : undef;
    my $repeat_type = $c->req->param('repeat_type') ? $c->req->param('repeat_type') : undef;
    my $parent_terms = $c->req->param('parent_terms') ? $c->req->param('parent_terms') : undef;

    $name =~ s/^\s+//;
    $name =~ s/\s+$//;
    $name =~ s/\|//g;

    $definition =~ s/^\s+//;
    $definition =~ s/\s+$//;

    if (defined($categories)) {
        $categories =~ s/^\s+//;
        $categories =~ s/\s+$//;
    }

    if (defined($default_value)) {
        $default_value = lc($default_value);
        $default_value =~ s/^\s+//;
        $default_value =~ s/\s+$//;
    }

    my $error = "";

    if (!$name) {
        $error .= "Informe um nome.\n";
    }
    if (!$definition) {
        $error .= "Informe uma definição.\n";
    }
    if (defined($definition) && $definition !~ m/([^\s]+\s+){6,}/) {
        $error .= "A definição informada parece curta. Certifique-se de que ela descreva completamente o tratamento e permita diferenciá-lo de outros tratamentos.\n";
    }
    if (!$format || $format !~ m/numeric|categorical|date|percent|counter|boolean|text|ontology/i) {
        $error .= "O formato deve ser numeric, categorical, date, percent, counter, boolean, text ou ontology.\n";
    }
    if (defined($categories) && defined($default_value) && $categories !~ m/$default_value/) {
        $error .= "O valor padrão do tratamento não está na lista de categorias.\n";
    }
    if (defined($default_value) && $default_value =~ m/[=\/]/) {
        $error .= "O valor padrão informado contém caracteres especiais.\n";
    }
    if (defined($minimum) && defined($maximum) && $maximum < $minimum) {
        $error .= "O valor máximo não pode ser menor que o valor mínimo.\n";
    }
    if (defined($repeat_type) && $repeat_type ne 'single' && $repeat_type ne 'multiple' && $repeat_type ne 'time_series') {
        $error .- "Tipo de repetição inválido. Deve ser single, multiple ou time_series.\n";
    }

    if ($error) {
        $c->stash->{rest} = {error => $error};
        return;
    }

    my $new_treatment;

    eval {
        if ($format =~ m/numeric|percent|counter|boolean/i) {
            $new_treatment = CXGN::Trait::Treatment->new({
                bcs_schema => $schema,
                definition => $definition,
                name => $name,
                format => $format
            });
            if (defined($minimum)) {
                $new_treatment->minimum($minimum);
            }
            if (defined($maximum)) {
                $new_treatment->maximum($maximum);
            }
            if ($repeat_type) {
                $new_treatment->repeat_type($repeat_type);
            }
        } elsif ($format eq "categorical") {
            $new_treatment = CXGN::Trait::Treatment->new({
                bcs_schema => $schema,
                name => $name,
                definition => $definition,
                format => $format,
            });
            if ($categories ne "") {
                $new_treatment->categories($categories);
                $new_treatment->category_details($category_details);
            }
            if ($repeat_type) {
                $new_treatment->repeat_type($repeat_type);
            }
        } elsif ($format eq "ontology" || $format eq "date" || $format eq "text") {
            $new_treatment = CXGN::Trait::Treatment->new({
                bcs_schema => $schema,
                name => $name,
                definition => $definition,
                format => $format
            });
        } 

        if (defined($default_value)) {
            $new_treatment->default_value($default_value);
        }

        $new_treatment->store($parent_terms);
    };

    if ($@) {
        $c->stash->{rest} = {error => "Ocorreu um erro ao tentar criar o tratamento: $@"};
        return;
    }

    $c->stash->{rest} = {success => 1};
}

1;
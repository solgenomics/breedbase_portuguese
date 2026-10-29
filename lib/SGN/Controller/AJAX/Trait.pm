package SGN::Controller::AJAX::Trait;
use utf8;

use Moose;
use CXGN::Trait;

BEGIN {extends 'Catalyst::Controller::REST'};

use strict;
use warnings;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

sub create_trait :Path('/ajax/trait/create') {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if (!($c->user() && $c->user->check_roles('curator'))) {
        $c->stash->{rest} = {error => "Você não tem permissão para criar novas características.\n"};
        return;
    }

    if (! $c->config->{allow_trait_edits}) {
        $c->stash->{rest} = {error => "Você não tem permissão para criar novas características.\n"};
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
        $categories = lc($categories);
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
        $error .= "A definição informada parece curta. Certifique-se de que ela descreva completamente a característica e permita diferenciá-la de outras características.\n";
    }
    if (!$format || $format !~ m/numeric|categorical|date|percent|counter|boolean|text|ontology/i) {
        $error .= "O formato deve ser numeric, categorical, date, percent, counter, boolean, text ou ontology.\n";
    }
    if (defined($categories) && defined($default_value) && $categories !~ m/$default_value/) {
        $error .= "O valor padrão da característica não está na lista de categorias.\n";
    }
    if (defined($default_value) && $default_value =~ m/[=\/]/) {
        $error .= "O valor padrão informado contém caracteres especiais.\n";
    }
    if (defined($minimum) && defined($maximum) && $maximum < $minimum) {
        $error .= "O valor máximo não pode ser menor que o valor mínimo.\n";
    }
    if ($repeat_type && $repeat_type ne 'single' && $repeat_type ne 'multiple' && $repeat_type ne 'time_series') {
        $error .- "Tipo de repetição inválido. Deve ser single, multiple ou time_series.\n";
    }

    if ($error) {
        $c->stash->{rest} = {error => $error};
        return;
    }

    my $new_trait;

    eval {
        if ($format =~ m/numeric|percent|counter|boolean/i) {
            $new_trait = CXGN::Trait->new({
                bcs_schema => $schema,
                definition => $definition,
                name => $name,
                format => $format
            });
            if (defined($minimum)) {
                $new_trait->minimum($minimum);
            }
            if (defined($maximum)) {
                $new_trait->maximum($maximum);
            }
            if ($repeat_type) {
                $new_trait->repeat_type($repeat_type);
            }
        } elsif ($format eq "categorical") {
            $new_trait = CXGN::Trait->new({
                bcs_schema => $schema,
                name => $name,
                definition => $definition,
                format => $format
            });
            if (defined($categories)) {
                $new_trait->categories($categories);
                $new_trait->category_details($category_details);
            }
            if ($repeat_type) {
                $new_trait->repeat_type($repeat_type);
            }
        } elsif ($format eq "ontology" || $format eq "date" || $format eq "text") {
            $new_trait = CXGN::Trait->new({
                bcs_schema => $schema,
                name => $name,
                definition => $definition,
                format => $format
            });
        }

        if (defined($default_value)) {
            $new_trait->default_value($default_value);
        }

        $new_trait->interactive_store($parent_terms);
    };

    if ($@) {
        $c->stash->{rest} = {error => "Ocorreu um erro ao tentar criar a característica: $@"};
        return;
    }

    $c->stash->{rest} = {success => 1};
}

sub edit_trait :Path('/ajax/trait/edit') {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if (!($c->user() && $c->user->check_roles('curator'))) {
        $c->stash->{rest} = {error => "Você não tem permissão para editar cvterms.\n"};
        return;
    }

    if (! $c->config->{allow_trait_edits}) {
        $c->stash->{rest} = {error => "Você não tem permissão para editar cvterms. Verifique a configuração do servidor.\n"};
        return;
    }

    my $cvterm_id = $c->req->param('cvterm_id') ? $c->req->param('cvterm_id') : undef;
    my $new_name = $c->req->param('new_name') ? $c->req->param('new_name') : undef;
    my $new_definition = $c->req->param('new_definition') ? $c->req->param('new_definition') : undef;

    if (!$cvterm_id) {
        $c->stash->{rest} = {error => "ID do cvterm ausente.\n"};
        return;
    }

    eval {
        my $trait = CXGN::Trait->new({
            bcs_schema => $schema,
            cvterm_id => $cvterm_id
        });

        if (defined($new_name)) {
            $trait->name($new_name);
        }
        if (defined($new_definition)) {
            $trait->definition($new_definition);
        }

        $trait->interactive_update();
    };

    if ($@) {
        $c->stash->{rest} = {error => "Ocorreu um erro ao atualizar o cvterm: $@"};
        return;
    }

    $c->stash->{rest} = {success => 1};
}

sub delete_trait :Path('/ajax/trait/delete') {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if (!($c->user() && $c->user->check_roles('curator'))) {
        $c->stash->{rest} = {error => "Você não tem permissão para editar cvterms.\n"};
        return;
    }

    if (! $c->config->{allow_trait_edits}) {
        $c->stash->{rest} = {error => "Você não tem permissão para editar cvterms. Verifique a configuração do servidor.\n"};
        return;
    }

    my $cvterm_id = $c->req->param('cvterm_id') ? $c->req->param('cvterm_id') : undef;

    if (!$cvterm_id) {
        $c->stash->{rest} = {error => "ID do cvterm ausente.\n"};
        return;
    }

    eval {
        my $trait = CXGN::Trait->new({
            bcs_schema => $schema,
            cvterm_id => $cvterm_id
        });

        $trait->delete();
    };

    if ($@) {
        $c->stash->{rest} = {error => "Ocorreu um erro ao excluir o cvterm: $@"};
        return;
    }

    $c->stash->{rest} = {success => 1};
}

1;
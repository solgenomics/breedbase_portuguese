
package SGN::Controller::Dataset;
use utf8;

use Moose;
use CXGN::Dataset;
use Data::Dumper;
use strict;
use warnings;

BEGIN { extends 'Catalyst::Controller'; }

sub dataset :Chained('/') Path('dataset') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $html = "";
    
    my $dataset;

    eval {
        $dataset = CXGN::Dataset->new({
            schema => $schema,
            people_schema => $people_schema,
            sp_dataset_id => $dataset_id
        });
    };
    if ($@) {
        print STDERR "Dataset retrieval error: $@ \n";
        $c->stash->{template} = 'generic_message.mas';
	    $c->stash->{message} = "O conjunto de dados solicitado não existe ou foi excluído.";
	    return;
    }
    
    # Only show dataset if the user is the owner OR the dataset is public
    my $user_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $owner_id = $dataset->sp_person_id;
    if ( ! ($user_id == $owner_id || $dataset->is_public) ) {
        $c->stash->{template} = 'generic_message.mas';
        $c->stash->{message} = "Você não tem acesso a este conjunto de dados.<br /><br />Se você é o proprietário deste conjunto de dados, verifique se está conectado ou peça ao proprietário para torná-lo público.";
        return;
    }

    my $info = $dataset->get_dataset_data();

    my $dataset_info = {
        id => $dataset_id,
	    name => $dataset->name(),
	    description => $dataset->description,
	    info => $info
    };

    my $lt = CXGN::List::Transform->new();
    my %transform_dict = (
        'plots' => 'stock_ids_2_stocks',
        'accessions' => 'stock_ids_2_stocks',
        'traits' => 'trait_ids_2_trait_names',
        'locations' => 'locations_ids_2_location',
        'plants' => 'stock_ids_2_stocks',
        'trials' => 'project_ids_2_projects',
        'trial_types' => 'cvterm_ids_2_cvterms',
        'breeding_programs' => 'project_ids_2_projects',
        'genotyping_protocols' => 'nd_protocol_ids_2_protocols'
    );
    $html .= '<table class="table-bordered"><thead><tr>' . "\n";
    foreach my $category (@{$dataset_info->{info}->{category_order}}) {
        $html .= '<th>' . $category . '</th>';
    }
    $html .= '</tr></thead><tbody><tr>' . "\n";
    foreach my $category (@{$dataset_info->{info}->{category_order}}) {
	    my $ids = $dataset_info->{info}->{categories}->{$category};
	    my @items;
	    if (exists($transform_dict{$category})) {
            my $transform = $lt->transform($schema, $transform_dict{$category}, $ids);
            @items = @{$transform->{transform}};
        } else {
            if (defined($ids)) {
                @items = @$ids;
		    }
        }
	    $html .= "<td><div class='well well-sm'>";
        $html .= "<select class='form-control' multiple>";
        foreach my $item (@items) {
            $html .= "<option value='$item' disabled>$item</option>";
        }
        $html .= "</select>";
        $html .= "</td></div>\n";
    }
    $html .= "</table>";

    my $owner = $people_schema->resultset("SpPerson")->find({ sp_person_id => $dataset->sp_person_id });
    my $onwer_name = $owner->first_name." ".$owner->last_name();

    $c->stash->{dataset_name} = $dataset->name();
    $c->stash->{dataset_id} = $dataset_id;
    $c->stash->{dataset_description} = $dataset->description;
    $c->stash->{dataset_contents} = $html;
    $c->stash->{dataset_owner_id} = $dataset->sp_person_id;
    $c->stash->{dataset_owner_name} = $onwer_name;
    $c->stash->{dataset_is_public} = $dataset->is_public;
    $c->stash->{template} = '/dataset/index.mas';
    
}

sub publish_dataset_authorize_start : Path('/dataset/publish/authorize') Args(1) {
    my $self = shift;
    my $c = shift;
    my $service = shift;

    my $config = $c->get_conf('dataset_archive_clients') || {};
    if ( ! exists $config->{$service} ) {
        $c->stash->{template} = "generic_message.mas";
        $c->stash->{message} = "O serviço selecionado não existe na configuração do servidor";
        return;
    }
    my $selected = $config->{$service};

    my $url = $selected->{web_url} . $selected->{auth_path};
    $url .= '?response_type=code';
    $url .= '&scope=all';
    $url .= '&client_id=' . $selected->{client_id};
    $url .= '&redirect_uri=' . $c->get_conf('main_production_site_url') . $selected->{redirect_path};

    $c->res->redirect($url);
    return;
}

sub publish_dataset_authorize_finish : Path('/dataset/publish/authorize') Args(0) {
    my $self = shift;
    my $c = shift;
    my $error = $c->req->param('error');
    my $code = $c->req->param('code');

    if ( !defined $code && !defined $error ) {
        $error = "Código de autorização não retornado pelo serviço";
    }

    if ( $error ) {
        $c->stash->{template} = 'generic_message.mas';
        $c->stash->{message} = "Não foi possível autorizar o aplicativo: $error";
        return;
    }

    $c->stash->{code} = $code;
    $c->stash->{template} = '/dataset/authorize.mas';
    return;
}

1;

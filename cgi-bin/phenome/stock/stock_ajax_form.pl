use strict;
use warnings;
use utf8;

package CXGN::Phenome::Stock::StockForm;
my $stock_form = CXGN::Phenome::Stock::StockForm->new();

use base qw/CXGN::Page::Form::AjaxFormPage  /;


use CXGN::Tools::Organism;
use Bio::Chado::Schema;
use CXGN::Stock;

use CXGN::People::Person;
use CXGN::Contact;


use Try::Tiny;

use JSON;
use CatalystX::GlobalContext qw( $c );


sub new {
    my $class  = shift;
    my $self   = $class->SUPER::new(@_);
    return $self;
}

sub define_object {
    my $self = shift;
    my %args      = $self->get_args();
    my $stock_id  = $args{stock_id} || $args{object_id};
    my $user_type = $self->get_user()->get_user_type();
    my %json_hash= $self->get_json_hash();
    my $sp_person_id = $self->get_user()->get_sp_person_id();

    print STDERR "this is sp_person_id before dbic_schema: ".$sp_person_id."\n";

    my $schema   = $c->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado', $sp_person_id);

    $self->set_object_id($stock_id);
    $self->set_object_name('Stock'); #this is useful for email messages
    $self->set_object( CXGN::Stock->new({schema=>$schema, stock_id=>$stock_id}) );

    if ( $self->get_object()->is_obsolete() == 1 && $user_type ne 'curator' )
    {
        $json_hash{error}="O material $stock_id está obsoleto!";
    }
    unless ( ( $stock_id =~ m /^\d+$/ || !$stock_id  )  ) {
        $json_hash{error}="Não existe material com o identificador $stock_id";
    }
    $self->set_json_hash(%json_hash);
    $self->set_primary_key("stock_id");
    my @owners;
    #my @owners = $self->get_object()->search_related("stockprops", {
    #type_id => $sp_person_cvterm_id } );

    $self->set_owners( @owners );

    $self->print_json() if $json_hash{error};
}


sub store {
    my $self=shift;

    my $stock    = $self->get_object();
    my $stock_id = $self->get_object_id();
    my %args     = $self->get_args();
    my %json_hash = $self->get_json_hash();
    my $initial_stock_id = $stock_id;

    my $error;
    $stock->species($args{organism});
    $stock->type_id($args{type_id});
    $stock->name($args{uniquename});
    $stock->uniquename($args{uniquename});
    $stock->description($args{description});


    my $message = $stock->exists_in_database();
    my $validate;
    if ($message) {
        $error = " O material $args{uniquename} já existe no banco de dados ";
    }else {
        try{
            $self->SUPER::store(); #this sets $json_hash{validate} if the form validation failed.
            $stock_id = $stock->stock_id() ;
        } catch {
            $error = " Ocorreu um erro. Não foi possível salvar no banco de dados.\n Uma mensagem de e-mail foi enviada à equipe de desenvolvimento da SGN.";
            CXGN::Contact::send_email('stock_ajax_form.pl died', $error . "\n" . $_ , 'sgn-bugs@sgn.cornell.edu');
        };
    }
    #the validate field is false is validation passed for all fields, true if did not pass and the form is re-printed

    %json_hash= $self->get_json_hash();
    $validate= $json_hash{validate};
    $json_hash{error} = $error if $error;

    my $refering_page="/stock/$stock_id/view";
    $self->send_form_email({subject=>"[New stock details stored] stock $stock_id", mailing_list=>'sgn-db-curation@sgn.cornell.edu', refering_page=>"www.solgenomics.net".$refering_page}) if (!$validate && !$json_hash{error});
    $json_hash{refering_page}=$refering_page if !$initial_stock_id && !$validate && !$error;

    $self->set_json_hash(%json_hash);

    $self->print_json();
}


####################################
sub delete {
    ##Delete the stock (actually set obsolete = 't')
    my $self = shift;
    my $check = $self->check_modify_privileges();
    $self->print_json() if $check ; #error or no user privileges

    my $stock      = $self->get_object();
    my $stock_name = $stock->uniquename();
    my $stock_id = $stock->stock_id();
    my %json_hash= $self->get_json_hash();
    my $refering_page="/stock/$stock_id/view";

    if (!$json_hash{error} ) {
        try {
            $stock->is_obsolete(1) ;
            $stock->store();
        }catch {
            $json_hash{error} = " Ocorreu um erro. Não foi possível excluir o material.\n Uma mensagem de e-mail foi enviada à equipe de desenvolvimento da SGN.";
            $self->send_form_email({subject=>"Stock delete failed!  ($stock_name) $_", mailing_list=>'sgn-db-curation@sgn.cornell.edu', refering_page=>"www.solgenomics.net".$refering_page, action=>'delete'});
        };
        $json_hash{reload} = 1;
    }
    $self->send_form_email({subject=>"Stock obsoleted ($stock_name)", mailing_list=>'sgn-db-curation@sgn.cornell.edu', refering_page=>"www.solgenomics.net".$refering_page, action=>'delete'}) if (!$json_hash{error});
    $self->set_json_hash(%json_hash);
    $self->print_json();
}



sub generate_form {
    my $self = shift;
    my $form_id = 'edit_stock'; # a form_id is required for ajax forms

    $self->init_form($form_id) ; ## instantiate static/editable/confirmStore form
    my $stock = $self->get_object();
    my %args  = $self->get_args();
    my $form = $self->get_form();
    my %stock_type_labels = (
        accession => 'Acesso', population => 'População', plot => 'Parcela',
        subplot => 'Subparcela', plant => 'Planta', tissue_sample => 'Amostra de tecido',
        seedlot => 'Lote de sementes', cross => 'Cruzamento', family_name => 'Família',
        vector_construct => 'Construção vetorial',
        'backcross population' => 'População de retrocruzamento',
        'f2 population' => 'População F2',
        'mutant population' => 'População mutante',
        'training population' => 'População de treinamento',
    );

    #########
    my $species = $stock->get_species() ;
    my $organism_id = $species ? $stock->stock->organism_id : undef ;
    my ($stock_type) = $stock->get_schema->resultset("Cv::Cv")->search(
        { name => 'stock_type' , }
        );
    my @types;
    my @type_ids;
    if ($stock_type) {
        my $cvterm_res = $stock_type->
            search_related('cvterms');
        while (my $cvterm = $cvterm_res->next() ) {
            push @types, $stock_type_labels{$cvterm->name()} || $cvterm->name();
            push @type_ids, $cvterm->cvterm_id();
        }
    }
          ##########

    if ( $self->get_action =~ /new|store|edit/ ) {
        $form->add_field(
            display_name => "Organismo",
            field_name   => "Organism",
            id           => "species_name",
            object       => $stock,
            getter       => "get_species",
            setter       => "set_species",
            autocomplete => '/ajax/organism/autocomplete',
            );
        $self->get_form->add_select(
            display_name       => "Tipo de material",
            field_name         => "type_id",
            contents           => $stock->type_id(),
            length             => 20,
            object             => $stock,
            getter             => "type_id",
            setter             => "type_id",
            select_list_ref    => \@types,
            select_id_list_ref => \@type_ids,
            );
    }
    if ( $stock->is_obsolete()  ) {
        $form->add_label(
            display_name => "Estado",
            field_name   => "obsolete_stat",
            contents     => 'OBSOLETO',
            );
    }
    if ( $self->get_action =~ /view/ ) {
        $form->add_label(
            display_name => "Organismo",
            field_name   => "stock_organism",
            contents => $species ? qq|<a href="/organism/$organism_id/view"> | . $species . "</a>" : '',
            );
        $form->add_label(
            display_name => "Tipo de material",
            field_name   => "stock_type",
            contents => $stock_type_labels{$stock->type()} || $stock->type(),
            );
    }

    $form->add_field(
        display_name => "Nome único",
        field_name   => "uniquename",
        object       => $stock,
        getter       => "uniquename",
        setter       => "uniquename",
        validate     => 'string',
        );

    $form->add_textarea(
        display_name => "Descrição",
        field_name   => "description",
        object       => $stock,
        getter       => "description",
        setter       => "description",
        columns      => 40,
        rows         => 4,
        );

    $form->add_hidden(
        field_name => "stock_id",
        contents   => $stock->stock_id(),
        );
    $form->add_hidden(
	field_name => "sp_person_id",
	contents   => $self->get_user()->get_sp_person_id(),
	object     => $stock,
	setter     => "sp_person_id",
	);
    $form->add_hidden(
        field_name => "action",
        contents   => "store",
        );
    if ($self->get_action =~ /view/ ) {
        $form->add_hidden(
            field_name => "type_id",
            contents   => $stock->type_id,
            );
    }
    if ( $self->get_action() =~ /view|edit/ ) {
        $form->from_database();
    }
    elsif ( $self->get_action() =~ /store/ ) {
        my %json_hash = $self->get_json_hash() ;
        print $json_hash{html} ;
        $form->from_request( %args );
    }
}


1;

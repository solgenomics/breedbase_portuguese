=head1 NAME

SGN::Controller::AJAX::Genefamily::Manual - a REST controller class to provide the
backend for objects linked with manual curated gene family (a phenome locusgroup)

=head1 DESCRIPTION

Add new locus members to an existing gene family

=head1 AUTHOR

Naama Menda <nm249@cornell.edu>


=cut

package SGN::Controller::AJAX::Genefamily::Manual;
use utf8;

use Moose;

use List::MoreUtils qw /any /;
use Try::Tiny;
use CXGN::Phenome::Schema;
use CXGN::Chado::Publication;

use CXGN::Page::FormattingHelpers qw/ info_table_html html_alternate_show /;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub display_locusgroup_members : Chained('/genefamily/manual/get_genefamily') :PathPart('members') : ActionClass('REST') { }

sub display_locusgroup_members_GET  {
    my ($self, $c) = @_;
    my $html;
    my %data;
    my $locusgroup = $c->stash->{genefamily};
    my $members = $locusgroup->get_cxgn_members;
    foreach my $locus_id (keys %$members) {
        my $locus = $members->{$locus_id}->{locus};
        my $locus_name = $locus->get_locus_name;
        my $common_name = $locus->get_common_name;
        my $evidence = $members->{$locus_id}->{evidence};
        my $ref = $members->{$locus_id}->{reference};
        no warnings 'uninitialized';
        $data{$common_name} .= qq|<a href="/locus/$locus_id/view">$locus_name</a> ($evidence. $ref)<br />| ;
    }
    foreach my $common_name (sort keys %data) {
        $html .= info_table_html( $common_name  => $data{$common_name},
                                  '__border'   => 0, );
    }
    my $hashref;
    $hashref->{html} = $html;
    $c->stash->{rest} = $hashref;
}


sub add_member:Path('/ajax/genefamily/manual/add') :ActionClass('REST') {}

sub add_member_GET :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{rest} = { error => "Nada aqui, é um GET.." } ;
}

sub add_member_POST :Args(0) {
    my ( $self, $c ) = @_;
    my $locusgroup_id = $c->req->param('locusgroup_id');
    my $locus_input   = $c->req->param('locus') ;
    my $evidence_id   = $c->req->param('evidence_id') ;
    my $reference_id  = $c->req->param('reference_id') ||
        CXGN::Chado::Publication::get_curator_ref($c->dbc->dbh);
    if (!$locus_input) {
        $self->status_bad_request($c, message => 'é necessário o parâmetro de entrada locus' );
        return;
    }
    my ($locus_name, $locus_symbol, $locus_id) = split (/\|/ ,$locus_input);
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema', undef, $sp_person_id);
    my $locus = $phenome_schema
        ->resultset('Locus')
        ->find({ locus_id => $locus_id, {} } );
    if (!$locus) {
        $c->stash->{rest} = { error => "nenhum locus encontrado para o ID '$locus_id' " };
        return;
    }
    my $locusgroup = $phenome_schema->resultset("Locusgroup")->find({locusgroup_id => $locusgroup_id } ) ;
    if (!$c->user) {
        $c->stash->{rest} = { error => 'Você precisa estar conectado para associar loci! ' };
        return;
    }
    if ( any { $_ eq 'curator' || $_ eq 'submitter' || $_ eq 'sequencer' } $c->user->roles() ) {
        # if this fails, it will throw an acception and will (probably rightly) be counted as a server error
        my $user_id = $c->user->get_object->get_sp_person_id;
        if ($locusgroup && $locus_id) {
            try {
                my $locusgroup_member = $phenome_schema->resultset("LocusgroupMember")->find_or_create( {
                    locusgroup_id => $locusgroup_id,
                    locus_id      => $locus_id,
                    sp_person_id  => $user_id,
                    evidence_id   => $evidence_id,
                    reference_id  => $reference_id,
                                                                                                        });
                $c->stash->{rest} = ['success'];
                # need to update the loci div!!
                return;
            } catch {
                $c->stash->{rest} = { error => "Falha: $_" };
                return;
            };
        } else {
            $c->stash->{rest} = { error => 'são necessários locusgroup_id e locus_id válidos para adicionar o membro ao locusgroup! ' };
        }
    } else {
        $c->stash->{rest} = { error => 'Sem privilégios para adicionar um novo locus ao locusgroup. Você precisa ter uma conta de submissor no SGN. Entre em contato com sgn-feedback@solgenomics.net para atualizar sua conta de usuário. ' };
    }
}


1;

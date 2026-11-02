use utf8;
#DEPRECATED
#####################
#This page now points to the url /solpeople/profile/<sp_person_id> in the controller SGN::Controller::People
#####################

use strict;

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Login;
use CXGN::People;
use CXGN::People::Person;
use CXGN::BlastWatch;
use CXGN::Phenome::Locus;
use CXGN::Cview::MapFactory;
use CXGN::Page::FormattingHelpers qw/info_section_html page_title_html
  info_table_html simple_selectbox_html
  html_optional_show columnar_table_html/;

our $c;
use CatalystX::GlobalContext qw($c);


my $page = CXGN::Page->new( "solpeople main menu", "john" );
my $dbh = CXGN::DB::Connection->new();
my $site_name = $c->config->{project_name};

my $sp_person_id = CXGN::Login->new($dbh)->verify_session();

my $sp = CXGN::People::Person->new( $dbh, $sp_person_id );
unless ($sp_person_id) {
    $page->error_page( "ID de login não encontrado.",
        "", "", "Login ID not found: $sp_person_id" );
}
unless ( $sp->get_username() ) {
    $page->error_page( "Nome de usuário não encontrado.",
        "", "", "Username not found for sp_person_id '$sp_person_id'" );
}
my $username = $sp->get_first_name() . " " . $sp->get_last_name();

#my $research_update=$sp->get_research_update();
#my $contact_update=$sp->get_contact_update();

$page->add_style( text => <<EOS);
div#queryTable
{
margin: 0px 0px 0px 0px;
display: none;
}
EOS
$page->header();

print <<END_HTML;

<script type = "text/javascript">
<!--
    function toggleLayer(whichLayer) {
	if (document.getElementById) {
	    var style2 = document.getElementById(whichLayer).style; 
	    style2.display = style2.display? "":"block";
	}
	else if (document.all) {
	    var style2 = document.all[whichLayer].style;
	    style2.display = style2.display? "":"block";
	}
	else if (document.layers) {
	    var style2 = document.layers[whichLayer].style;
	    style2.display = style2.display? "":"block";
	}
    }
    function showSequence(sequence) {
	document.getElementById("Heading").innerHTML="<strong>Full sequence: </strong>";
	document.getElementById("fullSequence").innerHTML=sequence;
    }
    function hideSequence() {
	document.getElementById("Heading").innerHTML="";
	document.getElementById("fullSequence").innerHTML="";
    }
//-->
</script>
END_HTML

print page_title_html("Meu $site_name");
print qq|<div align="center">Bem-vindo <b>$username</b></div>\n|;
print
qq|<div align="right" style="margin-bottom: 0.5em">Not $username? <a href="login.pl?logout=yes">[log out]</a></div>\n|;
print info_section_html( title => 'Ferramentas gerais', contents => <<EOHTML);
    <a href="personal-info.pl?action=edit&sp_person_id=$sp_person_id">Visualizar ou atualizar informações pessoais de contato e pesquisa</a><br />
    <a href="change-account.pl?action=edit&sp_person_id=$sp_person_id">Atualizar informações da conta</a><br />
    <a href="/forum/topics.pl">Post to SGN forum</a><br />
EOHTML

# my $queries =
#     qq|<div id="queryTable">|
#   . CXGN::BlastWatch::get_queries( $dbh, $sp_person_id )
#   . '</div>';
# print info_section_html( title => 'BLAST Watch', contents => <<EOHTML);
#     <div style="margin-bottom: 1em">O BLAST Watch permite enviar consultas recorrentes ao SGN. A busca BLAST é repetida semanalmente e você recebe um e-mail se os resultados mudarem.</div>
#     <a href="/tools/blast/watch/index.pl">Enviar consulta ao BLAST Watch do SGN</a><br />
#     <a href="javascript:toggleLayer('queryTable');" title="Visualizar suas consultas do BLAST Watch">Visualizar suas consultas do BLAST Watch</a>
#     $queries
# EOHTML

#return 1 if the first term is eq to one of the other terms given
sub in(@) {
    my $t = shift;
    ( grep { $t eq $_ } @_ ) ? 1 : 0;
}

#now assemble the sequencing tools stuff
if ( in( $sp->get_user_type, qw/curator sequencer/ ) ) {

    #make a form for uploading TPF and AGP files
    my $tpf_agp_upload = do {
        if ( $sp->get_user_type eq 'curator' ) {
            tpf_agp_upload_forms(<<EOHTML);
      <!-- the string 'TYPE' will be replaced in each instance by tpf_agp_upload_forms() -->
<label for="chrnuminputTYPE">Para o cromossomo #: </label><input id="chrnuminputTYPE" name="chr" type="text" size="2" maxlength="2" />
EOHTML
        }
        elsif ( $sp->get_user_type eq 'sequencer'
            and my @projects =
            grep { $_ >= 1 && $_ <= 12 }
            $sp->get_projects_associated_with_person )
        {
            my $chrinput =
              @projects > 1
              ? simple_selectbox_html(
                name    => 'chr',
                choices => \@projects,
                label   => 'Para o cromossomo #:',
              )
              : qq|For Chromosome #: <b>$projects[0]</b> <input type="hidden" value="$projects[0]" name="chr" />|;
            tpf_agp_upload_forms($chrinput);
        }
    };

    print info_section_html( title => 'Ferramentas de sequenciamento', contents => <<EOHTML);
<a href="attribute_bacs.pl">Atribuir um BAC ao seu projeto de sequenciamento de cromossomo</a><br />
<a href="/maps/physical/clone_il_view.pl">Visualizar/atualizar o mapeamento de IL de BACs (lista)</a><br />
<div style="vertical-align: middle; font-weight: bold"><a href="/maps/physical/clone_reg.pl">Visualizar/atualizar todos os registros de BACs (lista) <img style="border: none" src="/documents/img/new.gif" /></a></div>
<a href="/sequencing/tpf.pl">Visualizar arquivos TPF</a><br />
<a href="/sequencing/agp.pl">Visualizar arquivos AGP</a><br />
$tpf_agp_upload
EOHTML
}

# if( in( $sp->get_user_type(), qw/submitter curator/ ) )
# {
#   print info_section_html(title => 'Páginas de envio de ESTs', contents => <<EOHTML);
# <a href="/data-submit/top-level.pl">Página inicial de envio de dados</a>
# EOHTML
# }

if ( in( $sp->get_user_type(), qw/submitter curator/ ) ) {
    print info_section_html( title => 'Envio de dados de QTL',
        contents => <<EOHTML);
<a href="/phenome/qtl_form.pl">Enviar e analisar seus dados de QTL</a>
EOHTML
}

my @pops = CXGN::Phenome::Population->my_populations($sp_person_id);

if (@pops) {
    my $pop_list = my_populations(@pops);
    print info_section_html( title => 'Populações', contents => $pop_list );
}

#### solGS submitted jobs list ##########
my $solgs_jobs = SGN::Controller::solGS::AnalysisQueue->solgs_analysis_status_log($c);

my $solgs_jobs_table;

if(@$solgs_jobs) {
    $solgs_jobs_table =  columnar_table_html(
	headings   => [ 'Analysis name', 'Submitted on', 'Status', 'Result page'],
	data       => $solgs_jobs,
	__alt_freq => 2,
	__align    => 'llll',
	);
} else {
    $solgs_jobs_table = 'You have no submitted jobs.'
}

print info_section_html( 
    title    => 'Tarefas de análise enviadas ao solGS',
    contents => $solgs_jobs_table 
    );

#######


if ( $sp->get_user_type() eq 'curator' ) {
    print info_section_html( title => 'Ferramentas de curadoria', contents => <<EOHTML);
<a href="/solpeople/admin/crash_test.pl">Testar o tratamento de erros do site</a><br />
<a href="/solpeople/admin/stats.pl">Visualizar estatísticas de usuários</a><br />
<a href="/solpeople/admin/quick_create_account.pl">Criar conta de usuário</a><br />
<a href="/solpeople/admin/create_organization.pl">Criar instituição</a>
EOHTML
}

if ( $sp->get_user_type() =~ /curator/i ) {
    my $publications =
qq| <a href= "/search/pub_search.pl">Buscar no banco de publicações do SGN </a><br />|;
    $publications .=
qq| <a href= "/search/pub_search.pl?w9b3_assigned_to=$sp_person_id">Ver as publicações atribuídas a você</a><br />|;
    $publications .=
qq| <a href= "/search/pub_search.pl?w9b3_status=pending">See publications pending curation</a><br />|;
    $publications .=
qq| <a href= "/chado/fetch_pubmed.pl">Carregar novas publicações do PubMed</a><br />|;

    print info_section_html(
        title    => 'Mineração da literatura',
        contents => $publications
    );
}

if ( $sp->get_user_type() =~ /submitter|curator|sequencer/i ) {

    my @loci =
      CXGN::Phenome::Locus::get_locus_ids_by_editor( $dbh, $sp_person_id );
    my $top  = 50;
    my $more = 0;
    my $max  = @loci;
    if ( @loci > 24 ) {
        $more = @loci - 24;
        $max  = 24;
    }

    my $locus_editor_info = qq { None.<br /> };
    if ( @loci > 0 ) {
        $locus_editor_info = "";
    }

    for ( my $i = 0 ; $i < ($max) ; $i++ ) {
        my $locus    = CXGN::Phenome::Locus->new( $dbh, $loci[$i] );
        my $symbol   = $locus->get_locus_symbol();
        my $locus_id = $locus->get_locus_id();

        $locus_editor_info .=
qq { <a href="/phenome/locus_display.pl?locus_id=$locus_id&amp;action=view">$symbol</a> };
    }
    if ($more) {
        $locus_editor_info .=
qq|<br><b>e <a href="/search/locus/>$more more</a></b><br />|;
    }

    print info_section_html(
        title    => 'Loci com permissão de edição',
        contents => $locus_editor_info
    );

    my @annotated_loci =
      CXGN::Phenome::Locus::get_locus_ids_by_annotator( $dbh, $sp_person_id );

    my $more = 0;
    my $max  = @annotated_loci;
    if ( @annotated_loci > 24 ) {
        $more = @annotated_loci - 24;
        $max  = 24;
    }

    my ( $locus_annotations, $more_annotations );

    for ( my $i = 0 ; $i < $top ; $i++ ) {
        my $locus    = CXGN::Phenome::Locus->new( $dbh, $annotated_loci[$i] );
        my $symbol   = $locus->get_locus_symbol();
        my $locus_id = $locus->get_locus_id();

        if ( $i < $max ) {
            $locus_annotations .=
qq | <a href="/locus/$locus_id/view">$symbol</a> |;
        }
        else {
            $more_annotations .=
qq { <a href="/locus/$locus_id/view">$symbol</a> };
        }
    }

    if ($more) {
        $locus_annotations .= " and $more more, not shown.<br />";

        $locus_annotations .=
          html_optional_show( 'locus_annotations', 'Show more',
            qq|<div class="minorbox">$more_annotations</div> |,
          );
    }

    $locus_annotations .=
qq| <a href="../phenome/recent_annotated_loci.pl">[Visualizar loci anotados por data]</a> |;
    print info_section_html(
        title    => 'Loci anotados',
        contents => $locus_annotations
    );

    my $map_factory = CXGN::Cview::MapFactory->new($dbh);
    my @user_maps   = $map_factory->get_user_maps();
    my $html        = "";

    if ( @user_maps > 0 ) {
        $html .=
"<table alt=\"\" ><tr><td><i>Nome</i></td><td></td><td></td><td><i>status</i></td></tr>";
        foreach my $um (@user_maps) {
            my $public = " (not public) ";
            if ( $um->get_map()->get_is_public() ) { $public = "(public)"; }
            $html .=
                "<tr><td><b>"
              . $um->get_short_name()
              . "</b></td><td> <a href=\"/cview/umap.pl?action=view&amp;user_map_id="
              . $um->get_id()
              . "\" >[visualizar]</a></td><td><a href=\"/cview/umap.pl?action=edit&amp;user_map_id="
              . $um->get_id()
              . "\">[configure]</a></td><td>$public</td></tr>";

        }
        $html .= "</table>";
    }

    # BROKEN!
    #    print info_section_html(title => 'Mapas do usuário', contents=> <<EOHTML);
    #    <a href="/cview/upload_usermap.pl">Enviar novo mapa de usuário</a><br />
    #	<br />
    #	$html
    #EOHTML

}

my $user_type = $sp->get_user_type();
my $user_info = {
    user => qq{ Your current user status is <b>$user_type</b>. Entre em contato com <a href="mailto:sgn-feedback\@sgn.cornell.edu">SGN</a> to upgrade to a <b>submitter</b> account with more privileges. Submitters can upload user maps, EST data, and become locus editors. },

    submitter => qq{ Your current user status is <b>$user_type</b>. Você tem o nível máximo de permissão no SGN. Entre em contato com <a href="mailto:sgn-feedback\@sgn.cornell.edu">SGN</a> if you would like to change your user status.},

    curator => qq{ Your current user status is <b>$user_type</b>. },

    sequencer => qq{ Your current user status is <b>$user_type</b>. You have maximum user privileges on SGN. },

    genefamily_editor => qq{ Your current user status is <b>$user_type</b>. },
};

print info_section_html( title => 'Status do usuário',
    contents => $user_info->{$user_type} );

$page->footer();

#returns a string containing a TPF and an AGP upload form,
#with the single argument interpolated in
sub tpf_agp_upload_forms {
    my $chrinput = shift;
    my ( $chrinput_agp, $chrinput_tpf ) = ( $chrinput, $chrinput );
    $chrinput_agp =~ s/TYPE/_agp/g;
    $chrinput_tpf =~ s/TYPE/_tpf/g;
    return <<EOHTML;
<div style="margin-top: 1em">
  <b>Enviar arquivo Accessioned Golden Path (AGP)</b><br />
  <form action="/sequencing/agp.pl" method="post" enctype="multipart/form-data">
    $chrinput_agp
    <input type="hidden" name="filetype" value="agp" />
    <label for="agpinput">Arquivo: </label>
    <input id="agpinput" type="file" name="agp_file" value="Upload AGP file" /><button type="submit" value="Submit">Enviar</button>
  </form>
</div>
<div style="margin-top: 1em">
  <b>Enviar arquivo Tiling Path Format (TPF)</b><br />
  <form action="/sequencing/tpf.pl" method="post" enctype="multipart/form-data">
    $chrinput_tpf
    <input type="hidden" name="filetype" value="tpf" />
    <label for="tpfinput">Arquivo: </label>
    <input id="tpfinput" type="file" name="tpf_file" value="Upload TPF file" /><button type="submit" value="Submit">Enviar</button>
  </form>
</div>
EOHTML
}

sub my_populations {
    my @pops = @_;
    my $pops_list;

    foreach my $pop (@pops) {
        my $pop_name  = $pop->get_name();
        my $pop_id    = $pop->get_population_id();
        my $is_public = $pop->get_privacy_status();
        if ($is_public)    { $is_public = 'is publicly available'; }
        if ( !$is_public ) { $is_public = 'is not publicly available yet'; }
        $pops_list .=
qq |<a href="/qtl/population/$pop_id">$pop_name</a> <i>($is_public)</i><br/>|;
    }

    return $pops_list;
}

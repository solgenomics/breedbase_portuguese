use utf8;

package CXGN::Search::CannedForms;
use Modern::Perl;

use CXGN::DB::Connection;
use CXGN::Genomic::Search::Clone;
use CXGN::Searches::People;
use CXGN::Searches::Library;
use CXGN::Searches::Images;
use CXGN::Searches::Family;
use CXGN::Unigene::Search;
use CXGN::Phenome;
use CXGN::Publication;
use CXGN::Chado::Cvterm;
use CXGN::Searches::GemTemplate;
use CXGN::Searches::GemExperiment;
use CXGN::Searches::GemPlatform;
use CXGN::Page::FormattingHelpers
  qw/blue_section_html info_table_html simple_selectbox_html/;

use List::MoreUtils qw /uniq/;


=head1 NAME

CXGN::Search::CannedForms - contains several functions that spit out
                            HTML forms used for searching on SGN.

=head1 SYNOPSIS

=head1 DESCRIPTION

Each of these functions returns a string containing the HTML for a
search form.

=head1 FUNCTIONS

=cut

####################
## DESCRIPTION
###################
# this module contains functions to output various
# search forms that are used on more than one page.
# For example, the marker_search_form
# is used in both /search/direct_search.pl
# and in /search/markers/markersearch.pl

###############################
##   SEARCH FORM FUNCTIONS   ##
###############################


=head2 expr_template_search_form

  Desc: canned html for the SGN expr_template search form
  Args: CXGN::Page object
  Ret : string of HTML that will make an expr_template search form

=cut

sub expr_template_search_form {
    my $page = shift;
    my $q    = shift;
    $q ||= CXGN::Searches::GemTemplate->new()->new_query();

    return <<EOH
  <table class="search_form_title"><tr><td>
    <span class="search_form_title">Busca de expressão por molde</span>
  </td>
  </tr>
  </table>

<form action="/search/gem_template_search.pl" method="get">
  <div class="indentedcontent">
EOH
      . $q->to_html() . <<EOH;
  </div>
</form>
EOH

}

=head2 expr_experiment_search_form

  Desc: canned html for the SGN expr_experiment search form
  Args: CXGN::Page object
  Ret : string of HTML that will make an expr_experiment search form

=cut

sub expr_experiment_search_form {
    my $page = shift;
    my $q    = shift;
    $q ||= CXGN::Searches::GemExperiment->new()->new_query();

    return <<EOH
  <table class="search_form_title"><tr><td>
    <span class="search_form_title">Busca de expressão por experimento</span>
  </td>
  </tr>
  </table>

<form action="/search/gem_experiment_search.pl" method="get">
  <div class="indentedcontent">
EOH
      . $q->to_html() . <<EOH;
  </div>
</form>
EOH

}

=head2 expr_platform_search_form

  Desc: canned html for the SGN expr_platform search form
  Args: CXGN::Page object
  Ret : string of HTML that will make an expr_platform search form

=cut

sub expr_platform_search_form {
    my $page = shift;
    my $q    = shift;
    $q ||= CXGN::Searches::GemPlatform->new()->new_query();

    return <<EOH
  <table class="search_form_title"><tr><td>
    <span class="search_form_title">Busca de expressão por plataforma</span>
  </td>
  </tr>
  </table>

<form action="/search/gem_platform_search.pl" method="get">
  <div class="indentedcontent">
EOH
      . $q->to_html() . <<EOH;
  </div>
</form>
EOH

}


=head2 image_search_form
  ### DEPRECATED CGIBIN CODE

  Desc: canned html for the SGN image search form
  Args: CXGN::Page object
  Ret : string of HTML that will make an image search form

=cut

sub image_search_form {
    my $page = shift;
    my $q    = shift;
    $q ||= CXGN::Searches::Images->new()->new_query();

    return <<EOH
  <table class="search_form_title"><tr><td>
    <span class="search_form_title">Busca de imagens</span>
  </td>
  </tr>
  </table>

<form action="/search/image_search.pl" method="get">
  <div class="indentedcontent">
EOH
      . $q->to_html() . <<EOH;
  </div>
</form>
EOH
}

=head2 people_search_form

  Desc: canned html for the SGN people search form
  Args: CXGN::Page object
  Ret : string of HTML that will make a people search form

=cut

sub people_search_form {
    my $page = shift;
    my $q    = shift;
    $q ||= CXGN::Searches::People->new()->new_query();

    return <<EOH
  <table class="search_form_title"><tr><td>
    <span class="search_form_title">Busca no diretório</span>
  </td>
  </tr>
  </table>

<form action="/solpeople/people_search.pl" method="get">
  <div class="indentedcontent">
EOH
      . $q->to_html() . <<EOH;
  </div>
</form>
EOH
}

=head2 family_search_form

 Search for Families

=cut

sub family_search_form {
    my $page = shift;
    my $q    = shift;
    $q ||= CXGN::Searches::Family->new()->new_query();
    return <<HTML
  <table class="search_form_title"><tr><td>
    <span class="search_form_title">Busca de famílias</span>
  </td>
  </tr>
  </table>

	<form action="/search/family_search.pl" method="get">
		<div class="indentedcontent">
HTML
      . $q->to_html . <<HTML
		</div>
	</form>
HTML

}

=head2 library_search_form

  Desc: canned html for the EST library search form
  Args: CXGN::Page object
  Ret : string of HTML that will make a library search form

=cut

sub library_search_form {
    my $page = shift;
    my $q    = shift;
    $q ||= CXGN::Searches::Library->new()->new_query();

    return <<EOH
  <table class="search_form_title"><tr><td>
    <span class="search_form_title">Busca de bibliotecas</span>
  </td>
  </tr>
  </table>

<form action="/search/library_search.pl" method="get">
  <div class="indentedcontent">
EOH
      . $q->to_html() . <<EOH;
  </div>
</form>
EOH
}

=head2 est_search_form

  Desc: canned html for the EST search form
  Args: CXGN::Page object
  Ret : string of HTML that will make an EST search form

=cut

sub est_search_form {
    my $page = shift;

#commented bits are for after the EST search gets moved to the search framework -- Evan
#	my $q = shift;
#  $q ||=  CXGN::Search::EST->new()->new_query();

    return <<EOH

  <table class="search_form_title" summary=""><tr><td>
    <span class="search_form_title">Busca de ESTs</span>
  </td><td align="right">
    <a class="search_form_random" href="/search/est.pl?random=yes">
    Selecionar uma sequência EST ao acaso
    </a>
  </td></tr></table>

<form action="/search/est.pl" method="get">
  <div class="indentedcontent">
EOH

      #    .$q->to_html()
      . <<EOH
  <input type="hidden" name="request_from" value="0" />
  <table summary="" align="center" width="75%" cellspacing="1" cellpadding="1" border="0">
  <tr>
    <td colspan="3" align="right">

      <table summary="" cellpadding="0" cellspacing="0"><tr>
        <td>Identificador EST</td>
        <td><input class="form-control" name="request_id" type="text" style="background: #EEEEFF;" size="20" /></td>
	<td style="padding: 1em">Informe o identificador da sequência e selecione o tipo de identificador ou a opção automática.</td>
      </tr></table>
    </td>
  </tr>
  <tr><td colspan="2"><i>Tipo de identificador</i></td><td><i>Exemplo</i></td></tr>
<!--
  <tr>
Automatic guessing of the input's intensional type didn't work too well.
    <td><input type="radio" name="request_type" checked="checked" value="automatic" /></td>
    <td>Auto</td>
    <td>&nbsp;</td>
  </tr>
-->
  <tr>
    <td><input type="radio" name="request_type" value="7" checked="checked" /></td>
    <td>Identificador EST da SGN (SGN-E#)</td>
    <td>SGN-E143721</td>
  </tr>
  <tr>
    <td><input type="radio" name="request_type" value="8" /></td>
    <td>Identificador de clone de cDNA da SGN (SGN-C#)</td>
    <td>SGN-C157205</td>
  </tr>
  <tr>
    <td><input type="radio" name="request_type" value="9" /></td>
    <td>Identificador de cromatograma da SGN (SGN-T#)</td>
    <td>SGN-T123401</td>
  </tr>
  <tr>
    <td><input type="radio" name="request_type" value="14" /></td>
    <td>Identificador de ponto de microarranjo SGN/TMD/CGEP</td>
    <td>1-1-1.1.1.2</td>
  </tr>
  <tr>
    <td><input type="radio" name="request_type" value="10" /></td>
    <td>Nome do clone de cDNA (biblioteca/placa/poço)</td>
    <td>cLED-1-A1</td>
  </tr>
  <tr>
    <td><input type="radio" name="request_type" value="11" /></td>
    <td>Identificador do centro de sequenciamento</td>
    <td>&nbsp;</td>
  </tr>
  <tr>
    <td colspan="3">&nbsp;</td>
  </tr>
  <tr>
    <td colspan="2" align="center"><button class="btn btn-primary" type="submit" value="Search" name="search">Buscar</button></td>
    <td>&nbsp;</td>
  </tr>
  </table>

  <p><b>Dica:</b> Use a opção automática se o tipo do identificador não estiver listado. Identificadores do GenBank (gi#), números de acesso e números dbEST podem ser usados dessa forma. A SGN pode retornar versões de sequências EST mais recentes que as registradas no GenBank.</p>
EOH
      . <<EOH;
  </div>
</form>
EOH
}

=head2 clone_search_form

  Desc: canned html for the SGN genomic clone search form
  Args: none
  Ret : string of HTML that will make a clone search form

=cut

sub clone_search_form {
    my $page = shift;    #pointer to our page
    my $q    = shift;

    $q ||= CXGN::Genomic::Search::Clone->new->new_query;

    return <<EOH
  <table class="search_form_title" summary=""><tr><td>
    <span class="search_form_title">Busca de clones genômicos</span>
  </td><td align="right">
    <a class="search_form_random" href="/maps/physical/clone_info.pl?random=yes">
    Select a genomic clone at random
    </a>
  </td></tr></table>

<form action="/maps/physical/clone_search.pl" method="get">
  <div class="indentedcontent">
EOH
      . $q->to_html . <<EOH;
    <h3>Links relacionados:</h3>
    <ul>
    <li><a href="/maps/physical/list_bacs_by_plate.pl">Consultar BACs por placa de overgo</a></li>
    <li><a href="/cview/map.pl?map_id=1&amp;physical=1">Sobre o mapeamento físico</a></li>
    <li><a href="/maps/physical/overgo_stats.pl">Projeto overgo</a></li>
    <li><a href="/maps/physical/overgo_process_explained.pl">Processo de distribuição de overgos em placas</a></li>
    <li><a href="http://www.genome.arizona.edu/fpc/tomato/">Mapa FPC de tomate no AGI</a></li>
    <li><a href="/supplement/plantcell-14-1441/bac_annotation.pl">Anotação antiga (2000) de BACs do cromossomo 6 de tomate</a></li>
    <li><a href="/solanaceae-project/seed_bac_selection.pl">Orientações para selecionar BACs iniciais</a></li>
    </ul>
  </div>
</form>
EOH
}

=head2 unigene_search_form

  Desc: returns the unigene search form
  Args: CXGN::Page object
  Ret : string of HTML

=cut

sub unigene_search_form {
    my $page = shift;
    my $q    = shift;

    $q ||= CXGN::Unigene::Search->new->new_query;

    return <<EOH
  <table class="search_form_title" summary=""><tr><td>
    <span class="search_form_title">Busca de unigenes</span>
  </td><td align="right">
    <a class="search_form_random" href="/search/unigene.pl?random=yes">
    Select a unigene at random
    </a>
  </td></tr></table>
<form action="/search/ug-ad2.pl" method="get">
  <div class="indentedcontent">
EOH
      . $q->to_html . <<EOH
  </div>
</form>
<hr />
<span style="margin-top: 1em" class="search_form_title">TIGR TC</span>
<div class="indentedcontent">
  See <a href="/tools/convert/input.pl">Conversão entre unigenes da SGN e sequências TC do TGI</a>.
</div>
EOH
}

sub annotation_search_form {
    my $page = shift;
    my $q    = shift;

    return <<EOH;
  <table class="search_form_title" summary=""><tr><td>
    <span class="search_form_title">Busca de anotações</span>
  </td><td align="right">
<!-- what good would selecting a random annotation be? -->
  </td></tr></table>

Busca de texto completo nas anotações de unigenes, automáticas (BLAST) ou com curadoria manual.
<br /><br />

<form name="annotation_search" method="get" action="/search/annotation_search_result.pl">
<input type="hidden" name="request_from" value="0" />
<div align="center">
  <table summary=""><tr><td>
  <input name="search_text" type="text" size="50" /><button name="submit" type="submit" value="Search">Buscar</button><br />
  <input name="search_type" value="blast_search" type="radio" checked="checked" />Busca&nbsp;automática&nbsp;&nbsp;<input name="search_type" type="radio" value="manual_search" checked="checked" />Busca&nbsp;manual
  </td></tr></table>
</div>
</form>
EOH

}

=head2 gene_search_form

  Desc: returns the gene search form
  Args: CXGN::Page object
  Ret : string of HTML

=cut

sub gene_search_form {

    my $page = shift;
    my $q    = shift;

    $q ||= CXGN::Phenome->new->new_query;

    my $form = $q->to_html;

    #  my $quick_form = $q->to_quick_html;

    return <<EOHTML;

<table class="search_form_title" summary=""><tr><td>
    <h4><span class="search_form_title">Busca de genes</span></h4>
  </td>
  </tr></table>


<form  action= "/search/locus_search.pl" method="get">
$form<br/>

</form>


EOHTML

}


=head2 publication_search_form

  Desc: returns the publication search form
  Args: CXGN::Page object
  Ret : string of HTML

=cut

sub publication_search_form {

    my $page = shift;
    my $q    = shift;

    $q ||= CXGN::Publication->new->new_query;

    my $form = $q->to_html;

    return <<EOHTML;

<table class="search_form_title" summary=""><tr><td>
    
  </td>
  </tr></table>


<form  action= "/search/pub_search.pl" method="get">
$form<br/>

</form>


EOHTML

}



=head1 AUTHORS

  Robert Buels and Beth Skwarecki

=cut

package CXGN::Search::CannedForms::MarkerSearch;
use base qw( CXGN::Page::WebForm );

use Modern::Perl;
use CXGN::Page::FormattingHelpers qw(blue_section_html);
use Tie::Function;
use CXGN::DB::Connection;

sub new {
    my ( $class, $dbh ) = @_;
    my $self = $class->SUPER::new();
    $self->{dbh} = $dbh;
    return $self;
}

sub to_html {

    my ($self) = @_;

    tie my %species, 'Tie::Function', sub { $self->species_select(shift) };

    tie my %protocols, 'Tie::Function', sub { $self->protocol_select(shift) };

    tie my %chromos, 'Tie::Function', sub { $self->chromo_select(shift) };

    tie my %confs, 'Tie::Function', sub { $self->confidence_select(shift) };

    tie my %maps, 'Tie::Function', sub { $self->map_select(shift) };

    tie my %colls, 'Tie::Function', sub { $self->collection_select(shift) };

    tie my %textbox, 'Tie::Function', sub { $self->textbox(@_) };

    tie my %checkbox, 'Tie::Function', sub { $self->checkbox(@_) };

    tie my %nametype, 'Tie::Function', sub { $self->nametype(shift) };

    tie my %uniq, 'Tie::Function', sub { $self->uniqify_name(@_) };

    my $retstring = <<EOHTML;

<div class="container-fluid">

  <div class="row well">
    <div class="col-sm-2">
    </div>
    <div class="col-sm-8">
      <div class="form-horizontal" >
        <div class="form-group">
          <label class="col-sm-3 control-label">Nome do marcador ou SGN-M \#: </label>
          <div class="col-sm-9" >
            <div class="row">
              <div class="col-sm-5">
	        $nametype{asdf}
              </div>
	      <div class="col-sm-7">
	        $textbox{marker_name}
              </div>
            </div>
          </div>
        </div>
        <div class="form-group">
          <label class="col-sm-3 control-label"></label>
	  <div class="col-sm-9" >
	    <button class="btn btn-primary" type="submit" name="$uniq{submit}" value="Search">Buscar</button>&nbsp;&nbsp;&nbsp;&nbsp;
            $checkbox{'mapped','checked'}
            <span class="help" title="Marcadores não mapeados incluem candidatos ainda não mapeados e levantamentos de polimorfismo.">Buscar apenas marcadores em <a href=/cview>mapas</a></span>
	  </div>
	</div>
      </div>
    </div>
    <div class="col-sm-2">
    </div>
  </div>

  <h3 style="margin-bottom: 0; padding-bottom: 0;margin-top: 30px;">Opções avançadas de busca</h3>
  <div ><small>(Dúvidas? Consulte a <a href="/help/marker_search_help.pl">página de ajuda</a>)</small></div>
  <br/>
  <div class="row well">
    <div class="col-sm-6">

EOHTML

    $retstring .= blue_section_html( 'Opções de marcadores', '<a style="font-size: 75%" href="/search/markers/markersearch.pl?random=yes">
    [Selecionar um marcador ao acaso]</a>', <<EOFOO);

    $checkbox{bac_assoc}
    Exibir apenas marcadores associados a BACs<br />
      <div style="margin-left: 20px;">
        $checkbox{overgo_assoc}
        <span class="help" title="O processo overgo associa BACs a determinados marcadores dos mapas de tomate da SGN.">Associações por overgo<small> <a href="/maps/physical/overgo_process_explained.pl">[Sobre o processo overgo]</a></small></span><br />

        $checkbox{manual_assoc}
        <span class="help" title="Alguns marcadores foram associados manualmente a BACs.">Associações manuais</span><br />

        $checkbox{comp_assoc}
        <span class="help" title="Alguns marcadores foram comparados por BLAST com nossa coleção de BACs.">Associações computacionais</span><br />

      </div>
      <br />

      <div class="form-horizontal" >
	<div class="form-group">
          <label class="col-sm-6 control-label">Exibir marcadores da espécie: </label>
      	  <div class="col-sm-6" >
	    $species{yeah}
          </div>
	</div>
	<div class="form-group">
          <label class="col-sm-6 control-label"><span class="help" title="Definições dos protocolos: AFLP - polimorfismos de comprimento de fragmentos amplificados. CAPS - polimorfismos amplificados e clivados. PCR - qualquer método baseado em PCR não especificado. RFLP - polimorfismo de comprimento de fragmentos de restrição. SSR - repetições de sequências curtas (microssatélites)">Exibir marcadores do protocolo: </span></label>
      	  <div class="col-sm-6" >
	    $protocols{'yeah'}
          </div>
	</div>
	<div class="form-group">
	  <label class="col-sm-6 control-label"><span class="help" title="Coleções: COS - sequências ortólogas conservadas (tomate e Arabidopsis). COSII - sequências ortólogas conservadas II (várias espécies de asterídeas). KFG - genes de função conhecida">Exibir marcadores do grupo: </span></label>
          <div class="col-sm-6" >
	    $colls{'yeah'}
	  </div>
	</div>
      </div>
    </div>

EOFOO

    $retstring .= <<EOHTML;
    <div class="col-sm-6">

EOHTML

    $retstring .= blue_section_html( 'Localizações de mapas/marcadores', <<EOHTML);

      <div class="form-horizontal" >
	<div class="form-group">
          <label class="col-sm-6 control-label">Exibir apenas marcadores dos cromossomos: </label>
      	  <div class="col-sm-6" >
	    $chromos{yeah}
          </div>
	</div>
	<div class="form-group">
          <label class="col-sm-6 control-label">Posição inicial: </label>
      	  <div class="col-sm-6" >
	     $textbox{'pos_start',3}
          </div>
	  <label class="col-sm-6 control-label">Posição final: </label>
	  <div class="col-sm-6">
	     $textbox{'pos_end', 3}
	  </div>
	</div>
	<div class="form-group">
	  <label class="col-sm-6 control-label"><span class="help" title="Mapas gerados com MapMaker têm valores de confiança associados às posições. Mantenha a opção de confiança não calculada para exibir todos os marcadores de todos os mapas.">Confiança mínima: </span></label>
          <div class="col-sm-6" >
             $confs{yeah}
          </div>
	</div>
	<div class="form-group">
          <label class="col-sm-6 control-label">Nos mapas: </label>
      	  <div class="col-sm-6" >
	     $maps{yeah}
          </div>
	</div>
      </div>

EOHTML

    $retstring .= <<EOHTML;
    </div>
    <center><button class="btn btn-primary" type="submit" name="$uniq{submit}" value="Search">Buscar</button></center>
  </div>
</div>
EOHTML

    return $retstring;

}

sub checkbox {

    my ( $self, $what, $checked_by_default ) = @_;

    my $name       = $self->uniqify_name($what);
    my $val        = $self->data($what);
    my $checked    = '';
    my $ifnosubmit = 0;

    $ifnosubmit = 1
      if ( !$self->data('submit') || $self->data('submit') ne 'Search' );

    $checked = 'checked="checked"'
      if ( ( $val && $val eq 'on' ) or ( $checked_by_default && $ifnosubmit ) );
    return qq{<input type="checkbox" $checked name="$name" />}

}

sub textbox {

    my ( $self, $what, $size ) = @_;

    my $name = $self->uniqify_name($what) || '';
    my $val  = $self->data($what)         || '';

    my $sizeparam = ( defined($size) && $size > 0 ) ? qq{size="$size"} : '';
    return qq{<input class="form-control" type="text" $sizeparam name="$name" value="$val" />};

}

sub pos_start {

    my $self = shift;
    my $name = $self->uniqify_name('pos_start');
    my $val  = $self->data('pos_start');
    return qq{<input type="text" size="3" name="$name" value="$val" />};

}

sub pos_end {

    my $self = shift;
    my $name = $self->uniqify_name('pos_end');
    my $val  = $self->data('pos_end');
    return qq{<input type="text" size="3" name="$name" value="$val" />};

}

sub selectbox {

    my ( $self, $fieldname, $values, $mult ) = @_;

    my @valuelist = $self->data_multiple($fieldname);

    my $anysel = '';
    my @anymatches = grep { $_ eq 'Any' } @valuelist;
    $anysel =
      ( @valuelist == 0 || @anymatches > 0 ) ? 'selected="selected"' : '';

    my $retstring = '';

    if ($mult) {

        $retstring = '<select multiple="multiple" size="3" class="form-control"  name="'
          . $self->uniqify_name($fieldname) . '" >';
        $retstring .= qq{<option value="Any" $anysel>Qualquer um</option>};

    }
    else {
        $retstring = '<select class="form-control" name="' . $self->uniqify_name($fieldname) . '" >';

    }

    my $multiple = $mult ? 'multiple="multiple"' : '';

    if ( ref( $values->[0] ) eq 'ARRAY' ) {

        foreach my $i (@$values) {
            my $sel = '';
            $sel = 'selected="selected"' if grep { $_ eq $i->[0] } @valuelist;
            $retstring .= qq{<option value="$i->[0]" $sel>$i->[1]</option>};
        }

    }
    elsif ( @$values > 0 ) {

        foreach my $i (@$values) {
            my $sel = '';
            $sel = 'selected="selected"' if grep { $_ eq $i } @valuelist;
            $retstring .= qq{<option $sel>$i</option>};
        }

    }
    else {

        warn "no values given to selectbox()\n";
        return;
    }

    $retstring .= '</select>';
    return $retstring;

}

sub selectboxMap {

    my ( $self, $fieldname, $values, $mult ) = @_;
    my @valuelist = $self->data_multiple($fieldname);
    my $anysel = '';
    my $maptype = '';
    my @anymatches = grep { $_ eq 'Any' } @valuelist;
    $anysel =
      ( @valuelist == 0 || @anymatches > 0 ) ? 'selected="selected"' : '';
    my $retstring = '';

    if ($mult) {
        $retstring = '<select multiple="multiple" size="3" class="form-control"  name="'
          . $self->uniqify_name($fieldname) . '" >';
        $retstring .= qq{<option value="Any" $anysel>Qualquer um</option>};
    } else {
        $retstring = '<select class="form-control" name="' . $self->uniqify_name($fieldname) . '" >';
    }

    my $multiple = $mult ? 'multiple="multiple"' : '';
    if ( ref( $values->[0] ) eq 'ARRAY' ) {
        foreach my $i (@$values) {
	    if ($maptype eq '') {
		$retstring .= qq{<optgroup label="$i->[1] -------------------">};
		$maptype = $i->[1];
	    } elsif ($maptype ne $i->[1]) {
		$retstring .= qq{<optgroup label="$i->[1] -------------------">};
		$maptype = $i->[1];
	    }
            my $sel = '';
            $sel = 'selected="selected"' if grep { $_ eq $i->[0] } @valuelist;
            $retstring .= qq{<option value="$i->[0]" $sel>$i->[2]</option>};
        }
    } elsif ( @$values > 0 ) {
        foreach my $i (@$values) {
	    if ($maptype eq '') {
		$retstring .= qq{<optgroup label="$i --------------------">};
		$maptype = $i;
	    }
            my $sel = '';
            $sel = 'selected="selected"' if grep { $_ eq $i } @valuelist;
            $retstring .= qq{<option $sel>$i</option>};
        }
    } else {
        warn "no values given to selectbox()\n";
        return;
    }
    $retstring .= '</select>';
    return $retstring;
}

sub map_select {

    my ($self) = @_;
    my $mapx0rz =
      $self->{dbh}->selectall_arrayref(
"SELECT map_id, concat(map_type, ' ', units), short_name from map ORDER BY map_type, short_name"
      );
    return $self->selectboxMap( 'maps', $mapx0rz, 'multiple' );

}

sub collection_select {

    my ($self) = @_;

    my $collz =
      $self->{dbh}->selectcol_arrayref(
        "select mc_name from marker_collection ORDER BY mc_name");

    return $self->selectbox( 'colls', $collz, 'multiple' );

}

sub nametype {

    my $self = shift;
    my @namelist = ( ['starts with', 'começa com'], ['exactly', 'exatamente'], ['contains', 'contém'] );

    return $self->selectbox( 'nametype', \@namelist );

}

sub protocol_select {

    my $self = shift;
    my $protolist = $self->{dbh}->selectcol_arrayref("SELECT distinct protocol FROM marker_experiment WHERE protocol <> 'unknown'");

    #push(@$protolist, 'RFLP');

    @$protolist = sort @$protolist;

    return $self->selectbox( 'protos', $protolist, 'multiple' );

}

sub chromo_select {

    my $self = shift;
    my $chromolist =
      $self->{dbh}->selectcol_arrayref(
"SELECT distinct lg_name FROM linkage_group WHERE lg_name !~ '[0-9][a-z]'"
      );

    {
      no warnings 'uninitialized';
      @$chromolist = sort {
                do { $a =~ /(\w+)/; $1 }
            cmp do { $b =~ /(\w+)/; $1 }
      } @$chromolist;
    }

    return $self->selectbox( 'chromos', $chromolist, 'multiple' );

}

sub confidence_select {

    my $self = shift;
    my $conflist =
      $self->{dbh}->selectall_arrayref(
"SELECT confidence_id, confidence_name FROM marker_confidence order by confidence_id "
      );

    #  my %confs = map { $_->[0] => $_->[1] } @$conflist;

    return $self->selectbox( 'confs', $conflist );

}

sub species_select {

    my ($self) = @_;

    my $names =
      $self->{dbh}->selectcol_arrayref(
'select distinct common_name.common_name from common_name inner join organism using(common_name_id) inner join accession using(organism_id) inner join map on(accession.accession_id=map.parent_1 OR accession.accession_id=map.parent_2) ORDER BY common_name.common_name'
      );
    return $self->selectbox( 'species', $names, 'multiple' );

}

1;

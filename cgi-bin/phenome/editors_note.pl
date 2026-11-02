use utf8;
use strict;


use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/info_section_html
                                     page_title_html
				     columnar_table_html
                                     info_table_html
                                     html_optional_show
                                     html_alternate_show
                                     tooltipped_text
                                    /;

my $page = CXGN::Page->new();

 $page->header();

print page_title_html ('Nota aos editores de loci');
my $annotation_link = qq | <a href="http://docs.google.com/View?docid=ddhncntn_0cz2wj6">orientações de anotação</a> |;

print  "<b>Editores de loci</b> são especialistas e geralmente autores de pesquisas sobre o locus. Para se tornar editor de um locus, clique em Solicitar permissão de edição na subseção Detalhes do locus da página correspondente.<br />
<br>&nbsp;<br />
 <b>Editores:</b><br/>

    \t* têm permissão para editar o conteúdo da página do locus.<br />
     \t* podem adicionar dados à página conforme surgem novos conhecimentos sobre o locus. Cada subseção pode ser modificada pelos links de edição/anotação.<br />
    \t* iniciam discussões sobre a precisão dos dados enviados por editores, colaboradores e curadores do SGN.<br />
   \t* podem sugerir à equipe de curadoria melhorias na exibição dos dados, nas ferramentas de anotação e nas subseções.<br />
   \t* podem criar páginas para loci recém-identificados e documentados.<br />
   \t* podem listar as publicações relevantes sobre o locus de interesse.<br />
<br>&nbsp;<br />
 <b>Referência</b> sobre como anotar um locus está disponível aqui: $annotation_link.<br />

<br>&nbsp;<br />
<b>Contato</b> SGN staff by emailing to <a href=mailto:sgn-feedback\@sgn.cornell.edu>sgn-feedback\@sgn.cornell.edu</a> <br />";


$page->footer();

exit();





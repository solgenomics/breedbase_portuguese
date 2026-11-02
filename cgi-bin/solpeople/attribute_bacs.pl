use utf8;
use strict;
use warnings;

use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::Search::CannedForms;

my $dbh = CXGN::DB::Connection->new();
CXGN::Login->new($dbh)->verify_session();
my $page=CXGN::Page->new('Attribute BACs','john');
$page->header('Attribute BACs','How to attribute a BAC to a sequencing project');
print <<END_HTML;
<ol>
<li>Entre pelo link no canto superior direito de qualquer página do SGN.</li>
<li>Na barra de ferramentas, escolha <b>buscar</b>-&gt;<b>BACs</b>, ou use o formulário abaixo.</li>
<li>Digite na caixa de busca o nome do BAC que deseja atribuir ao seu projeto de sequenciamento.</li>
<li>Clique no <b>buscar</b> .</li>
<li>Se o BAC desejado aparecer nos resultados da busca, clique no link correspondente.</li>
<li>Na página de informações do BAC, há um link para atribuí-lo ao seu projeto. É necessário entrar na conta para que o link apareça. Confira a atribuição, pois atribuições incorretas só podem ser removidas manualmente pela equipe do SGN.</li>
</ol>
END_HTML
print CXGN::Search::CannedForms::clone_search_form($page);
$page->footer();

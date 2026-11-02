use utf8;

use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw | page_title_html blue_section_html |;

my $page = CXGN::Page->new();

$page->header();

my $page_title = page_title_html("Banco de dados de loci e fenótipos do SGN");

print <<HTML;

$page_title
<br/>

<iframe src="//www.slideshare.net/slideshow/embed_code/key/rbDItCskr6kq5C" width="595" height="485" frameborder="0" marginwidth="0" marginheight="0" scrolling="no" style="border:1px solid #CCC; border-width:1px; margin-bottom:5px; max-width: 100%;" allowfullscreen> </iframe> <div style="margin-bottom:5px"> <strong> <a href="//www.slideshare.net/nm249/sgn-community-annotation-tutorial" title="Tutorial de anotação comunitária do SGN" target="_blank">Tutorial de anotação comunitária do SGN</a> </strong> de <strong><a href="//www.slideshare.net/nm249" target="_blank">Naama Menda</a></strong> </div>



<br/>
<hr/>

<dt>O que é anotação comunitária?</dt>
<dd>
A anotação comunitária busca envolver a comunidade de pesquisa na inclusão de conhecimentos atualizados em bancos de dados biológicos.<br/>
Um dos principais esforços do SGN é ligar informações fenotípicas de Solanaceae aos genes correspondentes e, em seguida, ao genoma. Como parte desse objetivo, o SGN criou um banco de dados de <a href="/search/direct_search.pl?search=loci">nomes e descritores de loci</a>, e um banco de dados de <a href="/search/direct_search.pl?search=phenotypes">fenótipos de variação natural e induzida</a>. Os dois bancos de dados têm interfaces web que permitem referências cruzadas, associações com modelos gênicos de tomate e informações revisadas pela equipe sobre sequências, literatura, ontologias, redes gênicas e o <a href="http://solcyc.sgn.cornell.edu">banco de dados de vias bioquímicas de Solanaceae</a>. Todas as ferramentas de curadoria estão abertas à anotação comunitária on-line por meio de contas com permissão de envio atribuída pela equipe.<br/><br>
 O banco comunitário contém 5.548 acessos fenotipados e 5.739 loci revisados. Mais de 300 loci foram enviados ou anotados por mais de 70 colaboradores ativos, formando um banco mantido pela comunidade.
</dd>

<dt>How do I begin annotating my favorite gene?</dt>
<ul>
<li> <b><a href= "/search/direct_search.pl?search=loci">Busque o locus</a></b>. Você pode obter <b>editor privileges</b> para qualquer locus do banco de dados.<br/> Para obter permissão de edição, clique em Solicitar permissão de edição em qualquer página de locus, ao lado do nome do editor, ou <a href="mailto:sgn-feedback.sgn.cornell.edu">envie um e-mail</a> e um curador do SGN criará uma conta para você.</li>

<li><b> Enviar um novo locus</b>. Seu locus de interesse de Solanaceae não foi encontrado no SGN? Convidamos você a <b>enviar</b> informações sobre loci genéticos de Solanaceae e espécies relacionadas <a href="/locus/0/view">here</a> (observe que uma <a href="/solpeople/new-account.pl">conta do SGN</a> é necessária para todos os envios). Para conjuntos grandes de dados, <a href="mailto:sgn-feedback.sgn.cornell.edu">entre em contato com o SGN</a>
</li>
</ul>
<br/>

<dd><img src="/documents/img/locus_edit.jpg" border="1"  width="80%" ></dd>

<br/>

<dt>Posso enviar informações sem ser editor do locus?</dt>
<ul>
<li>Você deseja <b>enviar informações relacionadas</b> como publicações ou sequências, sem ser editor do locus?<br>
Basta entrar com sua conta de responsável pelo envio. <a href="/solpeople/new-account.pl">conta do SGN</a> podem ser criadas facilmente, mas o envio de informações exige uma breve validação. Por favor, <a href="mailto:sgn-feedback.sgn.cornell.edu">envie um e-mail ao SGN</a> para obter permissão de acesso aos recursos de anotação comunitária.
</li>
</ul>
<br/>

<dd><img src="/documents/img/seq_submit.jpg" border="1"  width="80%"></dd>

<br/>

<dt>Posso publicar dados sem permissão de envio no SGN?</dt>
<ul>
<li>A qualquer momento, você pode enviar <b>comentários</b> a qualquer página de locus ou fenótipo. Basta entrar com sua conta do SGN. Os comentários aparecem no final de cada página.
</li>

</ul>


<br/>
<hr>
<br/>

<a name="phenotype"></a>
<dt>O banco de fenótipos do SGN também é mantido pela comunidade!</dt>
<dd>O SGN mantém uma coleção de milhares de <a href="../search/direct_search.pl?search=phenotypes">acessos fenotipados</a>, de várias populações de mapeamento e mutantes. Os fenótipos são vinculados a loci do SGN quando aplicável. Usuários com permissão de envio podem editar acessos, enviar imagens e adicionar ligações às informações dos loci.<br/></dd>

<dt>Enviar fenótipo</dt>
<dd>Novos fenótipos e acessos de plantas podem ser enviados <a href="/stock/0/new">here</a>. Para conjuntos grandes de dados, <a href="mailto:sgn-feedback.sgn.cornell.edu">entre em contato com o SGN</a>.<br/>
A anotação de fenótipos funciona de forma semelhante à de loci. Os responsáveis pelo envio são os proprietários dos acessos e têm permissão completa de edição on-line.<br />
Para enviar fenótipos em lote, envie-nos um <a href= "/content/phenotype_submissions.pl">arquivo com as informações</a>, e imagens em CD/DVD, para que possamos carregar os dados.
</dd>

<dd><br/></dd>
<dd><img src="/documents/img/new_pheno.jpg" border="1" width="80%"></dd>

<br/>


<br/><hr/>

<dt>Para mais informações sobre os bancos de loci e fenótipos editáveis pela comunidade, consulte <a href="http://docs.google.com/Doc?id=ddhncntn_0cz2wj6">SGN submission guide</a>.</dt>
HTML


$page->footer();

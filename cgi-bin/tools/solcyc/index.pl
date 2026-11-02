use utf8;

use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / blue_section_html page_title_html /;

my $page=CXGN::Page->new("SGN SolCyc","Lukas");

$page->header();
	  
print page_title_html("<a href=\"http://solcyc.solgenomics.net/\">SolCyc</a> Vias bioquímicas");

print qq {

<img src="/documents/img/ptools.png" border="0" alt="" />
<div class="boxbgcolor1">
<p>
SolCyc é uma coleção de bancos de vias e genomas (PGDBs) de espécies de Solanaceae gerados com o <a href="http://bioinformatics.ai.sri.com/ptools/">Pathway Tools</a> software da <a href="http://www.sri.com">SRI International</a>, o mesmo software usado em <a href="http://www.arabidopsis.org/tools/aracyc/">AraCyc</a> para <i>Arabidopsis thaliana</i> e <a href="http://www.ecocyc.org">EcoCyc</a> para <i>E. coli</i>.
</p>
<p>
Atualmente estão disponíveis bancos de tomate, batata e pimentão, gerados a partir de sequências anotadas de unigenes do SGN. As montagens automáticas iniciais tiveram pouca ou nenhuma curadoria humana. O banco de berinjela deixou de ser mantido e não está mais disponível.
</p>

<ul>
<li>LycoCyc (tomato): <a href="http://solcyc.solgenomics.net/LYCO/server.html">Página de consulta</a> | <a href="http://solcyc.solgenomics.net/LYCO/NEW-IMAGE?type=OVERVIEW&amp;force=t">Diagrama geral das vias</a></li>
<li>PotatoCyc (potato): <a href="http://solcyc.solgenomics.net/POTATO/server.html">Página de consulta</a> | <a href="http://solcyc.solgenomics.net/POTATO/NEW-IMAGE?type=OVERVIEW&amp;force=t">Diagrama geral das vias</a> </li>
<li>CapCyc (pepper): <a href="http://solcyc.solgenomics.net/CAP/server.html">Página de consulta</a> | <a href="http://solcyc.solgenomics.net/CAP/NEW-IMAGE?type=OVERVIEW&amp;force=t">Diagrama geral das vias</a></li>
<li>CoffeaCyc (coffee): <a href="http://solcyc.solgenomics.net/COFFEA/server.html?">Página de consulta</a> | <a href="http://solcyc.solgenomics.net/COFFEA/NEW-IMAGE?type=OVERVIEW&amp;force=t">Diagrama geral das vias</a></li>
<li>PetuniaCyc (petunia): <a href="http://solcyc.solgenomics.net/PET/server.html?">Página de consulta</a> | <a href="http://solcyc.solgenomics.net/PET/NEW-IMAGE?type=OVERVIEW&amp;force=t">Diagrama geral das vias</a></li>
<li>NicotianaCyc (tobacco): <a href="http://solcyc.solgenomics.net/TOBACCO/server.html?">Página de consulta</a> | <a href="http://solcyc.solgenomics.net/TOBACCO/NEW-IMAGE?type=OVERVIEW&amp;force=t">Diagrama geral das vias</a></li>
</ul>

<p>
Outros bancos serão gerados e a anotação será aprimorada com vias específicas de Solanaceae.
</p>
<p>
Observe a disponibilidade de <a href="http://solcyc.solgenomics.net/expression.html">Omics viewer</a>, que permite sobrepor informações de microarranjos, chips gênicos, proteômica e metabolômica aos diagramas gerais de vias.
</p>
</div>

<p>
<img src="/documents/img/ptools.png" border="0" alt="" />
</p>

<b>Interfaces de programação para Pathway Tools</b>:<br />
Atualmente mantemos uma interface Perl e uma interface Java para Pathway Tools:
<a href="ftp://ftp.solgenomics.net/programs/javacyc/javacyc.tar.gz">JavaCyc</a> e <a href="ftp://ftp.solgenomics.net/programs/perlcyc/perlcyc.tar.gz">PerlCyc</a>. Mais informações estão disponíveis em <a href="/downloads/">software downloads</a> page.

};

$page->footer();

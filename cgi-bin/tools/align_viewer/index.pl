use utf8;
use CatalystX::GlobalContext qw( $c );
use strict;
use CXGN::Tools::Text qw | sanitize_string |;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
                                       blue_section_html  /;
use HTML::Entities;
#Get input, if this page is loaded from find_caps.pl
my $page = CXGN::Page->new( "Align Browser", "Chenwei");
my ($seq_data, $id_data, $format, $title, $type,
    $show_prot_example, $show_cds_example, $show_id_example,
    $temp_file, $maxiters) = $page->get_arguments(
    qw/seq_data id_data format title type
    show_prot_example show_cds_example show_id_example
    temp_file maxiters/
);

$seq_data =~ s/[\<\{\}\;\"\']//g; # do not remove great than sign for fasta! 
$id_data = sanitize_string($id_data);
$format = sanitize_string($format);
$title = sanitize_string($title);
$type = sanitize_string($type);
$show_prot_example = sanitize_string($show_prot_example);
$show_cds_example = sanitize_string($show_cds_example);
$show_id_example = sanitize_string($show_id_example);
$temp_file = sanitize_string($temp_file);
$maxiters = sanitize_string($maxiters);


my ($intro_content, $input_content);

my $HTML_ROOT = $c->get_conf('basepath');
my $DOC_PATH =  $c->get_conf('tempfiles_subdir').'/align_viewer';
my $PATH = $HTML_ROOT . $DOC_PATH;
if( $temp_file ) {
    $temp_file = $c->path_to( $c->generated_file_uri('align_viewer',$temp_file) );
    if(-f $temp_file){
        $seq_data = $temp_file->slurp;
    }
}


#############################################################
#Create introduction content'
$intro_content = <<HTML;
<p>Esta ferramenta analisa alinhamentos de sequências. Informe <b>apenas sequências alinhadas</b>, no formato FASTA ou Clustal.</p>
Its functionality includes:
<ol>
<li>Exibição da imagem.</li>
<li>Cálculo e saída da similaridade entre pares e de possíveis variantes de splicing ou alelos, com base na sobreposição e similaridade de pares de sequências do alinhamento.</li>
<li>Permite ocultar sequências do alinhamento para excluí-las da análise.</li>
<li>Selecione um intervalo de sequências para analisar.</li>
<li>Avaliar a sobreposição de um membro do alinhamento com os demais.</li>
<li>Calcular o ponto médio sem lacunas de cada sequência alinhada e agrupá-las pela sobreposição.</li>
</ol>
HTML

$title||="";

#############################################################
#Create input content
$input_content = <<HTML;
<form method="post" action="show_align.pl" name="aligninput" enctype="multipart/form-data">

<button type="submit" name="submit" value="Analyze Alignment">Analisar alinhamento</button><br /><br />
<b>Título (opcional): </b>&nbsp;&nbsp;
<input type="textbox" name="title" size="16" value="$title">
<br /><br />
HTML

#Alignment type
if(!$type) { $type = "pep" }
my %type_checked = ( pep => "", nt => "", cds => "" );
$type_checked{$type} = "checked=\"checked\"";
my ($tcn, $tcp, $tcc) = map { $type_checked{$_} } qw/ nt pep cds /;

$input_content .= <<HTML;
<b>Tipo</b>&nbsp;&nbsp;
<input id="aligninput.radio.nt" type="radio" name="type" value="nt" $tcn/>nucleotide &nbsp;&nbsp;
<input id="aligninput.radio.pep" type="radio" name="type" value="pep" $tcp/>peptide &nbsp;&nbsp;
<input id="aligninput.radio.pep" type="radio" name="type" value="cds" $tcc/>CDS (most powerful)
<br /><br />
HTML

#############################
#Input format let it be unaligned by default
if (!$format) { $format="fasta_unaligned"; }

my %format_checked = ( clustalw => "",
		fasta => "",
		fasta_unaligned => "",
		);

$format_checked{$format}="checked=\"checked\"";
$maxiters ||= 2;
my ($fcw, $fcf, $fcu) = map { $format_checked{$_} } qw/clustalw fasta fasta_unaligned/;

$input_content .= <<HTML;
<b>Formato de entrada</b><br />
Especifique a espécie da sequência após uma barra, por exemplo, "AT1G01010.1/Arabidopsis" <br />
Substitua todos os espaços do ID e da espécie por sublinhado (_).<br />
<input type="radio" name="format" value="clustalw" $fcw/>Clustal Alignment<a target="blank" href="/about/clustal_file.pl"> [O que é isto?]</a><br />
<input type="radio" name="format" value="fasta" $fcf/>Alinhamento FASTA (com lacunas)<br /><br />
<input type="radio" name="format" value="fasta_unaligned" $fcu/>FASTA não alinhado (será alinhado com <a href="http://www.drive5.com/muscle/">Muscle 3.6</a>, limitado a 200 sequências)<br />

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Max Iterations 
<input type="text" name="maxiters" value=$maxiters>
 Use mais iterações para maior precisão. O máximo é 1000.<br /><br />
<!--
<input type="radio" name="run" value="cluster" checked="1">run on cluster (preferred)<br />
<input type="radio" name="run" value="local">run on localhost<br /><br />
-->
HTML

if($show_prot_example){
	$seq_data = $page->path_to("cgi-bin/tools/align_viewer/data/prot_example.txt")->slurp;
}
elsif($show_cds_example){
	$seq_data = $page->path_to("cgi-bin/tools/align_viewer/data/cds_example.txt")->slurp;
}
elsif($show_id_example){
	$id_data = <<HEREDOC;
SGN-U282881 SGN-U228103 At1g09155.1 At1g56240.1 At1g56250.1 NP_178331.2 At2g02350.1 At2g02320.1 At2g02340.1 At2g02360.1 At2g02250.1 At2g02240.1 At2g02300.1 At2g02310.1 SGN-U211584 SGN-U219097 SGN-U219098 SGN-U311800 SGN-U218282 SGN-U218283 At5g24560.1 SGN-U204215 SGN-U221580 SGN-U282885 SGN-U234276 SGN-U220091 SGN-U305684 SGN-U219720
HEREDOC
}

$seq_data ||= '';
###############################
#Text area for input sequences
$input_content .= <<HTML;
<b>Informe sequências FASTA/Clustal</b>
&nbsp;&nbsp;
<a href="index.pl" onclick="
	document.getElementById('textarea_seq_data').value = '';
	return false">(x) Clear</a><br />
<textarea id="textarea_seq_data" name="seq_data" rows="12" cols="80">$seq_data</textarea><br /><br />
<b>Ou use identificadores separados por espaços</b><br />
 Supports TAIR AGI [AT1G01010.1], SGN Unigene [SGN-U332332], or any NCBI/Entrez identifier<br />
<textarea id="textarea_id_data" name="id_data" rows="2" cols="80">$id_data</textarea><br /><br />
<b>Ou envie um arquivo FASTA/Clustal</b> <input type="file" name="upload" /><br />
<br /><br />


<button type="submit" name="submit" value="Analyze Alignment">Analisar alinhamento</button>
</form>

HTML


# Print Page

$page->header();


my $example_link = <<HTML;
&nbsp;&nbsp;&nbsp;<span style="color:#669">
<a href="index.pl?&format=fasta&title=Alignment%20Example&type=pep&show_prot_example=1">
Aligned Example</a>
&nbsp;|&nbsp;
<a href="index.pl?&format=fasta_unaligned&maxiters=300&title=CDS%20Example&type=cds&show_cds_example=1">Unaligned Example</a>
&nbsp;|&nbsp;
<a href="index.pl?&maxiters=10&title=ID%20Input%20Example&&type=pep&format=fasta_unaligned&show_id_example=1">ID Input Example</a>
</span>
HTML

print page_title_html("Analisador de alinhamentos");

#print blue_section_html('Introduction','<table width="100%" cellpadding="5" cellspacing="0" border="0" summary=""><tr><td>' . $intro_content . '</td></tr></table>');

print blue_section_html(
        "<span style=\"white-space:nowrap\">Consulta &nbsp;&nbsp;&nbsp;&nbsp;$example_link</span>",
	'<table width="100%" cellpadding="5" cellspacing="0" border="0" summary=""><tr><td>' . $input_content . '</td></tr></table>');


$page->footer();

use utf8;

use strict;
use warnings;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
                                       blue_section_html  /;

#Get input, if this page is loaded from find_caps.pl
our $page = CXGN::Page->new( "CAPS Designer", "Chenwei");
my ($format, $cheap_only, $exclude_seq, $cutno, $seq_data, $seq_select) = $page->get_arguments("format", "cheap", "start", "cutno", "seq_data");#, "seq_select");

my ($intro_content, $input_content);

$intro_content = "<tr><td><p>Esta ferramenta desenha ensaios CAPS para até 12 sequências. Aceita sequências FASTA e alinhamentos Clustal e gera uma lista de enzimas polimórficas que cortam as sequências em produtos de comprimentos diferentes.</p>";
$intro_content .= "<b>Suggestions:</b><ol><li>Nucleotídeos de baixa qualidade e Ns nas extremidades da sequência geram ambiguidade. Remova-os das sequências de entrada.</li><li>Fragmentos polimórficos muito pequenos são difíceis de visualizar em gel de agarose de 1-4% e não são adequados para CAPS. Exclua alguns nucleotídeos, por exemplo 20, em cada extremidade para evitar esse problema.</li></ol></td></tr>";


$input_content = '<form method="post" action="find_caps.pl" name="capsinput">';

#Select input format
$input_content .= '<b>Formato de entrada</b><br />';
if ( $format && $format eq "clustalw" ){
  $input_content .= '<input type="radio" name="format" value="clustalw" checked="checked" />clustal alignment <a target="blank" href="/about/clustal_file.pl">[O que é isto?]</a><br />';
  $input_content .= '<input type="radio" name="format" value="fasta" />sequências FASTA não alinhadas<br /><br />';
}
else {
  $input_content .= '<input type="radio" name="format" value="clustalw" />clustal alignment <a target="blank" href="/about/clustal_file.pl">[O que é isto?]</a><br />';
  $input_content .= '<input type="radio" name="format" value="fasta" checked="checked" />sequências FASTA não alinhadas<br /><br />';
}

{ no warnings 'uninitialized';
#Text area for input sequences
$input_content .= '<b>Sequências de entrada</b><br />';
$input_content .= "<textarea name=\"seq_data\" rows=\"20\" cols=\"100\">$seq_data</textarea><br /><br /><br /><br />";
}

#Options low price enzyme
$input_content .= '<b>Options</b><br /><br />';
if ( $cheap_only ){
  $input_content .= '<input type="checkbox" name="cheap" value = "1" checked="checked" /> Find enzymes priced less than $65/1000u.<br />';
}
else {
  $input_content .= '<input type="checkbox" name="cheap" value = "1" /> Find enzymes priced less than $65/1000u.<br />';
}

#Option exclude end sequence
if (!$exclude_seq){
  $exclude_seq = 20;
}
$input_content .= "Exclude <input type=\"text\" size=\"3\" name=\"start\" value=\"$exclude_seq\" /> nucleotides at both ends<br />";

#Option cutting times
if (!$cutno){
  $cutno = 4;
}
$input_content .= "Don\'t show enzymes that cut each parent more than <input type=\"text\" name=\"cutno\" size=\"3\" value=\"$cutno\" /> times<br /><br /><br />";

$input_content .= '<button type="submit" name="submit" value="Find Caps">Localizar CAPS</button>';

$input_content .= '</form>';

#Submit and reset button
$input_content .='<form method="post" action="caps_input.pl" name="capsinput2">';
$input_content .= '<button type="submit" name="submit" value="Reset">Limpar</button></form>';
$page->header();
print page_title_html("Designer de CAPS");
print blue_section_html('Introduction','<table width="100%" cellpadding="5" cellspacing="0" border="0" summary="">' . $intro_content . '</table>');
print blue_section_html('Consulta', $input_content);


$page -> footer();

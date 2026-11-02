#!/usr/bin/perl -w
use utf8;
use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
                                       blue_section_html  /;

our $page = CXGN::Page->new("Busca de SSR", "rfa5");
my ($seq_data, $format, $title, $type) = $page->get_arguments("seq_data", "format", "title", "type");
my ($intro_content, $input_content);


#############################################################
#Create introduction content'
$intro_content = "<p>Buscar microssatélites (SSRs) em sequências nucleotídicas em lote.</p>";

#############################################################
#Create input content
$input_content = '<form method="post" action="show_ssr.pl" name="ssrinput" enctype="multipart/form-data">';

#############################
#Output type
$input_content .= '<b>Tipo de saída</b><br /><input type="radio" name="type" value="html" checked="checked" />HTML<br />';
$input_content .= '<input type="radio" name="type" value="tab" />Tab delimited<br /><br />';

#############################
#Options
$input_content .= '<b>Options</b><br />';
$input_content .= '<table width="100%" cellpadding="5" cellspacing="0" border="0" summary=""><tr>';
$input_content .= '<td>Informe o comprimento mínimo da unidade: <input type="text" name="ssr_min" value="2" size="5" /></td>';
$input_content .= '<td>Informe o comprimento máximo da unidade: <input type="text" name="ssr_max" value="10" size="5" /></td>';
$input_content .= '<td>Informe o número mínimo de repetições: <input type="text" name="ssr_repeat" value="2" size="5" /></td>';
$input_content .= '</tr></table>';

###############################
#Text area for input sequences
$input_content .= '<b>Informe sequências no formato FASTA</b><br />';
$input_content .= "<textarea name=\"seq_data\" rows=\"20\" cols=\"100\">$seq_data</textarea><br /><br />";
$input_content .= '<b>Enviar arquivo</b> <input type="file" name="upload" /><br /><br /><br />';


#########################################
#Submitbutton
$input_content .= '<button type="submit" name="submit" value="Find repeated sequences">Localizar sequências repetidas</button>';
$input_content .= '</form>';

###########################################
#Page Output  

$page->header();
print page_title_html("Busca de SSR");
print blue_section_html('Introduction','<table width="100%" cellpadding="5" cellspacing="0" border="0" summary=""><tr><td>' . $intro_content . '</td></tr></table>');
print blue_section_html('Consulta','<table width="100%" cellpadding="5" cellspacing="0" border="0" summary=""><tr><td>' . $input_content . '</td></tr></table>');
$page -> footer();

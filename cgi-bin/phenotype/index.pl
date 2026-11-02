#!/usr/bin/perl -w
use utf8;

#Main Page for Phenotypic Database

use strict;
use CXGN::Page;
use CXGN::DB::PhenoPopulation;
use CGI;

#get parameters from form on previous page
use CatalystX::GlobalContext qw( $c );
my %params = %{$c->req->params};
my $pop_id = $params{pop_id};

my $page = CXGN::Page->new('phenotype', 'Adri');

print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 transitional//EN\" \"http://www.w3.org/tr/xhtml1/DTD/xhtml1-transitional.dtd\">";

$page->header("Buscar no banco de dados de fenótipos");

#-------------------------------------------------
my @populations = CXGN::DB::PhenoPopulation::get_all_populations;
my $current_pop_id;
my $current_pop_name;

#population selected
if ($pop_id) {
  $current_pop_id = $pop_id;
  $current_pop_name = CXGN::DB::PhenoPopulation::get_pop_name_from_pop_id($pop_id);
}

#no population selected, first one in DB is used as default
else {
  $current_pop_id = $populations[0][0];
  $current_pop_name = $populations[0][1];
}

my @genotypes = CXGN::DB::PhenoPopulation::get_all_gen_from_pop_id($current_pop_id);
my @gen_ids;
for my $i (0..$#genotypes) {
  push @gen_ids, $genotypes[$i][0];
}
my @prop_info_by_organ = CXGN::DB::PhenoPopulation::get_all_prop_info_by_organ_from_pop_id($current_pop_id);

print <<EOF

<table summary="" width="100%" cellpadding="0" cellspacing="10" border="0">

<tr><td valign="top">
<table summary="" width="100%" cellpadding="0" cellspacing="0" border="0">

<tr><td>
<center>
<h3><u>Bem-vindo ao banco de dados de fenótipos</u></h3>
<p>Nesta página, você pode buscar dados e imagens de plantas de todas as populações no banco de fenótipos.</p>
<p>Há duas formas de encontrar dados e imagens: por genótipo ou por fenótipo.</p>
</center>
</td></tr>

<tr><td><img src="/documents/img/dot_clear.gif" width="1" alt="" height="10" /></td></tr>
<tr><td colspan="1" bgcolor="#cccccc"><img src="/documents/img/dot_clear.gif" alt="" width="1" height="1" /></td></tr>
<tr><td><img src="/documents/img/dot_clear.gif" width="1" height="10" alt="" /></td></tr>

<tr><td>
<center><h3><u>Buscar no banco de dados de fenótipos</u></h3></center>

<center>
<table summary="" width="100%" cellpadding="0" cellspacing="0" border="0">

<tr><td>
<!--populations-->
<form action="#" method="get">
<table summary="">
<tr><td valign="top">

EOF
;

print "<b><u>POPULAÇÃO selecionada:</u> $current_pop_name</b>";

print <<EOF
</td></tr>
<tr><td><p>Abaixo estão as populações do banco de dados. Selecione uma população e clique no botão para buscar imagens e dados em outra população.</p></td></tr>
<tr><td valign="top" align="left">
Todas as populações:
<select name="pop_id">
EOF
;

for (0..$#populations) {
  print "<option value = \"$populations[$_][0]\">$populations[$_][1]</option>";
}

print <<EOF
</select>
</td>
<td valign="top" align="right">
<button type="submit" value="Change Population">Alterar população</button>
</td></tr>
</table>
</form>
</td></tr>

<!--genotypes-->

<tr><td>
<form action="/phenotype/display_plants_from_genotype.pl" method="get">
<table summary="">
<tr><td>
<b><u>Buscar por GENÓTIPOS</u></b>
</td></tr>
<tr><td><p>Abaixo está uma lista de todos os <b>genótipos</b> na população selecionada acima. Ao selecionar um genótipo, você verá as plantas correspondentes e os links para suas imagens e dados:</p></td></tr>
<tr><td valign="top" align="left">

EOF
;

print "Genotypes in <b>$current_pop_name</b>:";
print "<select name=\"gen_id\">";
for my $i (0..$#genotypes) {
  print "<option value = \"$genotypes[$i][0]\"> $genotypes[$i][1]</option>";
}
print "</select>";
print "<input type=\"hidden\" name=\"pop_id\" value=\"$current_pop_id\" />";
print "<input type=\"hidden\" name=\"pop_name\" value=\"$current_pop_name\" />";

print <<EOF
</td>
<td valign="top" align="right">
<button type="submit" value="get Plants by Genotype">Obter plantas por genótipo</button>
</td></tr>
</table>
</form>
</td></tr>

<!--properties-->
<tr><td>
<form action="/phenotype/display_plants_from_property.pl" method="get">
<table summary=""><tr><td>
<b><u>Buscar por PROPRIEDADES</u></b> (<a href="display_prop_list.pl">Property Descriptions</a>)
</td></tr>
<tr><td>
EOF
;

print "<p>Abaixo está uma lista de todos os <b>properties</b> medidas na população selecionada acima. Ao selecionar uma propriedade, você verá as plantas com essa propriedade medida e os links para os dados e as imagens de suas amostras:</p>";

print "</td></tr>";
print "<tr><td width=\"100%\" valign=\"top\" align=\"left\">";

print "Properties in <b>$current_pop_name</b>:";
print "<select name=\"prop_id\">";

for (0..$#prop_info_by_organ) {
  my $i = $_;
  $prop_info_by_organ[$i] or next;
  my $organ_name = $prop_info_by_organ[$i][0][2];
  print "<optgroup label=\"$organ_name\">";
  for (0..$#{$prop_info_by_organ[$i]}) {
    my $j = $_;
    my $prop_id = $prop_info_by_organ[$i][$j][0];
    my $prop_name = $prop_info_by_organ[$i][$j][1];
    print "<option value = \"$prop_id\">$prop_name</option>\n";
  }
  print "</optgroup>";
}

print "</select>";
print "<input type=\"hidden\" name=\"pop_id\" value=\"$current_pop_id\" />";
print "<input type=\"hidden\" name=\"pop_name\" value=\"$current_pop_name\" />";

print <<EOF

</td>
<td width="100%" valign="top" align="right">
<button type="submit" value="get Plants by Property">Obter plantas por propriedade</button>
</td></tr></table>
</form>
</td></tr>

</table>
</center>
</td>
</tr>

</table>
</td></tr>

<tr><td><img src="/documents/img/dot_clear.gif" width="1" height="10" alt="" /></td></tr>
<tr><td bgcolor="#cccccc"><img src="/documents/img/dot_clear.gif" width="1" height="1" alt="" /></td></tr>
<tr><td><img src="/documents/img/dot_clear.gif" width="1" height="10" alt="" /></td></tr>

<!--terminology-->
<tr><td>
<center><h3><u>Terminology</u></h3></center>

<table summary="" width="100%" cellpadding="0" cellspacing="0" border="0">
<tr><td>

<dl>
<dt><b>População</b></dt>
<dd>todos os organismos que constituem um grupo ou ocorrem em um local específico.</dd>
<dt><br /><b>Genótipo</b></dt>
<dd>grupo de organismos com uma constituição genética específica.</dd>
<dt><br /><b>Propriedade/Fenótipo</b></dt>
<dd>características físicas ou bioquímicas observáveis de um organismo, determinadas pela constituição genética e pelas influências ambientais.</dd>
</dl>

</td></tr>
</table>

</td></tr>

</table>
EOF
;

#--------------------------
$page->footer();

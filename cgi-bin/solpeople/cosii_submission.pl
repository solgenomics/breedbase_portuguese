use utf8;
use Modern::Perl;
use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Marker::Tools;
use CXGN::Accession;
use CXGN::Accession::Tools;
use CXGN::Login;
use CXGN::Tools::Text;

my $dbh=CXGN::DB::Connection->new();

my $login=CXGN::Login->new($dbh);
$login->verify_session();

my $page=CXGN::Page->new('cosii_submission.pl','john');

$page->header('Enviar experimento de primers COSII');
my($action,$marker_name,$accession_id,$primer_type,$temp,$mg,$bands)=$page->get_encoded_arguments('action','marker_name','accession_id','primer_type','temp','mg','bands');
my $marker_id;
my $accession_name;

if($action eq 'verify' or $action eq 'insert') {
    my @marker_ids=CXGN::Marker::Tools::marker_name_to_ids($dbh,$marker_name);

    unless(@marker_ids) {
        $page->message_page("Marcador '$marker_name' não encontrado.");
    }

    #i don't want to write any error handling here, because all cosii marker names (currently) refer to one marker each
    if(@marker_ids>1) {
        $page->message_page("Vários marcadores encontrados com o nome '$marker_name'. Entre em contato conosco para resolver o problema.");
    }

    ($marker_id)=@marker_ids;

    #test accession
    my $accession=CXGN::Accession->new($dbh,$accession_id);
    unless($accession) {
        $page->message_page("ID de acesso '$accession_id' não encontrado no banco de dados");
    }
    $accession_name=$accession->verbose_name();

    #test primer type
    unless($primer_type eq 'iUPA' or $primer_type eq 'eUPA') {
        $page->message_page("Primer type '$primer_type' is unknown");
    }

    #test temp
    unless($temp=~/^\d+$/) {
        $page->message_page("Temperatura '$temp' não reconhecida. Informe apenas um número inteiro.");
    }
    if($temp>500) {
        $page->message_page("Temperatura '$temp' inválida");
    }

    #test mg
    unless(CXGN::Tools::Text::is_number($mg)) {
        $page->message_page("Concentração de Mg não reconhecida. Informe um número inteiro ou com apenas uma casa decimal, usando ponto como separador.");
    }

    #test bands
    unless($bands eq 'M' or $bands eq 'm' or $bands=~/^\d+$/ or $bands=~/^\d+\+\d+$/) {
        $page->message_page("Tamanhos de banda não reconhecidos. Consulte os exemplos e não inclua espaços no valor informado.");
    }
    if($bands eq 'm') {
        $bands='M';
    }
}





if($action eq 'verify')
{
    print CXGN::Page::FormattingHelpers::page_title_html('Verificar dados');
    print"<b>Nome do marcador:</b> $marker_name (SGN-M$marker_id)<br />";
    print"<b>Acesso:</b> $accession_name (SGN accession ID:</b> $accession_id)<br />";
    print"<b>Tipo de primer:</b> $primer_type<br />";
    print"<b>Temperature:</b> $temp<br />";
    print"<b>Mg concentration:</b> $mg<br />";
    print"<b>Bands:</b> $bands<br /><br />";
    print <<END_HTML;
<form method="post" action="">
<input type="hidden" name="marker_id" value="$marker_id" />
<input type="hidden" name="marker_name" value="$marker_name" />
<input type="hidden" name="accession_id" value="$accession_id" />
<input type="hidden" name="primer_type" value="$primer_type" />
<input type="hidden" name="temp" value="$temp" />
<input type="hidden" name="mg" value="$mg" />
<input type="hidden" name="bands" value="$bands" />
<input type="hidden" name="action" value="insert" />
<button type="submit" value="Add new data">Adicionar dados</button>
END_HTML
    exit(0);
}





if($action eq 'insert')
{
    print CXGN::Page::FormattingHelpers::page_title_html('Simulação de adição destes dados');
    print"<a href=\"/search/markers/markerinfo.pl?marker_id=$marker_id\">[Visualizar marcador com os novos dados]</a><br /><br />";
    print"<b>Nome do marcador:</b> $marker_name (SGN-M$marker_id)<br />";
    print"<b>Acesso:</b> $accession_name (SGN accession ID:</b> $accession_id)<br />";
    print"<b>Tipo de primer:</b> $primer_type<br />";
    print"<b>Temperature:</b> $temp<br />";
    print"<b>Mg concentration:</b> $mg<br />";
    print"<b>Bands:</b> $bands<br />";
    print"<hr />"
}





my $marker_name_filled_in='C2_At';
if($marker_name)
{
    $marker_name_filled_in=$marker_name;
}
my $temp_filled_in='55';
if($temp)
{
    $temp_filled_in=$temp;
}
my $mg_filled_in='1.5';
if($mg)
{
    $mg_filled_in=$mg;
}
my $bands_filled_in='';
if($bands)
{
    $bands_filled_in=$bands;
}
my @accessions=CXGN::Accession::Tools::all_accessions($dbh);
my $accessions_selector='<select name="accession_id">';
for my $accession_hash(sort {$a->{verbose_name} cmp $b->{verbose_name}} @accessions)
{
    my $each_accession_id=$accession_hash->{accession_id};
    my $each_accession_name=$accession_hash->{verbose_name};
    #warn"$each_accession_id\n";
    my $selected='';
    if($each_accession_id==$accession_id)
    {
        $selected=' selected="selected" ';
    }
    $accessions_selector.="<option value=\"$each_accession_id\" $selected>$each_accession_name</option>";
}
$accessions_selector.='</select>';
my $iupa_selected='checked="checked"';
my $eupa_selected='';
if($primer_type and $primer_type eq 'eUPA')
{
    $iupa_selected='';
    $eupa_selected='checked="checked"';
}
print <<END_HTML;
<center>
<form method="post" action="">
<table cellspacing="10" cellpadding="10" border="0">

<tr>
<td>
Nome do marcador<br />
<input type="text" name="marker_name" value="$marker_name_filled_in" /><br />
</td>
<td>
Tipo de primer<br />
<input type="radio" name="primer_type" value="iUPA" $iupa_selected />iUPA<br />
<input type="radio" name="primer_type" value="eUPA" $eupa_selected />eUPA
</td>
</tr>

<tr>
<td colspan="2">
Acesso<br />
$accessions_selector
<br />Para adicionar um acesso a esta lista, <a href="/contact/form">entre em contato com o SGN</a>.
</td>
</tr>

<tr>
<td>
Temperature (C)<br />
<input type="text" name="temp" value="$temp_filled_in" /><br />
</td>
<td>
Mg concentration<br />
<input type="text" name="mg" value="$mg_filled_in" /><br /><br />
</td>
</tr>

<tr>
<td>
Band sizes<br />
<input type="text" name="bands" value="$bands_filled_in" />
</td>
<td>
Band size examples:<br />
1 band: <b>300</b><br />
2 bands separated by a '+' sign: <b>300+500</b><br />
M para mais de 2: <b>M</b>
</td>
</tr>

<tr>
<td colspan="2">
<input type="hidden" name="action" value="verify" />
<button type="submit" value="Verify">Verificar</button>
</td>
</tr>

</table>
</form>    
</center>
END_HTML
$page->footer();

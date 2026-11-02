#!/usr/bin/perl -w
use utf8;
use strict;
use CXGN::Page;
use CatalystX::GlobalContext '$c';

my $tmpdir = $c->config->{'basepath'} . $c->config->{'tempfiles_subdir'} . "/blastgraph/";

our $page = CXGN::Page->new("BLAST running", "Koni");

#'output_graphs' will be passed on to view_result.pl
my ($request_file, $not_finished, $invalid, $output_graph_option) 
	= $page->get_arguments("request", "notfinished","invalids", "output_graphs");

if ( ! -f "$tmpdir/${request_file}.req" ) {
  print STDERR "$request_file ($!)\n";
  request_not_found($page);
}

open REQUEST_FILE, "<$tmpdir/$request_file.req"
  or $page->error_page("Não foi possível abrir o arquivo de requisição do BLAST " . "\"$request_file\" ($!)");

my @output = ();
my $refresh = "";
while(<REQUEST_FILE>) {
  chomp;
  my ($name, $file) = split/\t/;

  if ( -f "$tmpdir/$file.html" ) {
    push @output, "<tr><td><a href=\"./view_result.pl?result_file=$file.html&output_graphs=$output_graph_option\">$name</a></td><td><font color=#009900>Finished</font></td></tr>";
  } elsif ( -f "$tmpdir/$file" ) {
    push @output, "<tr><td>$name</td><td><font color=\"#CCCC00\">Running</font></td></tr>";
    $refresh = "<meta http-equiv=\"Refresh\" content=\"30; URL=./wait_result.pl?request=$request_file&invalids=$invalid&output_graphs=$output_graph_option\">";
    $not_finished="yes";
  } else {
    push @output, "<tr><td>$name</td><td><font color=#CC0000>Queued</font></td></tr>";
    $refresh = "<meta http-equiv=\"Refresh\" content=\"30; URL=./wait_result.pl?request=$request_file&invalids=$invalid&output_graphs=$output_graph_option\">";
    $not_finished="yes";
  }
}

close REQUEST_FILE;

my $text = "";
if ($not_finished eq "yes") {

  $text = "<tr><td><p>Sua requisição BLAST ainda está em execução. Use os links abaixo para ver os resultados. Recarregue a página para atualizar o status. Ela será recarregada automaticamente a cada <b>30 seconds</b>.</p></td></tr>";
} else {
  $text = "<tr><td align=\"center\"><p>BLAST concluído. Use os links abaixo para ver os resultados.</p></td></tr>";
}

my $invalid_text;
if ($invalid eq "yes") {
  $invalid_text ="<p>NOTE: Some combinations of BLAST programs and target databases were invalid (i.e. protein search on nucleotide database) and automatically skipped.";
} else {
  $invalid_text = "";
}

$page->header("", $refresh);

print <<EOF;

<h4><center>RESULTADOS DA BUSCA BLAST DO SGN</center></h4>

<table width="80%" cellpadding="2" cellspacing="2" border="0" align="center">
$text
<tr><td><table cellpadding="2" cellspacing="2" border="0" align="center">
  <tr><th>Job</th><th>Status</th></tr>
  <tr><td></td><td><img src="/documents/img/dot_clear.png" height="1" width="40"></td></tr>
  @output
  </table>
  $invalid_text
</td></tr>
</table>
<br />
EOF



$page->footer();

sub request_not_found {
  my ($page) = @_;

  $page->header();

  print <<EOF;

  <h4>ERRO DO BLAST DO SGN -- REQUISIÇÃO ANTIGA NÃO ENCONTRADA</h4>

  <p>O navegador solicitou o status de uma tarefa BLAST que não existe. <b>não adicione aos favoritos</b> os resultados do BLAST, pois são excluídos automaticamente do servidor após 2 dias.</p>

EOF

  $page->footer();
  exit(0);
}

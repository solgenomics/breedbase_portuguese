use utf8;


package CXGN::Blast::Parse::Plugin::BlastOverviewGraph;

use Moose;
use Bio::GMOD::Blast::Graph;
use File::Basename qw | basename |;
use File::Slurp qw | read_file |;

sub name { 
  return "Overview";
  # return "Overview graph";
}

# at what point to display it... preferably on the top
sub priority { 
  1;
}

sub prereqs { 

}

sub parse { 
  my $self = shift;
  my $c = shift;
  my $raw_report_file = shift;
  my $bdb = shift;
  
  return 'Nenhum relatório encontrado.' unless -e $raw_report_file;
  
  return 'A exibição gráfica não está disponível para relatórios BLAST maiores que 1 MB' if -s $raw_report_file > 1_000_000;
  
  return '<b>Gráfico geral:</b> não exibido porque nenhum resultado foi encontrado.<br /><br />' if no_hits($raw_report_file);

  open(my $fh, ">", $raw_report_file.".blast_graph.html") || die "Can't open $raw_report_file .blast_graph.html";

  my $filename = basename($raw_report_file);

  eval { 
    my $graph = Bio::GMOD::Blast::Graph->new(-outputfile => $raw_report_file,
      -dstDir => $c->config->{basepath}."/".$c->config->{tempfiles_subdir}."/",
      -format => 'blast',
      -dstURL => $c->config->{tempfiles_subdir}."/",
      -imgName=> $filename.".blast_graph.png",
      -fh     => $fh
    );

    $graph->showGraph();
  };

  if ($@) { 
    return "<b>Nenhum gráfico geral disponível</b> ($@)";
  }
  
  my $html = "<center>". read_file($raw_report_file.".blast_graph.html")."</center>";
  
  return $html;
}

sub no_hits { 
  my $file = shift;
  my $contents = read_file($file);
  
  if ($contents =~ /No hits found/) { 
    return 1;
  }
  
  return 0;
}



1;

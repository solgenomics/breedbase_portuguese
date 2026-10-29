
package CXGN::Blast::Parse::Plugin::CoverageGraph;
use utf8;

use Moose;
use File::Basename;
use File::Slurp;

sub name { 
    return "Coverage";
    # return "Coverage graph";
}

sub prereqs { 
}

sub parse { 
    my $self = shift;
    my $c = shift;
    my $raw_report_file = shift;
    
    my $basename = basename($raw_report_file);

      if (no_hits($raw_report_file)) { 
     	return "<b>Gráfico de cobertura:</b> não exibido porque nenhum hit foi encontrado.<br /><br />";
     }

    #graph variables for just Evan's graph package
    my $graph_img_fileurl = $c->tempfile(TEMPLATE=> "blast/blast_coverage_XXXXXX", UNLINK=>0);
    my $graph_img_filepath = $c->path_to($graph_img_fileurl);
    
    my $graph2 = CXGN::Graphics::BlastGraph->new( blast_outfile => $raw_report_file,
                                                graph_outfile => $graph_img_filepath,
                                              );

  return { error => "Relatório BLAST grande demais para este método de análise", } if -s $raw_report_file > 1_000_000;

  my $errstr = $graph2->write_img();
  if ($errstr) { 
      #return "<b>Sorry, and error occurred.</b> $errstr";
  }

 

  return join '',
    ( <<EOH,
<center><b>Histograma de conservação</b></center>
<p>O histograma mostra a contagem de resultados <i>para cada base</i> na sequência de consulta,
mas conta <i>apenas os domínios encontrados pelo BLAST</i>, portanto representa mais uma medida por região do que por base individual.
No gráfico, verde indica bases idênticas nas regiões conservadas; azul indica bases diferentes nessas regiões. Lacunas introduzidas pelo BLAST na sequência de consulta são ignoradas; lacunas nas sequências-alvo são consideradas.</p>
EOH
      qq|<center>|,
      $graph2->get_map_html(), #code for map element (should have the name used below in the image)
      qq|<div align="center" style="color: #777777">|,
      qq|<img src="$graph_img_fileurl" border="2" usemap="#graph2map" alt="" />|,
      qq|</div>|,
      qq|</center>|,
    );

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

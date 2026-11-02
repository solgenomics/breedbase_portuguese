use utf8;

use strict;

use File::Temp qw//;
use File::Spec;

use CXGN::DB::Connection;
use CXGN::TomatoGenome::BACPublish qw/tpf_agp_files/;
use CXGN::Genomic::Clone;
use CXGN::Genomic::CloneIdentifiers qw/parse_clone_ident/;
use CXGN::Login;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw( info_section_html
				      page_title_html
				      columnar_table_html
				      info_table_html
				      modesel
				    );
use CXGN::People;
use CXGN::Publish qw/publish/;

#tpf_agp is in the current directory
use CXGN::TomatoGenome::tpf_agp qw(
				   format_validation_report
				   filename
				   published_ftp_download_links
				   tabdelim_to_html
				   tabdelim_to_array
				   modtime_string
				  );

my $page = CXGN::Page->new("Exibição do caminho de cobertura","Rob");
my $dbh = CXGN::DB::Connection->new();

#get input arguments and validate
my ($chr) = $page->get_arguments(qw/chr/);
$chr += 0; #force chr to be numeric
$chr ||= 1;

#if we have a file upload, validate it according to its type and store it
if(my $upload = $page->get_upload ) {
  #get the active login
  my $sp_person_id = CXGN::Login->new($dbh)->verify_session();
  my $sp = CXGN::People::Person->new($dbh, $sp_person_id);
  $sp->get_username
    or do {print $page->header; graceful_exit("Nome de usuário não encontrado.")};

  #check that the login has permission to upload for this chromosome
  unless($sp->get_user_type eq 'curator'
	 || grep {$_ == $chr && $_ <= 12 && $_ >= 1} $sp->get_projects_associated_with_person) {
    print $page->header(); graceful_exit('Sua conta não tem permissão para enviar arquivos para esse cromossomo');
  }

  my $validation_report = validate_and_publish_tpf($upload->fh,$chr);
  $page->message_page('Falha na validação do TPF',$validation_report) if $validation_report;
}


$page->header('Exibição de TPF',"Caminhos de cobertura dos cromossomos");
print <<EOHTML;
<p>As listas de caminhos de cobertura abaixo foram desenvolvidas e enviadas ao
SGN pelos respectivos <a href="/about/tomato_sequencing.pl">projetos de sequenciamento
dos cromossomos de tomate</a>.</p>

<p>A lista abaixo mostra os clones que compõem o caminho de cobertura
planejado atualmente para este cromossomo, junto com as lacunas
que ainda precisam ser cobertas por uma sequência de clones.</p>

<p>O formato TPF consiste em três colunas:</p>
<ol>
  <li>o acesso NCBI/EMBL da sequência do BAC</li>
  <li>o nome da sequência do BAC no SGN</li>
  <li>um nome para cada grupo contíguo de BACs, interno a cada projeto de sequenciamento de cromossomo</li>
</ol>

<p>Esses arquivos também estão disponíveis para download <a href="ftp://ftp.sgn.cornell.edu/tomato_genome/tpf">via FTP</a>.</p>
EOHTML

if ($chr > 12 or $chr < 1){
  graceful_exit("Oops! Chromosome number must be between 1-12.");
}

print qq|<div style="text-align: center; font-weight: bold; margin-bottom: 0.5em">Cromossomo</div>\n|;
print modesel( [map {["?chr=$_",$_]} 1..12], $chr-1);
print "<br />\n";


#now show the current tpf and agp files

my $published_tpf;
eval {
  ($published_tpf,undef) = tpf_agp_files($chr);
};
if ($@){
  graceful_exit($@);
}

my ($published_tpf_ftp,undef) = published_ftp_download_links($chr);
print info_section_html( title    => 'Tiling Path Format (TPF)',
			 subtitle => modtime_string($published_tpf).'  '.$published_tpf_ftp,
			 contents => tpf_to_html($published_tpf) || <<EOHTML,
<center><b>Nenhum arquivo TPF está disponível para o cromossomo $chr</b></center>
EOHTML
		       );
print info_section_html( title    => "Outros recursos do cromossomo $chr",
			 contents =>  <<EOHTML,
<ul>
<li>Mapas de tomate: <a href="/cview/index.pl">Genético</a> | <a href="/cview/map.pl?map_id=9&amp;physical=1">Físico</a> | <a href="/cview/map.pl?map_id=13">Resultados de BAC FISH</a></li>
<li><a href="/organism/Solanum_lycopersicum/clone_sequencing?chr=$chr">Lista de BACs do cromossomo $chr</a></li>
<li><a href="agp.pl?chr=$chr">Montagem (AGP) do cromossomo $chr</a></li>
</ul>
EOHTML
		       );
$page->footer;



# we should NOT be using error_page! Use this instead!
sub graceful_exit {

  my ($message) = @_;
  print $message;
  print $page->footer;
  exit;

}

#CHECK:
#correct number of columns
#correct data type of each column
#correctly formed bac identifiers
#bac identifiers are on the correct chromosome
sub validate_and_publish_tpf {
  my ($tpf_fh,$chr) = @_;
  my $publishing_filename = filename($chr,'tpf');
  my $tmp = File::Temp->new( UNLINK => 1, SUFFIX => '.tpf' );
  my @errors;
  my $line_ctr = 0;
  my $err = sub {
    push @errors, "Linha $line_ctr: ".shift;
  };
  #copy the tpf file from the apache-spooled temp file.  while doing
  #that, go over each line and validate it
  while(my $line = <$tpf_fh>) {
    $line_ctr++;
    chomp $line;
    $line =~ s/\r$//;
    unless($line =~ /^\s*#/) {
      my @d = split /\s+/,$line;
      @d == 3 or $err->("Número incorreto de colunas:  ".scalar(@d)." colunas encontradas");
      if( $d[0] =~ /^GAP$/ ) {
        $d[1] =~ /^type-[1234]$|/ or $err->("Se a primeira coluna for GAP, a segunda deve ser um tipo de lacuna type-[1234]");
        $d[2] eq '?' or $err->("Se a primeira coluna for 'GAP', a terceira deve ser '?' (o valor é '$d[2]')");
      }
      elsif( $d[0] eq '?' || $d[0] =~ /^\S{5,}$/ ) {
	my $p = parse_clone_ident($d[1],qw/agi_bac_with_chrom agi_bac/)
            or $err->("Se a linha não for uma lacuna, a segunda coluna deve conter um identificador válido de clone BAC do SGN");
	if($p) {
	  my $c = CXGN::Genomic::Clone->retrieve_from_parsed_name($p)
            or $err->("Identificador de clone desconhecido na segunda coluna: '$d[1]'");
	  if($c) {
	    $c->chromosome_num == $chr
              or $err->("O BAC com o identificador '$d[1]' não está registrado no cromossomo $chr");
	    $d[1] = $c->clone_name_with_chromosome;
	  }
	}
      }
      else {
        $err->("Primeira coluna inválida: '$d[0]'");
      }
      print $tmp join("\t",@d)."\n";
    } else {
      print $tmp "$line\n";
    }
  }
  close $tmp; #make sure we flush the writes we made
  if(@errors) {
    return format_validation_report(@errors);
  } else {
    publish(['cp', "$tmp", $publishing_filename]);
    return;
  }
}

sub tpf_to_html {
  my ($filename) = @_;
  if($filename && -f $filename) {
    return tabdelim_to_html($filename,undef,
			#this sub looks at the contents of each
			#table cell and might emit some style rules
			#to highlight it
			    sub {
			      my ($contents) = @_;
			      if ($contents =~ /^\s*#/) {
				'color: green'
			      } elsif ( $contents =~ /^\s*GAP\s*$/ ) {
				'color: red'
			      } elsif ( $contents =~ /^\s*\?\s*$/ ) {
				'font-weight: bold'
			      }
			    }
			   );

  }
}


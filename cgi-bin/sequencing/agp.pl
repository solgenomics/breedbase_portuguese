use utf8;
use strict;

use File::Temp qw//;
use File::Spec;

use Bio::DB::GenBank;

use CXGN::TomatoGenome::BACPublish qw/tpf_agp_files/;
use CXGN::BioTools::AGP qw/agp_parse agp_write/;
use CXGN::Genomic::Clone;
use CXGN::Genomic::CloneIdentifiers qw/parse_clone_ident/;
#use CXGN::Login; # does not seem to be used
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw( info_section_html
				      page_title_html
				      columnar_table_html
				      info_table_html
				      modesel
				      html_break_string
				    );
use CXGN::People;
use CXGN::Publish qw/publish/;
use CXGN::Tools::List qw/str_in/;


#tpf_agp is in the current directory
use CXGN::TomatoGenome::tpf_agp qw(
				   format_validation_report
				   filename
				   published_ftp_download_links
				   tabdelim_to_html
				   tabdelim_to_array
				   modtime_string
				  );

my $page = CXGN::Page->new("Exibição de AGP","Rob");

#get input arguments and validate
my ($chr) = $page->get_arguments(qw/chr/);
$chr += 0; #force chr to be numeric
$chr ||= 1;

#if we have a file upload, validate it according to its type and store it
if(my $upload = $page->get_upload ) {
  #get the active login
#   my $sp_person_id = CXGN::Login->new()->verify_session()
#     or $page->error_page("Login ID not found");
#   my $sp = CXGN::People::Person->new($sp_person_id);
#   $sp->get_username
#     or $page->error_page("Username not found.","","", "Username not found for sp_person_id '$sp_person_id'");

#   #check that the login has permission to upload for this chromosome
#   unless($sp->get_user_type eq 'curator'
# 	 || grep {$_ == $chr && $_ <= 12 && $_ >= 1} $sp->get_projects_associated_with_person) {
#     $page->error_page('your account does not have privileges to upload files for that chromosome');
#   }

  my $validation_report = validate_and_publish_agp($upload->fh,$chr);
  $page->message_page('Falha na validação do AGP',$validation_report) if $validation_report;
}


$page->header('Exibição da montagem',"Montagens de cromossomos");
print <<EOHTML;
<p>As listas abaixo foram desenvolvidas e enviadas ao SGN pelos respectivos <a href="/about/tomato_sequencing.pl">projetos de sequenciamento dos cromossomos de tomate</a>.</p>
<p>O arquivo AGP descreve a melhor montagem de sequência conhecida atualmente para este cromossomo. As descrições desse formato estão disponíveis <a href="http://www.ncbi.nlm.nih.gov/genome/guide/Assembly/AGP_Specification.html">no NCBI</a> e <a href="http://genome.ucsc.edu/goldenPath/datorg.html">na UCSC</a>.</p>
<p>Esses arquivos também estão disponíveis para download <a href="ftp://ftp.sgn.cornell.edu/tomato_genome/agp">via FTP</a>.</p>
EOHTML

print qq|<div style="text-align: center; font-weight: bold; margin-bottom: 0.5em">Cromossomo</div>\n|;
print modesel( [map {["?chr=$_",$_]} 1..12], $chr-1);
print "<br />\n";

#now show the current tpf and agp files
my (undef,$published_agp) = tpf_agp_files($chr);
my $agp_modtime  = modtime_string($published_agp);
my (undef,$published_agp_ftp) = published_ftp_download_links($chr);
print info_section_html( title    => 'Accessioned Golden Path (AGP)',
			 subtitle => "$agp_modtime  $published_agp_ftp",
			 contents => agp_to_html($published_agp) || <<EOHTML,
<center><b>Nenhum arquivo AGP está disponível para o cromossomo $chr</b></center>
EOHTML
		       );
print info_section_html( title    => "Outros recursos do cromossomo $chr",
			 contents =>  <<EOHTML,
<ul>
<li>Mapas de tomate: <a href="/cview/index.pl">Genético</a> | <a href="/cview/map.pl?map_id=9&amp;physical=1">Físico</a> | <a href="/cview/map.pl?map_id=13">Resultados de BAC FISH</a></li>
<li><a href="/organism/Solanum_lycopersicum/clone_sequencing?chr=$chr">Lista de BACs do cromossomo $chr</a></li>
<li><a href="tpf.pl?chr=$chr">Caminho de cobertura (TPF) do cromossomo $chr</a></li>
</ul>
EOHTML
		       );
$page->footer;


sub validate_and_publish_agp {
  my ($agp_fh,$chr) = @_;

  #warn "we got a '$agp_fh', which refs to ".ref($agp_fh);

  #parse the AGP, validate its syntax
  my @errors;
  my $lines = agp_parse($agp_fh, validate_syntax => 1, error_array => \@errors )
    or return format_validation_report(@errors);

  #now check the report for consistency in other things
  my $err = sub {
    my $linerec = shift;
    push @errors, "<AGP>:$linerec->{linenum}: ".shift;
  };

  foreach our $l (@$lines) {
    next if $l->{comment}; #ignore comments for this step

    my $err = sub {
      push @errors, "<AGP>:$l->{linenum}: ".shift;
    };

    #check that we have the correct object identifier
    $l->{objname} eq "S.lycopersicum-chr$chr"
      or $err->("a primeira coluna deve ser 'S.lycopersicum-chr$chr', em vez de '$l->{objname}'");

    if(my $ident = $l->{ident}) {
      	my $p = parse_clone_ident($ident,'agi_bac_with_chrom','agi_bac','versioned_bac_seq');

	#try to treat it as a versioned genbank accession.  look it
	#up, get its clone name, then compare its sequence to the most
	#recent sequence we have on file for that clone.  error if
	#they don't match
	my $c = $p ? CXGN::Genomic::Clone->retrieve_from_parsed_name($p)
                     || $err->("Identificador de sequência desconhecido: '$ident'")
	           : lookup_and_match_genbank_accession($ident,$err);

	unless( ref $c ) {
          $err->("Nenhuma sequência de BAC encontrada para o identificador '$ident'");
	} else {
	  $c->chromosome_num == $chr
            or $err->("O BAC referenciado pelo identificador '$ident' não está atribuído ao cromossomo $chr");
	  my $latest_ver = $c->latest_sequence_version;
	  !$p->{version} || $p->{version} == $latest_ver
            or $err->("A versão da sequência de '$ident' difere da versão mais recente no banco de dados do SGN, que é '$latest_ver'.");

	  #rewrite the identifier to the SGN-type identifier
	  $l->{ident} = $c->latest_sequence_name
            or $err->("A sequência de '$ident' ainda não foi carregada no banco de dados do SGN. Se ainda não a enviou, faça isso antes de publicar esta montagem. Se já a enviou, aguarde algumas horas para que o carregamento seja concluído e tente enviar este arquivo novamente.");

	  # check that the length of this element is not longer than the element referred to
	  my $seq = $c->seq
            or $err->("Não foi possível obter a sequência de '$ident'");
	  my $seqlen = length($seq);
	  $seqlen >= $l->{length}
            or $err->("o comprimento deste componente ($l->{length} bases) é maior que o da sequência especificada ($ident, $seqlen bases)");
	}
    }

  }

  #splat if we have errors
  @errors
    and return format_validation_report(@errors);

  #otherwise, go ahead and rewrite and publish
  my $tmp = File::Temp->new( UNLINK => 1, SUFFIX => '.agp' );
  agp_write($lines,$tmp);
  close $tmp;

  my $publishing_filename = filename($chr,'agp')
    or die "no filename to publish to??";
  publish(['cp', "$tmp", $publishing_filename]);

  return;
}

sub agp_to_html {
  my ($filename) = @_;
  if( $filename && -f $filename ) {
    return tabdelim_to_html($filename, 'AGP',
			    sub {
			      my ($contents) = @_;
			      if ($contents =~ /^#/) {
				'color: green'
			      } # elsif ( $contents eq 'N' ) {
# 				''
# 			      } elsif( $contents eq 'yes' ){
# 				'color: green; font-weight: bold'
# 			      } elsif( $contents eq 'F' ) {
# 				'background: #b0b0e4; font-weight: bold;'
# 			      } elsif( $contents eq 'D' ) {
# 				'background: #bfbfbf'
# 			      } elsif( $contents eq 'contig' ) {
# 				'color: gray'
# 			      }
			    }
			   );
  }
}

#lookup the given string as a versioned genbank accession, return the
#clone object if you can find it in genbank, and it has the same
#sequence as the latest sequence we have on file for that bac
sub lookup_and_match_genbank_accession {
  my ($accession,$err) = @_;

  unless($accession =~ /^[a-z]{2}\d+\.\d+$/i) {
    $err->("Identificador desconhecido: '$accession'");
    return;
  }

  my $gb = Bio::DB::GenBank->new;
  my $seq = eval{$gb->get_Seq_by_version($accession)}; #this dies if the acc doesn't exist
  warn $@ if $@;
  unless($seq) {
    $err->("'$accession' parece ser um acesso do GenBank, mas não foi encontrado no GenBank.");
    return;
  }

  #find the word in the description line that is our clone identifier
  my $clone;
  foreach my $word (split /\s+/,$seq->desc) {
    if( my $p = parse_clone_ident($word,'agi_bac_with_chrom','agi_bac') ) {
      $p->{match} = $accession;
      $clone = CXGN::Genomic::Clone->retrieve_from_parsed_name($p);
      last;
    }
  }
  unless($clone) {
    $err->("Não foi possível associar o acesso '$accession' do GenBank a um nome de clone. O campo DEFINITION desse registro inclui um nome de clone?");
    return;
  }

  unless($clone->latest_sequence_name) {
    $err->("O registro $accession do GenBank indica corresponder ao identificador de BAC do SGN ".$clone->clone_name_with_chromosome.", mas nenhuma sequência foi enviada ao SGN para esse clone. Envie a sequência ao SGN.");
    return;
  }

  #now make sure the clones have the same sequence
  my @clone_seqs = $clone->seq;
#  warn "checking our seq ".length($clone_seqs[0])." against their seq ".length($seq->seq);
  unless(@clone_seqs == 1 && compare_gb_and_sgn_seqs($seq->seq,$clone_seqs[0])) {
    $err->("A sequência de $accession no GenBank não corresponde à sequência do SGN para ".$clone->latest_sequence_name.". Atualize o SGN ou o GenBank para que as sequências correspondam ou use identificadores de sequência versionados do SGN (por exemplo, C01HBa0001A01.1).");
#    warn "seq for $accession is\n".$clone_seqs[0]
  }

  #if we get here, it all miraculously matched up
  return $clone;
}


#compare a genbank and an sgn sequence, allowing for X-masked
#nucleotides that may be present in the sgn sequence
sub compare_gb_and_sgn_seqs {
  my ($gb_seq,$sgn_seq) = @_;

  #easy if they're straight equal
  return 1 if $gb_seq eq $sgn_seq;

  #otherwise, do a match taking into account the X's in the SGN sequence

  return 0 unless
    length($gb_seq) == length($sgn_seq)
      && $sgn_seq =~ /[Xx]/;

  $gb_seq = lc $gb_seq;
  $sgn_seq = lc $sgn_seq;

  for(my $i=0;$i<length($gb_seq);$i++) {
    my $gb = substr($gb_seq,$i,1);
    my $sgn = substr($sgn_seq,$i,1);
    if($gb ne $sgn && $sgn ne 'x') {
      return 0;
    }
  }
  return 1;
}

#!/usr/bin/perl
use utf8;

use strict;
use warnings;

use CXGN::Page;
use File::Spec;
use CXGN::DB::Connection;
use CXGN::BlastWatch;

use CGI ();

use CatalystX::GlobalContext qw( $c );

my $page = CXGN::Page->new( "Resultados do BLAST Watch", "Adri");

my $cgi = CGI->new;

my $bw_query_id = $cgi->param('query');

my $dbh = CXGN::DB::Connection->new();

$c->throw( message => "No query chosen.", is_error => 0 ) unless $bw_query_id;

my $select = "SELECT sequence, program, database, matrix, evalue, num_results "
    . "FROM blastwatch_queries where blastwatch_queries_id = ?";
my $sth = $dbh->prepare($select);
$sth->execute($bw_query_id);
my (@v) = $sth->fetchrow();
$sth->finish;

my $results = CXGN::BlastWatch::get_results($dbh,$bw_query_id);

if (!$results) { &user_error("Invalid query.") }

website($page, $results,@v);

#---------------#

sub website {
    my ($page, $results,$sequence,$program,$database,$matrix,$evalue,$num_results) = @_;

    # force sequence to wrap                                                                                                                         
    
    my $length = length($sequence);
    my $wrap = 85;
    for (my $i = $wrap; $i < $length ; $i += $wrap + 1) {
	substr($sequence, $i, 0) = " ";
    }
    
    $page->header('Resultados do BLAST Watch','BLAST Watch Results');
    
    print <<EOF;

<p><strong>Sequência de consulta:</strong><br/>
$sequence</p>

<p><strong>Programa:</strong> $program</p>

<p><strong>Banco de dados:</strong> $database</p>

<p><strong>Substitution Matrix:</strong> $matrix</p>

<p><strong>Limiar esperado (e-value):</strong> $evalue</p>

<strong>Resultados:</strong>

EOF

if ($results ne "No results found.") {
    print <<TEXT;
    
    <table summary="" width="90%">
	<td><strong>Query</strong></td>
	<td><strong>Hit</strong></td>
        <td><strong>Início</strong></td>
	<td><strong>End</strong></td>
	<td><strong>E-value</strong></td>
	<td><strong>Score</strong></td>
	<td></td>
	</tr>
	$results
	</table>
	
TEXT
}

    else { print $results }

    $page->footer();
    
}

sub user_error {
    my ($page,$reason) = @_;
    
    $page->header();
    
    print <<EOF;
    <h4>Erro do BLAST Watch do SGN</h4>
	<p>$reason</p>
EOF

    $page->footer();
    exit(0);
}

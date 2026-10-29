use utf8;

=head1 NAME

t/integration/search.t - integration tests for generic search URLs

=head1 DESCRIPTION

Tests for search URLs

=head1 SYNOPSIS


=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use Modern::Perl;
use Test::Most;

use lib 't/lib';
use SGN::Test::Data qw/ create_test /;
use SGN::Test::WWW::Mechanize skip_cgi => 1;

my $mech = SGN::Test::WWW::Mechanize->new;

$mech->get_ok("/search/organisms");
$mech->content_like(qr!Organism/Taxon Search!);

$mech->get_ok("/search");
$mech->content_like(qr/Search/);

$mech->get_ok("/search/index.pl");
# $mech->content_like(qr/A database of in-situ/);

my $type_regex = {
    bacs                         => qr/Busca de clones genômicos/,
    directory                    => qr/Busca no diretório/,
    est                          => qr/Busca de ESTs/,
    est_library                  => qr/Busca de bibliotecas/,
    experiment                   => qr/Busca de expressão/,
    family                       => qr/Busca de famílias/,
    images                       => qr/Busca de imagens/,
    library                      => qr/Busca de bibliotecas/,
    loci                         => qr/Search Genes and Loci/,
    marker                       => qr/Localizações de mapas\/marcadores/,
    markers                      => qr/Opções de marcadores/,
    #phenotype                    => qr/Submit New Stock/,
    #phenotype_qtl_trait          => qr/Submit New Stock/,
    platform                     => qr/Busca de expressão/,
    qtl                          => qr/Search QTLs/,
    template_experiment_platform => qr/Busca de expressão/,
    trait                        => qr/Search and browse tree of traits/,
    unigene                      => qr/Busca de unigenes/,
    glossary                     => qr/Busca no glossário/,
};

$mech->get("/search/wombats");
is($mech->status,404,'/search/wombats is a 404');

$mech->get("/search/direct_search.pl?search=wombats");
is($mech->status,404,'/search/direct_search.pl?search=wombats is a 404');

for my $type (keys %$type_regex) {
    $mech->get_ok("/search/$type");
    my $regex = $type_regex->{$type};
    diag $mech->content;
    $mech->content_like($regex); 

    # the glossary search was never accessible via direct_search
    $mech->get_ok("/search/direct_search.pl?search=$type") if ($type ne 'glossary');
}

done_testing;

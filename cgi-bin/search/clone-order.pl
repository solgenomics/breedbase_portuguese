#!/usr/bin/perl -w
use utf8;
use strict;
use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Cookie;
my $dbh = CXGN::DB::Connection->new();
my $check_q = $dbh->prepare("SELECT order_routing_id from clone LEFT JOIN library USING (library_id) where clone_name=?");

our $page = CXGN::Page->new("Clone Shopping Cart", "Koni");

my ($clone_add) = $page->get_arguments("add_clone");

my $cart_contents = CXGN::Cookie::get_cookie("CloneCart");

if (!$cart_contents) {
  $cart_contents = "";
}

my @clones = split /,/,$cart_contents;
if ($clone_add) {
  push @clones, $clone_add;
}

# Note: An advantage of server-side statefulness here is not repeating this
#       everytime. This is typical of stateful/stateless tradeoff -- storing
#       state provides performance gains but at the expense of correctness and
#       increased complexity.
#
#       Future versions of this ordering thing may require server side state
#       due to the limitations of cookie size at the client.
my %ok_clones = ();
my %orders = ();
foreach my $clone_id ( @clones ) 
{
  $check_q->execute($clone_id);
  if ($check_q->rows()>0) {
    my ($order_routing_id) = $check_q->fetchrow_array();
    if (!$ok_clones{$clone_id}) {
      push @{$orders{$order_routing_id}}, $clone_id;
      $ok_clones{$clone_id} = 1;
    }
  }
}

# If we have valid clones, set the cookie.
if (keys(%ok_clones) > 0) {
  CXGN::Cookie::set_cookie("CloneCart",join(",",keys(%ok_clones)));
} else {
  CXGN::Cookie::set_cookie("CloneCart","");
  empty_cart();
}

if ($clone_add) {
  $page->client_redirect("/search/clone-order.pl");
  exit(0);
}

my @order_text = ();
foreach my $routing_id ( keys %orders ) {
  if ($routing_id == 1) { # TED
      push @order_text, ted_order_routing($orders{$routing_id});
  }
  elsif ($routing_id == 2) { # Kazusa
      push @order_text, kazusa_order_routing($orders{$routing_id});
  } else {
    $page->error_page("Clone solicitado, mas a função de encaminhamento de pedidos para \"$routing_id\" não está disponível");
  }

}

sub ted_order_routing {
  my ($clone_listref) = @_;
  my $clone_order = join(",",@{$clone_listref});
  my $text = <<EOF;
  <form method="post" action="/search/route-order.pl" target="_BLANK">
<input type="hidden" name="route_to" value="1" />
<input type="hidden" name="order_clones" value="$clone_order" />
<table summary="" cellpadding="2" cellspacing="2" border="0" align="center" width="100%">
<tr><td style="background-color: CCCCFF;" align="center">Os seguintes clones selecionados estão disponíveis por <b>TED</b></td></tr>
EOF
  foreach (@{$clone_listref}) {
    $text .= "<tr><td>$_</td></tr>";
  }

  $text .= <<EOF;
<tr><td style="background-color: CCCCFF;" align="center">
<button type="submit" name="route_order" value="Route Order">Encaminhar pedido</button>&nbsp;&nbsp;<button type="submit" name="route_order" value="Delete Order">Excluir pedido</button>
</td></tr></table></form>
EOF

  return $text;
}

sub kazusa_order_routing { 
    my ($clone_listref) = @_;
    my $clone_order = join(",", @{$clone_listref});
    my $clone_order_text = "Dear Kazusa, %0AI would like to order the following clones:%0A$clone_order%0A";
    my $text = <<EOF;
<form method="post" action="/search/route-order.pl" target="_BLANK">
<input type="hidden" name="route_to" value="1" />
<input type="hidden" name="order_clones" value="$clone_order" />
<table summary="" cellpadding="2" cellspacing="2" border="0" align="center" width="100%">
<tr><td style="background-color: CCCCFF;" align="center">Os seguintes clones selecionados estão disponíveis por <b>Kazusa</b></td></tr>
EOF
  foreach (@{$clone_listref}) {
    $text .= "<tr><td>$_</td></tr>";
  }

  $text .= <<EOF;
<tr><td style="background-color: CCCCFF;" align="center">
<a href="mailto:plantinfo\@kazusa.or.jp?subject=clone order&amp;body=$clone_order_text"><b>SOLICITAR CLONES (e-mail)</b></a>&nbsp;&nbsp;<button type="submit" name="route_order" value="Delete Order">Excluir pedido</button><br /><br />
<a href="http://www.kazusa.or.jp/clonereq/">Página de solicitação de clones de Kazusa</a> | <a href="http://www.kazusa.or.jp/clonereq/agreement.html">Kazusa Material Transfer Agreement</a>
</td></tr></table></form>

EOF
return $text;
}

$page->header();

print <<EOF;

<table summary="" width="80%" align="center" cellspacing="2" cellpadding="2" border="0">
<tr><td>
<p>O SGN pode montar uma lista de clones e encaminhar os pedidos aos responsáveis quando você terminar de selecioná-los. Para continuar a seleção, use o botão Voltar do navegador ou inicie uma <a href="/search/direct_search.pl">nova busca</a></p>
</td></tr>
<tr><td align="center"><b>Shopping Cart Contents</b></td></tr>
<tr><td>
<p />
@order_text
</td></tr>
<tr><td>
<p>
<b>Observe:</b> O SGN não processa pedidos de clones diretamente. Os clones selecionados são encaminhados aos responsáveis pelos botões de envio acima. Seu navegador <b>deve aceitar cookies</b> para que isso funcione. Use o botão Voltar para selecionar mais clones ou inicie uma nova busca pelos links acima.
</p>
</td></tr>
</table>
EOF

$page->footer();

sub empty_cart {

  $page->header();

  print <<EOF;

  <table summary="" border="0" width="80%" align="center">
  <tr><td align="center"><p>Não há clones de cDNA no carrinho.</td></tr>
  <tr><td align="center"><p>O navegador precisa aceitar cookies para solicitar clones pelo SGN.</p>
  <br /></td></tr>
  </table>

EOF

  $page->footer();

  exit 0;
}


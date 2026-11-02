#!/usr/bin/perl -w
use utf8;
use strict;
use warnings;

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::People;
use CXGN::People::Login;

my $page = CXGN::Page->new( "solpeople User Confirmation", "Koni" );
my $dbh = CXGN::DB::Connection->new();

my ( $username, $confirm_code ) = $page->get_arguments( "username", "confirm" );
my $sp = CXGN::People::Login->get_login( $dbh, $username );

if ( !$sp ) {
    confirm_failure($page, "Username \"$username\" was not found.");
}

if ( !$sp->get_confirm_code() ) {
    confirm_failure($page, "No confirmation is required for user <b>$username</b>. Esta conta já foi confirmada. <p><a href='/user/login?goto_url=%2F'>[Página de entrada]</a></p>");
}

if ( $sp->get_confirm_code() ne $confirm_code ) {
    confirm_failure($page, "Confirmation code is not valid!\n");
}

$sp->set_disabled(undef);
$sp->set_confirm_code(undef);
$sp->set_private_email( $sp->get_pending_email() );

$sp->store();

$page->header();

print <<EOF;

<p>Confirmação concluída para o usuário <b>$username</b>.</p>

<p><a href="/user/login?goto_url=%2F">[Página de entrada]</a></p>
<br />

EOF

$page->footer();

sub confirm_failure {
    my ($page, $reason) = @_;

    $page->header();

    print <<EOF;

  <p>Não foi possível processar esta solicitação de confirmação. Confira se a URL completa de confirmação foi colada corretamente no navegador.</p>

  <p><b>Reason:</b> $reason</p>

  <br />

EOF

    $page->footer();

    exit 0;
}

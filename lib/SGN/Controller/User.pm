
package SGN::Controller::User;

use utf8;
use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub login :Path('/user/login') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    $c->response->headers->header( 'Access-Control-Allow-Headers' => 'DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Content-Range,Range,Authorization');
    $c->stash->{goto_url} = $c->req->param("goto_url");

    print STDERR "GOTOURL=".$c->stash->{goto_url}."\n";
    $c->stash->{template} = '/user/login.mas';
}

sub new_user :Path('/user/new') Args(0) {
    my $self = shift;
    my $c = shift;

    # Redirect to the login page and display the new user form
    $c->res->redirect('/user/login?goto_url=/&new_user=1');
    $c->detach();
}

sub update_account :Path('/user/update') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user()) {
	$c->res->redirect('/user/login');
	return;
    }

    $c->stash->{logged_in_username} = $c->user()->get_username();
    $c->stash->{private_email} = $c->user()->get_private_email();

    $c->stash->{template} = '/user/change_account.mas';
}

sub confirm_user :Path('/user/confirm') Args(0) {
    my $self = shift;
    my $c = shift;

    my $confirm_code = $c->req->param('confirm_code');
    my $username = $c->req->param('username');

    if ($c->config->{disable_account_confirm}) {
        $c->stash->{template} = '/generic_message.mas';
        $c->stash->{message} = 'A confirmação de contas está desativada neste site. Entre em contato com nm529@cornell.edu para confirmar sua conta.';
        return;
    }

    my $sp = CXGN::People::Login->get_login( $c->dbc()->dbh(), $username );

    if ( !$sp ) {
	confirm_failure($c, "O nome de usuário \"$username\" não foi encontrado.");
	return;
    }

    if ( !$sp->get_confirm_code() ) {
	confirm_failure($c, "O usuário <b>$username</b> não precisa de confirmação. Esta conta já foi confirmada. <p><a href='/user/login'>[Página de login]</a></p>");
	return;
    }

    if ( $sp->get_confirm_code() ne $confirm_code ) {
	confirm_failure($c, "O código de confirmação não é válido.\n");
	return;
    }

    $sp->set_disabled(undef);
    $sp->set_confirm_code(undef);
    $sp->set_private_email( $sp->get_pending_email() );

    $sp->store();

    # Send confirmation to user, if manual confirmation is enabled
    if ( $c->config->{user_registration_admin_confirmation} && $c->config->{user_registration_admin_confirmation_email} ) {
        my $host = $c->config->{main_production_site_url};
        my $project_name = $c->config->{project_name};
        my $subject="[$project_name] Nova conta confirmada";
        my $body=<<END_HEREDOC;

Sua nova conta no $project_name, com o nome de usuário \"$username\", foi confirmada.

Agora você pode entrar usando os dados da sua conta:
$host

Obrigado,
Equipe $project_name

*NÃO* responda a esta mensagem. Se tiver dificuldades para entrar na conta ou
alguma dúvida, use o formulário de contato:
$host/contact/form

END_HEREDOC
        CXGN::Contact::send_email($subject,$body,$sp->get_pending_email());
    }

    $c->stash->{template} = '/generic_message.mas';
    $c->stash->{message} = "O nome de usuário <b>$username</b> foi confirmado com sucesso.";
}

sub confirm_failure {
    my $c = shift;
    my $reason = shift;

    $c->stash->{template} = '/generic_message.mas';
    $c->stash->{message} = "Este código de confirmação é inválido. Verifique se o endereço completo de confirmação foi colado corretamente no navegador. ($reason)";

}

sub reset_password_form :Path('/user/reset_password_form') Args(0) {
    my $self = shift;
    my $c = shift;

    my $token = $c->req->param('reset_password_token');

    my $person_id;
    if ($token) {
	my $person_id = CXGN::People::Login->get_login_by_token($c->dbc->dbh(), $token);
	if (!$person_id) {
	    $c->stash->{message} = "O link informado para redefinir a senha é inválido. Tente novamente com outro link.";
	    $c->stash->{template} = '/generic_message.mas';
	    return;
	}

	my $person = CXGN::People::Person->new($c->dbc->dbh(), $person_id);
	$c->stash->{token} = $token;
	$c->stash->{person_id} = $person_id;
	$c->stash->{username} = $person->get_username();
	$c->stash->{template} = '/user/reset_password_form.mas';
    }
    else {
	$c->stash->{message} = "Nenhum token foi informado. Tente novamente.";
	$c->stash->{template} = '/generic_message.mas';
    }

}

sub quick_create_account :Path('/user/admin/quick_create_account') {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
	$c->forward('/user/login');
	return;
    }

    $c->stash->{template} = '/user/quick_create_account.mas';
}



1;

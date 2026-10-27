
package SGN::Controller::AJAX::User;

use utf8;
use Moose;
use JSON;
use URI::FromHash 'uri';
use IO::File;
use Data::Dumper;
use HTML::Entities;
use CXGN::People::Roles;
use CXGN::BreedingProgram;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub login : Path('/ajax/user/login') Args(0) {
    my $self = shift;
    my $c = shift;

    my $username = $c->req->param("username");
    my $password = $c->req->param("password");
    my $goto_url = $c->req->param("goto_url");

    $goto_url = $c->req->referer if $goto_url eq '/';
    print STDERR "Goto URL = $goto_url\n";

    my $login = CXGN::Login->new($c->dbc->dbh());
    my $login_info = $login->login_user($username, $password);

    if (exists($login_info->{incorrect_password}) && $login_info->{incorrect_password} == 1) {
	$c->stash->{rest} = { error => "O nome de usuário ou a senha está incorreto. Tente novamente." };
	return;
    }
    elsif (exists($login_info->{account_disabled}) && $login_info->{account_disabled}) {
	my %translated_reasons = (
	    'unconfirmed account'    => 'conta não confirmada',
	    'administrator action'   => 'ação administrativa',
	);
	my $reason = $translated_reasons{$login_info->{account_disabled}} || 'motivo administrativo';
	$c->stash->{rest} = { error => "Esta conta foi desativada pelo seguinte motivo: $reason. Entre em contato com o administrador do banco de dados para reativá-la." };
	return;
    }
    else {
	$c->stash->{rest} = {
	    message => "Acesso realizado com sucesso.",
	    goto_url => $goto_url
	};
    }
}

sub logout :Path('/ajax/user/logout') Args(0) {
    my $self = shift;
    my $c = shift;

    my $login = CXGN::Login->new($c->dbc->dbh());
    $login->logout_user();

    $c->stash->{rest} = { message => "Usuário desconectado com sucesso." };
}

sub logout_externally :Path('/ajax/user/logout_externally') QueryParam('redirect_uri') {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    $c->response->headers->header( 'Access-Control-Allow-Headers' => 'DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Content-Range,Range,Authorization');
#    my $redirect_uri = $c->request->param( 'redirect_uri' );
    my $login = CXGN::Login->new($c->dbc->dbh());
    $login->logout_user();
#    $c->stash->{redirect_uri} = $redirect_uri;
#    $c->stash->{template} = '/site/toolbar/logout_externally.mas';
    $c->stash->{rest} = { message => "Usuário desconectado com sucesso." };
}

sub new_account :Path('/ajax/user/new') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    print STDERR "Adding new account...\n";
    if ($c->config->{is_mirror}) {
	$c->stash->{template} = '/system_message.mas';
	$c->stash->{message} = "Este site é um espelho e não permite adicionar usuários. Acesse o site principal para criar uma conta.";
	return;
    }


    my ($first_name, $last_name, $username, $password, $confirm_password, $email_address, $organization, $breeding_program_ids)
	= map { $c->req->params->{$_} } (qw|first_name last_name username password confirm_password email_address organization breeding_programs|);

    # Set organization from breeding programs, if provided
    if ($breeding_program_ids && ref($breeding_program_ids) ne 'ARRAY') {
        $breeding_program_ids = [$breeding_program_ids];
    }
    my @breeding_program_names;
    if ( !$organization && $breeding_program_ids ) {
        foreach my $breeding_program_id (@$breeding_program_ids) {
            my $breeding_program = CXGN::BreedingProgram->new({ schema=> $schema , program_id => $breeding_program_id });
            push(@breeding_program_names, $breeding_program->get_name());
        }
        $organization = join(', ', @breeding_program_names);
    }

    if ($username) {
	#
	# check password properties...
	#
	my @fail = ();
	if (length($username) < 7) {
	    push @fail, "O nome de usuário é muito curto. Ele deve ter pelo menos 7 caracteres";
	} elsif ( $username =~ /\s/ ) {
        push @fail, "O nome de usuário não pode conter espaços";
    } else {
	    # does user already exist?
	    #
	    my $existing_login = CXGN::People::Login -> get_login($c->dbc()->dbh(), $username);

	    if ($existing_login->get_username()) {
		push @fail, "O nome de usuário \"$username\" já está em uso. Escolha outro nome";
	    }

	}
	if (length($password) < 7) {
	    push @fail, "A senha é muito curta. Ela deve ter pelo menos 7 caracteres";
	}
	if ("$password" ne "$confirm_password") {
	    push @fail, "A senha e sua confirmação não coincidem";
	}

	if ($password eq $username) {
	    push @fail, "A senha não pode ser igual ao nome de usuário";
	}
	if ($email_address !~ m/[^\@]+\@[^\@]+/) {
	    push @fail, "O endereço de e-mail é inválido";
	}
    if ( $email_address ) {
        my @person_ids = CXGN::People::Login->get_login_by_email($c->dbc()->dbh(), $email_address);
        if ( scalar(@person_ids) > 0 ) {
            push @fail, "O endereço de e-mail já está associado a uma conta";
        }
    }
	unless($first_name) {
	    push @fail,"Informe o nome ou a inicial";
	}
	unless($last_name) {
	    push @fail,"Informe o sobrenome";
	}

	if (@fail) {
	    $c->stash->{rest} = { error => "Não foi possível criar a conta pelos seguintes motivos: ".(join ", ", @fail) };
	    return;
	}
    }

    my $confirm_code = $self->tempname();
    my $new_user = CXGN::People::Login->new($c->dbc->dbh());
    $new_user -> set_username($username);
    $new_user -> set_pending_email($email_address);
    $new_user -> set_disabled('unconfirmed account');
    $new_user -> set_organization($organization);
    $new_user -> store();

    print STDERR "Generated sp_person_id ".$new_user->get_sp_person_id()."\n";
    print STDERR "Update password and confirm code...\n";
    $new_user->update_password($password);
    $new_user->update_confirm_code($confirm_code);

    print STDERR "Store Person object...\n";
    #this is being added because the person object still uses two different objects, despite the fact that we've merged the tables
    my $person_id=$new_user->get_sp_person_id();
    my $new_person=CXGN::People::Person->new($c->dbc->dbh(),$person_id);
    $new_person->set_first_name($first_name);
    $new_person->set_last_name($last_name);
    $new_person->store();

    # Add user to breeding programs
    if ( $c->config->{user_registration_join_breeding_programs} ) {
        my $person_roles = CXGN::People::Roles->new({ people_schema => $people_schema });
        my $sp_roles = $person_roles->get_sp_roles();
        my %roles = map {$_->[0] => $_->[1]} @$sp_roles;
        foreach my $breeding_program_name (@breeding_program_names) {
            my $role_id = $roles{$breeding_program_name};
            if ( !$role_id ) {
		        my $error = $person_roles->add_sp_role($breeding_program_name);
                if ( $error ) {
                    print STDERR "ERROR: Could not create role $breeding_program_name [$error]\n";
                }
                else {
                    my $new_sp_roles = $person_roles->get_sp_roles();
                    my %new_roles = map {$_->[0] => $_->[1]} @$new_sp_roles;
                    $role_id = $new_roles{$breeding_program_name};
                }
            }
            if ( $role_id ) {
                my $add_role = $person_roles->add_sp_person_role($person_id, $role_id);
            }
        }
    }

    # Add additional user details for admin confirmation
    my $user_details = '';
    if ( $c->config->{user_registration_admin_confirmation} && $c->config->{user_registration_admin_confirmation_email} ) {
        $user_details .= "Nome: $first_name $last_name\n";
        $user_details .= "E-mail: $email_address\n";
        $user_details .= "Organização(ões): $organization\n";
    }

    my $host = $c->config->{main_production_site_url};
    my $project_name = $c->config->{project_name};
    my $subject="[$project_name] Confirmação de endereço de e-mail";
    my $body=<<END_HEREDOC;

Esta mensagem foi enviada para confirmar o endereço de e-mail do usuário
\"$username\"
$user_details

Clique no link abaixo (ou copie e cole no navegador) para confirmar sua conta
e seu endereço de e-mail:

$host/user/confirm?username=$username&confirm_code=$confirm_code

Obrigado,
Equipe $project_name

*NÃO* responda a esta mensagem. Se tiver dificuldades para confirmar seu e-mail
ou alguma dúvida, use o formulário de contato:
$host/contact/form

END_HEREDOC

    # Send confirmation email to admin
    my $message = "";
    if ( $c->config->{user_registration_admin_confirmation} && $c->config->{user_registration_admin_confirmation_email} ) {
        CXGN::Contact::send_email($subject,$body,'user_registration_admin_confirmation_email');
        $message = "Sua conta foi criada, mas precisa ser confirmada pelos administradores do site. Você receberá um e-mail após a confirmação.";
    }

    # Send confirmation email to user
    else {
        CXGN::Contact::send_email($subject,$body,$email_address);
        $message = "Para continuar, confirme que podemos entrar em contato pelo endereço \"$email_address\". Enviamos uma mensagem com o link de confirmação. Verifique seu e-mail e use esse link para confirmar o endereço.";
    }

    $c->stash->{rest} = {
        message => "A conta foi criada com o nome de usuário \"$username\".\n\n$message\n\nVocê poderá entrar após a confirmação da conta."
    };
}


sub change_account_info_action :Path('/ajax/user/update') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user() ) {
        $c->stash->{rest} = { error => "Você precisa estar conectado para usar esta página." };
	return;
    }

    my $person = CXGN::People::Login->new($c->dbc->dbh(), $c->user->get_sp_person_id());

#    my ($current_password, $change_username, $change_password, $change_email) = $c->req->param({qw(current_password change_username change_password change_email)});

    my $args = $c->req->params();

    if (!$args->{change_password} && ! $args->{change_username} && !$args->{change_email}) {
	my $error = "Nenhuma ação foi solicitada. Marque no formulário os campos que deseja atualizar e informe os novos dados.";
	print STDERR $error;
	$c->stash->{rest} =  { error => $error };
	return;
    }

    chomp($args->{current_password});
    if (! $person->verify_password($args->{current_password})) {
	my $error = "A senha atual não corresponde aos registros da SGN.";
	print STDERR $error;
	$c->stash->{rest} = { error => "$error" };
	return;
    }

    # Check for error conditions in all changes, before making any of them.
    # Otherwise, we could end up making some changes and then failing on later
    # ones. The user would then push the back button and their information may
    # be different now but they will probably assume no changes were made. This
    # is most troublesome if the current password changes.
    #
    if ($args->{change_username}) {
	#unless change_username is set, new_username won't be in the args hash because of the prestore test
	my $new_username = $args->{new_username};
	if(length($new_username) < 7) {
	    my $error = "O nome de usuário deve ter pelo menos 7 caracteres.";
	    print STDERR $error;
	    $c->stash->{rest} = { error => $error  };
	    return;
	}

	my $other_user = CXGN::People::Login->get_login($c->dbc->dbh(), $new_username);
	if (defined $other_user->get_sp_person_id() &&
	    ($person -> get_sp_person_id() != $other_user->get_sp_person_id())) {
	    print STDERR "Username alread in use.\n";
	    $c->stash->{rest} = { error =>  "O nome de usuário \"$new_username\" já está em uso. Escolha outro nome." };
	    return;
	}

	$person->set_username($new_username);
	$person->store();
    }

    if ($args->{change_password}) {
	#unless change_password is set, new_password won't be in the args hash because of the prestore test
	my ($new_password, $confirm_password) = ($args->{new_password}, $args->{confirm_password});
	if(length($args->{new_password}) < 7) {
	    print STDERR "Password too short\n";
	    $c->stash->{rest} = { error => "A senha deve ter pelo menos 7 caracteres. Tente novamente." };
	    return;
	}
	#format check
	if($args->{new_password} !~ /^[a-zA-Z0-9~!@#$^&*_.=:;<>?]+$/) {
	    print STDERR "Illegal characters in password\n";
	    $c->stash->{rest} = { error => "Ocorreu um erro. Volte à página anterior e tente novamente. A senha não pode conter espaços nem estes símbolos: <u><b>` ( ) [ ] { } - + ' \" / \\ , |</b></u>." };
	    return;
	}
	if($args->{new_password} ne $args->{confirm_password}) {
	    print STDERR "Password don't match.\n";
	    $c->stash->{rest} = { error => "As novas senhas não coincidem. Informe a mesma senha duas vezes para confirmá-la." };
	    return;
	}

	print STDERR "Saving new password to the database\n";
	$person->update_password($args->{new_password});
    }

    my $user_private_email = $c->user->get_private_email();
    if($args->{change_email}) {
	#unless change_email is set, private_email won't be in the args hash because of the prestore test
	my ($private_email, $confirm_email) = ($args->{private_email}, $args->{confirm_email});
	if($private_email !~ m/^[a-zA-Z0-9_.-]+@[a-zA-Z0-9_.-]+$/) {
	    print STDERR "Invalid email address\n";
	    $c->stash->{rest} = { error => "Ocorreu um erro. Volte à página anterior e tente novamente. O endereço \"$private_email\" não parece ser um e-mail válido." };
	    return;
	}
	if($private_email ne $confirm_email) {
	    print STDERR "Emails don't match\n";
	    $c->stash->{rest} = { error => "Ocorreu um erro. Volte à página anterior e tente novamente. Os novos endereços de e-mail não coincidem. Informe o mesmo endereço duas vezes para confirmá-lo." };
	    return;
	}

	print STDERR "Saving private email '$private_email' to the database\n";
	$person->set_private_email($private_email);
	my $confirm_code = $self->tempname();
	$person->set_confirm_code($confirm_code);
	$person->store();

	$user_private_email = $private_email;

	$self->send_confirmation_email($args->{username}, $user_private_email, $confirm_code, $c->config->{main_production_site_url});

    }

    $c->stash->{rest} = { message => "Atualização concluída com sucesso." };

}

sub send_confirmation_email {
    my ($self, $username, $private_email, $confirm_code, $host) = @_;
    my $subject = "[SGN] Confirmação de endereço de e-mail";

    my $body = <<END_HEREDOC;

Você solicitou uma conta no site $host.

*NÃO* responda a esta mensagem. O endereço de resposta não é válido.
Use o formulário de contato em $host/contact/form.

Esta mensagem foi enviada para confirmar o endereço de e-mail do usuário
\"$username\".

Clique no link abaixo (ou copie e cole no navegador) para confirmar sua conta
e seu endereço de e-mail:

  $host/user/confirm?username=$username&confirm=$confirm_code

Obrigado.
Sol Genomics Network
END_HEREDOC

   CXGN::Contact::send_email($subject, $body, $private_email);
}


sub forgot_username : Path('/ajax/user/forgot_username') Args(0) {
    my $self = shift;
    my $c = shift;

    my $email = $c->req->param('forgot_username_email');
    my @person_ids = CXGN::People::Login->get_login_by_email($c->dbc->dbh(), $email);
    $self->send_forgot_username_email_message($c, $email, \@person_ids);

    $c->stash->{rest} = {
        message => "Solicitação enviada. Se houver uma conta neste banco de dados associada ao e-mail informado, você receberá uma mensagem com o nome de usuário. Caso contrário, nenhuma mensagem será enviada."
    };
}


sub reset_password :Path('/ajax/user/reset_password') Args(0) {
    my $self = shift;
    my $c = shift;

    my $email = $c->req->param('password_reset_email');

    my @person_ids = CXGN::People::Login->get_login_by_email($c->dbc->dbh(), $email);
    foreach my $pid (@person_ids) {
        my $email_reset_token = $self->tempname();
        my $reset_link = $c->config->{main_production_site_url}."/user/reset_password_form?reset_password_token=$email_reset_token";
        my $person = CXGN::People::Login->new( $c->dbc->dbh(), $pid);
        $person->update_confirm_code($email_reset_token);
        $self->send_reset_email_message($c, $pid, $email, $reset_link, $person->{username});
    }

    $c->stash->{rest} = {
        message => "Solicitação enviada. Se houver uma conta neste banco de dados associada ao e-mail informado, você receberá uma mensagem com o link para redefinir a senha. Caso contrário, nenhuma mensagem será enviada.",
    };
}

sub process_reset_password_form :Path('/ajax/user/process_reset_password') Args(0) {
    my $self = shift;
    my $c = shift;

    my $token = $c->req->param("token");
    my $confirm_password = $c->req->param("confirm_password");
    my $new_password = $c->req->param("new_password");

    if (length($new_password) < 7) {
        $c->stash->{rest} = { error => "A senha é muito curta. Ela deve ter pelo menos 7 caracteres." };
        $c->detach();
    }

    if ($confirm_password ne $new_password){
        $c->stash->{rest} = { error => "Informe a mesma senha no campo de confirmação." };
        $c->detach();
    }

    eval {
        my $q = "SELECT sp_person_id FROM sgn_people.sp_person WHERE confirm_code=?;";
        my $h = $c->dbc->dbh()->prepare($q);
        $h->execute($token);
        my ($person_id) = $h->fetchrow_array();
        my $login = CXGN::People::Login->new($c->dbc->dbh(), $person_id);
        $login->update_password($new_password);
        $login->update_confirm_code("");
    };
    if ($@) {
        print STDERR "Password reset failed: $@\n";
        $c->stash->{rest} = { error => "Não foi possível redefinir a senha. Tente novamente ou entre em contato com o administrador." };
    }
    else {
        $c->stash->{rest} = { message => "A senha foi atualizada com sucesso." };
    }
}


sub send_forgot_username_email_message {
    my $self = shift;
    my $c = shift;
    my $email = shift;
    my $person_ids = shift;

    my @usernames;
    foreach my $pid (@$person_ids) {
        my $person = CXGN::People::Login->new( $c->dbc->dbh(), $pid);
        push(@usernames, $person->get_username());
    }

    # Only send a message if there is an account associated with the specified email address
    if ( @usernames > 0 ) {
        my $username_message = "Os seguintes nomes de usuário estão associados ao seu endereço de e-mail: " . join(', ', @usernames);

        my $project_name = $c->config->{project_name};
        my $subject = "[$project_name] Recuperação do nome de usuário";
        my $main_url = $c->config->{main_production_site_url};

        my $body = <<END_HEREDOC;

Olá,

Você solicitou os nomes de usuário das contas associadas a este endereço de e-mail em $main_url.

$username_message

Se você não fez esta solicitação, entre em contato conosco.

Para falar conosco, *NÃO* responda a esta mensagem. Use o formulário de contato ($main_url/contact/form).

Obrigado.

Equipe $project_name

END_HEREDOC

        CXGN::Contact::send_email($subject, $body, $email);
    }
}

sub send_reset_email_message {
    my $self = shift;
    my $c = shift;
    my $pid = shift;
    my $private_email = shift;
    my $reset_link = shift;
    my $person = shift;

    my $project_name = $c->config->{project_name};
    my $subject = "[$project_name] Redefinição de senha";
    my $main_url = $c->config->{main_production_site_url};

    my $body = <<END_HEREDOC;

Olá,

O usuário $person solicitou a redefinição de senha em $main_url.

Se você não fez esta solicitação, entre em contato conosco.

Para falar conosco, *NÃO* responda a esta mensagem. Use o formulário de contato ($main_url/contact/form).

Use o link abaixo para redefinir sua senha. Você pode clicar nele ou copiá-lo e colá-lo no navegador:

$reset_link

Obrigado.

Equipe $main_url

END_HEREDOC

   CXGN::Contact::send_email($subject, $body, $private_email);
}

sub tempname {
    my $self = shift;
    my $rand_string = "";
    my $dev_urandom = IO::File->new("</dev/urandom") || print STDERR "Can't open /dev/urandom";
    $dev_urandom->read( $rand_string, 16 );
    my @bytes = unpack( "C16", $rand_string );
    $rand_string = "";
    foreach (@bytes) {
        $_ %= 62;
        if ( $_ < 26 ) {
            $rand_string .= chr( 65 + $_ );
        }
        elsif ( $_ < 52 ) {
            $rand_string .= chr( 97 + ( $_ - 26 ) );
        }
        else {
            $rand_string .= chr( 48 + ( $_ - 52 ) );
        }
    }
    return $rand_string;
}

sub get_login_button_html :Path('/ajax/user/login_button_html') Args(0) {
    my $self = shift;
    my $c = shift;
    eval {
	my $production_site = $c->config->{main_production_site_url};
	my $html = "";
	# if the site is a mirror, gray out the login/logout links
	if( $c->config->{'is_mirror'} ) {
	    print STDERR "generating login button for mirror site...\n";
	    $html = <<HTML;
	    <a style="line-height: 1.2; text-decoration: underline; background: none" href="$production_site" title="entrar no site principal">site principal</a>
	} elsif ( $c->config->{disable_login} ) {
	    <li class="dropdown">
		<div class="btn-group" role="group" aria-label="..." style="height:34px; margin: 1px 0px 0px 0px" >
		<button class="btn btn-primary disabled" type="button" style="margin: 7px 7px 0px 0px">Entrar</button>
		</div>
		</li>

HTML

    } elsif ( $c->req->uri->path_query =~ "logout=yes") {
	print STDERR "generating login button for logout...\n";
	$html = <<HTML;
  <li class="dropdown">
      <div class="btn-group" role="group" aria-label="..." style="height:34px; margin: 1px 0px 0px 0px" >
	<a href="/user/login">
          <button class="btn btn-primary" type="button" style="margin: 7px 7px 0px 0px">Entrar</button>
	</a>
      </div>
  </li>
HTML

} elsif ( $c->user_exists ) {
    print STDERR "Generate login button for logged in user...\n";
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $username = $c->user->get_username();
    $html = <<HTML;
    <div class="btn-group" role="group" aria-label="..." style="height:34px; margin: 1px 3px 0px 0px">
        <button id="navbar_profile" class="btn btn-primary" type="button" onclick='location.href="/solpeople/profile/$sp_person_id"' style="margin: 7px 0px 0px 0px" title="Meu perfil">$username</button>
        <button id="navbar_lists" name="lists_link" class="btn btn-info" style="margin:7px 0px 0px 0px" type="button" title="Listas" onClick="show_lists();">
            <span class="glyphicon glyphicon-align-justify" ></span>&nbsp;<span class="hidden-sm">Listas</span>
        </button>
        <button id="navbar_datasets" name="lists_link" class="btn btn-info" style="margin:7px 0px 0px 0px" type="button" title="Conjuntos de dados" onClick="window.location='/search/datasets';">
            <span class="glyphicon glyphicon-list" style="transform: rotate(90deg)"></span>&nbsp;<span class="hidden-sm">Dados</span>
        </button>
        <button id="navbar_personal_calendar" name="personal_calendar_link" class="btn btn-primary" style="margin:7px 0px 0px 0px" type="button" title="Seu calendário">
            Calendário&nbsp;<span class="glyphicon glyphicon-calendar" ></span>
        </button>
        <button id="navbar_logout" class="btn btn-default glyphicon glyphicon-log-out" style="margin:6px 0px 0px 0px" type="button" onclick="logout();" title="Sair"></button>
      </div>
HTML

  } else {
      print STDERR "generating regular login button..\n";
      $html = qq |
      <li class="dropdown">
        <div class="btn-group" role="group" aria-label="..." style="height:34px; margin: 1px 0px 0px 0px" >
            <button id="site_login_button" name="site_login_button" class="btn btn-primary" type="button" style="margin: 7px 7px 0px 0px; position-absolute: 10,10,100,10">Entrar</button>
        </div>
      </li>
 |;

};
	if ($@) {
	    print STDERR "ERROR: $@\n";
	    $c->stash->{rest} = { error => $@ };
	}
	return $c->stash->{rest} = { html => $html, logged_in => $c->user_exists };
    }
}

sub quick_create_user :Path('/ajax/user/quick_create_account') Args(0) {
    my $self = shift;
    my $c = shift;

     if (!$c->user()) {
	$c->stash->{rest} = { error => "Você precisa estar conectado para usar esta funcionalidade." };
	return;
    }

    if (!$c->user()->check_roles("curator")) {
	$c->stash->{rest} = { error => "Você não possui permissão para usar esta funcionalidade." };
	return;
    }
    my $logged_in_person_id = $c->user()->get_sp_person_id();

    my $logged_in_user=CXGN::People::Person->new($c->dbc->dbh(), $logged_in_person_id);
    $logged_in_person_id=$logged_in_user->get_sp_person_id();
    my $logged_in_username=$logged_in_user->get_first_name()." ".$logged_in_user->get_last_name();
    my $logged_in_user_type=$logged_in_user->get_user_type();

    my ($username, $password, $confirm_password, $email_address, $new_user_type, $first_name, $last_name) =
	map { print STDERR $_." ".$c->req->param($_)."\n"; $c->req->param($_) } qw | username password confirm_password confirm_email user_type first_name last_name |;

    print STDERR "$username, $password, $confirm_password, $email_address, $new_user_type, $first_name, $last_name\n";

    my $new_user_login=CXGN::People::Login->new($c->dbc->dbh);

    if ($username) {
        my @fail=();

	if(length($username)<7){push @fail,"O nome de usuário é muito curto. Ele deve ter pelo menos 7 caracteres";}
        my $existing_login=CXGN::People::Login->get_login($c->dbc->dbh, $username);

        if($existing_login->get_username()){push @fail,"O nome de usuário \"$username\" já está em uso. Escolha outro nome.";}

	if(length($password)<7){push @fail,"A senha é muito curta. Ela deve ter pelo menos 7 caracteres";}

	if("$password" ne "$confirm_password"){push @fail,"A senha e sua confirmação não coincidem.";}

	if($password eq $username){push @fail,"A senha não pode ser igual ao nome de usuário.";}

	if($new_user_type ne 'user' and $new_user_type ne 'sequencer' and $new_user_type ne 'submitter'){
	    push @fail,"Não é possível criar um usuário do tipo \"$new_user_type\" pela interface web.";}
        if(@fail)
        {
            my $fail_str="";
            foreach(@fail)
            {
                $fail_str .= "<li>$_</li>\n"
            }
	    $c->stash->{rest} = { error => $fail_str };
	    return;

        }
    }

    my $encoded_username = encode_entities($username);
    print STDERR "USERNAME: $username. ENCODED: $encoded_username\n";
    $new_user_login->set_username($encoded_username);
    $new_user_login->set_private_email(encode_entities($email_address));
    $new_user_login->set_pending_email(encode_entities($email_address));
    $new_user_login->set_password($password);

    $new_user_login->store();

    my $new_user_person_id=$new_user_login->get_sp_person_id();
    my $new_user = CXGN::People::Person->new($c->dbc->dbh, $new_user_person_id);

    eval {

	$new_user->set_contact_email(encode_entities($email_address));
	$new_user->set_user_type(encode_entities($new_user_type));
	$new_user->set_first_name(encode_entities($first_name));
	$new_user->set_last_name(encode_entities($last_name));

	$new_user->store();
    };

    if ($@) {
	print STDERR "Quick account creation failed: $@\n";
	$c->stash->{rest} = { html => "Ocorreu um erro ao criar a conta." };
    }
    else {
	$c->stash->{rest} = { html => "<center><h4>Conta criada com sucesso para $first_name $last_name</h4><a href=\"/user/admin/quick_create_account\">Criar outra conta" };
    }
}


1;

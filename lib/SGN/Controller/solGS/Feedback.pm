
package SGN::Controller::solGS::Feedback;
use utf8;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }


sub submission_feedback : Path('/solgs/submission/feedback/') Args() {
    my ( $self, $c ) = @_;
    
    if ($c->user) {
        my $job_type = $c->req->param('job');
        my $msg = $self->message_content($c, $job_type);
        $c->stash->{message} = $msg;
        $c->stash->{template} = "/generic_message.mas";
    } else {
        $c->controller('solGS::Utils')->require_login($c);
    }

}

sub message_content {
    my ($self, $c, $job_type) = @_;

    $job_type =~ s/[_|-]/ /g;
    $job_type = lc($job_type);

    my $user_id  = $c->user()->get_object()->get_sp_person_id();
    my $profile_link = "<a href=\"/solpeople/profile/$user_id\">sua página de perfil</a>";

    my $referer  = $c->req->referer;
    my $back_link = "<a href=\"$referer\">[ Voltar ]</a>";
    
    my $msg = "<p>Sua tarefa de $job_type foi enviada.</p>"
      . "<p>Você receberá um e-mail quando ela for concluída,  " 
      . "o que pode levar algumas horas. Se o e-mail não estiver na sua caixa de entrada, "
      . "verifique também sua pasta de spam.</p>"
      . "<p>Como alternativa, você também pode verificar o status da tarefa em $profile_link."
      . "<p>$back_link</p>";

    return $msg;

}

1;
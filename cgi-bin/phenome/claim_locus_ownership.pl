use utf8;

use strict;
use warnings;

use CXGN::Page;
use CXGN::Login;
use CXGN::People;
use CXGN::Contact;
use CXGN::Phenome::Locus;

use CatalystX::GlobalContext qw( $c );

my $dbh = $c->dbc->dbh;

my $page=CXGN::Page->new("claim_locus_ownership.pl","Naama");
my %args=$page->get_all_encoded_arguments();
my $locus_id=$args{locus_id};
my $locus=CXGN::Phenome::Locus->new($dbh, $locus_id); 
my $sp_person_id = CXGN::Login->new($dbh)->verify_session();

my @owners= $locus->get_owners();

my $user = CXGN::People::Person -> new($dbh, $sp_person_id);
if ((grep { $_ =~ /^$sp_person_id$/ } @owners) ) {
    $page->header();
    print <<HEREDOC;
    
<h3>Você já é o proprietário do locus.<br>
    Na próxima vez, clique no link de entrada no canto superior direito de qualquer página do SGN.<br><br>
<a href="/locus/$locus_id/view">Voltar</a> à página do locus.</h3>

HEREDOC
    $page->footer();
    exit();
}

my $username=$user->get_first_name()." ".$user->get_last_name();
my $usermail=$user->get_private_email();
my $replyto= 'sgn-feedback@sgn.cornell.edu';


my $subject="[Locus ownership] Request editor privileges for locus $locus_id";
my $fdbk_body="$username has requested to obtain ownership for locus $locus_id\nsp_person_id = $sp_person_id, $usermail";


my $user_body= "Dear $username,\n\nYour request for obtaining editor privileges for SGN locus ID $locus_id will be processed shortly.\nA confirmation email will be sent to you once the request is confirmed. After that you should be able now to edit this locus' details.\n\n Thank you for using SGN!\nhttp://www.sgn.cornell.edu/"; 



$page->header();

if ($args{action} eq 'confirm') {
    confirm_dialog($locus_id);
}
elsif ($args{action} eq 'request') {

    print <<END_HEREDOC;

Your request for edit permissions on locus id: $locus_id<br /> 
foi enviada à equipe de desenvolvimento do SGN.<br /><br />
Você receberá uma resposta em breve.<br /><br />

<a href="locus_display.pl?locus_id=$locus_id">Voltar</a> to the locus page.


END_HEREDOC
CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
CXGN::Contact::send_email($subject,$user_body, $usermail, $replyto);
}

$page->footer();


sub confirm_dialog {

    #my $self = shift;
   
    my $locus_id = shift;
    my $back_link = qq| <a href="locus_display.pl?locus_id=$locus_id">Voltar</a> to the locus page without requesting edit privileges|;


    print qq { 	
	<form>
	Request edit privileges for locus id: $locus_id? 
	<input type="hidden" name="action" value="request" />
	<input type="hidden" name="locus_id" value="$locus_id" />
        <button type="submit" value="Sumbit request">Enviar solicitação</button>
	</form>
	
	$back_link

    };

}

   

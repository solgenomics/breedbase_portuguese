
use strict;
use warnings;
use utf8;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use CXGN::People::Person;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $mech = Test::WWW::Mechanize->new;
my $response;

$mech->get_ok('http://localhost:3010/ajax/user/login?username=janedoe&password=secretpw');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{message}, 'Acesso realizado com sucesso.');

$mech->get_ok('http://localhost:3010/ajax/user/new?first_name=testfirst&last_name=testlast&username=testusername&password=testpass&confirm_password=testpass&email_address=test@testcassavabase.com');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'message' => 'A conta foi criada com o nome de usuário "testusername".

Para continuar, confirme que podemos entrar em contato pelo endereço "test@testcassavabase.com". Enviamos uma mensagem com o link de confirmação. Verifique seu e-mail e use esse link para confirmar o endereço.

Você poderá entrar após a confirmação da conta.'});

$mech->get_ok('http://localhost:3010/ajax/user/new?first_name=testfirst&last_name=testlast&username=testusername&password=testpass&confirm_password=testpass&email_address=test@testcassavabase.com&organization=testorg');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'error' => 'Não foi possível criar a conta pelos seguintes motivos: O nome de usuário "testusername" já está em uso. Escolha outro nome'});

#confirm account is still in cgi-bin, so test lacking here. will do manually
my $q = "update sgn_people.sp_person set disabled = default where username = 'testusername';";
my $sth = $f->bcs_schema->storage->dbh->prepare($q);
$sth->execute;
my $email = 'test@testcassavabase.com';
my $q = "update sgn_people.sp_person set private_email='$email' where username = 'testusername';";
my $sth = $f->bcs_schema->storage->dbh->prepare($q);
$sth->execute;

$mech->get_ok('http://localhost:3010/ajax/user/forgot_username?forgot_username_email=test@testcassavabase.com');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{message}, 'Solicitação enviada. Se houver uma conta neste banco de dados associada ao e-mail informado, você receberá uma mensagem com o nome de usuário. Caso contrário, nenhuma mensagem será enviada.');

$mech->get_ok('http://localhost:3010/ajax/user/reset_password?password_reset_email=test@testcassavabase.com');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{message}, 'Solicitação enviada. Se houver uma conta neste banco de dados associada ao e-mail informado, você receberá uma mensagem com o link para redefinir a senha. Caso contrário, nenhuma mensagem será enviada.');

$mech->get_ok('http://localhost:3010/ajax/user/login?username=testusername&password=testpass');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{message}, 'Acesso realizado com sucesso.');

# CHECK UPDATES LOGGED IN AS WRONG USER

# test update password functionality 
#
$mech->get_ok('http://localhost:3010/ajax/user/update?change_password=1&current_password=secretpw&new_password=blablabla&confirm_password=blablabla');
$response = decode_json($mech->content());
print STDERR Dumper($response);
is($response->{error}, "A senha atual não corresponde aos registros da SGN.", "password update check");

# reset it to what it was
#
$mech->get_ok('http://localhost:3010/ajax/user/update?change_password=1&current_password=blablabla&new_password=secretpw&confirm_password=secretpw');

# check email update
#
$mech->get_ok('http://localhost:3010/ajax/user/update?change_email=1&current_password=secretpw&private_email=test@testbase.org&confirm_email=test@testbase.org');
$response = decode_json($mech->content());
is($response->{error}, "A senha atual não corresponde aos registros da SGN.", 'email update check');

# email was not set in the fixture, no need to reset it to nothing?


# change username
#
$mech->get_ok('http://localhost:3010/ajax/user/update?current_password=secretpw&change_username=1&new_username=janemoe');
my $un_response = decode_json($mech->content());
is($un_response->{error}, "A senha atual não corresponde aos registros da SGN.", "username update check");

# change username back
#
$mech->get_ok('http://localhost:3010/ajax/user/update?current_password=secretpw&change_username=1&new_username=janedoe');

# LOG OUT WRONG USER
#
$mech->get_ok('http://localhost:3010/ajax/user/login?logout=1');
$response = decode_json $mech->content();
print STDERR "LOGOUT: ".Dumper($response);

# CHECK UPDATES WITH CORRECT USER
# login again as janedoe for update tests
#
$mech->get_ok('http://localhost:3010/ajax/user/login?username=janedoe&password=secretpw');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{message}, 'Acesso realizado com sucesso.');

# test update password functionality
#
$mech->get_ok('http://localhost:3010/ajax/user/update?change_password=1&current_password=secretpw&new_password=blablabla&confirm_password=blablabla');
$response = decode_json($mech->content());
print STDERR Dumper($response);
is($response->{message}, "Atualização concluída com sucesso.", "password update check");

# reset it to what it was
#
$mech->get_ok('http://localhost:3010/ajax/user/update?change_password=1&current_password=blablabla&new_password=secretpw&confirm_password=secretpw');

# check email update
#
$mech->get_ok('http://localhost:3010/ajax/user/update?change_email=1&current_password=secretpw&private_email=test@testbase.org&confirm_email=test@testbase.org');
$response = decode_json($mech->content());
is($response->{message}, 'Atualização concluída com sucesso.', 'email update check');

# email was not set in the fixture, no need to reset it to nothing?


# change username
#
$mech->get_ok('http://localhost:3010/ajax/user/update?current_password=secretpw&change_username=1&new_username=janemoe');
my $un_response = decode_json($mech->content());
is($un_response->{message}, "Atualização concluída com sucesso.", "username update check");

# change username back
#
$mech->get_ok('http://localhost:3010/ajax/user/update?current_password=secretpw&change_username=1&new_username=janedoe');



#Delete user
my $dbh = $schema->storage->dbh;
if( $dbh and  my $u_id = CXGN::People::Person->get_person_by_username( $dbh, "testusername" ) ) {
    my $q = "delete from sgn_people.sp_token where sp_person_id=?";
    my $h = $dbh->prepare($q);
    $h->execute($u_id);
    CXGN::People::Person->new( $dbh, $u_id )->hard_delete;
}

done_testing;

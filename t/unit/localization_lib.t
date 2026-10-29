use strict;
use warnings;
no warnings 'once';
use utf8;
use Test::More;
use Encode qw(decode);
use MIME::QuotedPrint qw(decode_qp);
use JSON::PP;
use File::Temp qw(tempdir);

# Exercise presentation methods without loading Catalyst, database schemas or
# sending mail. The source methods themselves are compiled and executed.
sub load_method {
    my ($file, $method, $package) = @_;
    open my $fh, '<:encoding(UTF-8)', $file or die "$file: $!";
    local $/;
    my $source = <$fh>;
    my ($code) = $source =~ /^(sub\s+\Q$method\E\b[^\n{]*\{.*?^\})/ms;
    die "Cannot extract $method from $file" unless $code;
    $code =~ s/^(sub\s+\w+)\s*:\w+(?=\s*\{)/$1/;
    my $ok = eval "package $package; no strict; use utf8; $code; 1;";
    die "Cannot compile $file / $method: $@" unless $ok;
}

load_method('lib/SGN/Controller/Image.pm', 'validate_image_filename', 'LocalImage');
my $image = bless {}, 'LocalImage';
is($image->validate_image_filename('plot_001.jpg'), 0, 'valid JPG accepted');
is($image->validate_image_filename('plot_001.PNG'), 0, 'valid uppercase PNG accepted');
like($image->validate_image_filename('plot!.png'), qr/caracteres inválidos/, 'invalid filename message localized');
like($image->validate_image_filename('plot.exe'), qr/\.png, \.jpg, \.jpeg, \.gif, \.pdf, \.ps ou \.eps/,
     'extension validation keeps all accepted format tokens');

load_method('lib/CXGN/Page/Form/Static.pm', 'get_error_message', 'LocalStatic');
{
    no strict 'refs';
    my @errors = qw(INPUT_REQUIRED_ERROR INTEGER_REQUIRED_ERROR NUMBER_REQUIRED_ERROR TOKEN_REQUIRED_ERROR
                    LENGTH_EXCEEDED_ERROR DATE_REQUIRED_ERROR UNIQUE_REQUIRED_ERROR ALLELE_SYMBOL_REQUIRED_ERROR);
    my $i = 0;
    for my $error (@errors) { ${"CXGN::Page::Form::ElementI::$error"} = ++$i; }
}
my $form = bless {}, 'LocalStatic';
my $noise = '';
{
    open my $quiet, '>', \$noise or die $!;
    local *STDOUT = $quiet;
    local $CXGN::Page::Form::INPUT_REQUIRED_ERROR = 1;
    like($form->get_error_message(1), qr/Campo obrigatório/, 'required-field message localized');
    like($form->get_error_message(2), qr/número inteiro/, 'integer validation message localized');
    like($form->get_error_message(8), qr/XXX-NN/, 'allele format token preserved');
    like($form->get_error_message(999), qr/Erro desconhecido \[999\]/, 'unknown error preserves code');
}

{
    package LocalSearch;
    sub data { $_[0]->{$_[1]} }
    sub data_multiple { defined $_[0]->{$_[1]} ? ($_[0]->{$_[1]}) : () }
    sub uniqify_name { $_[1] }
}
for my $name (qw(checkbox selectbox nametype est_search_form)) {
    load_method('lib/CXGN/Search/CannedForms.pm', $name, 'LocalSearch');
}
my $search = bless {}, 'LocalSearch';
my $html = $search->est_search_form();
like($html, qr/<button[^>]*value="Search"[^>]*name="search"[^>]*>Buscar<\/button>/,
     'search button has Portuguese caption and original submitted value');
like($html, qr/name="request_type" value="7" checked="checked"/, 'EST type ID preserved');
my $options = $search->selectbox('species', ['tomato'], 1);
like($options, qr/<option value="Any"[^>]*>Qualquer um<\/option>/,
     'all-species option has explicit original value');
like($search->nametype(), qr/value="starts with"[^>]*>começa com</, 'matching mode keeps its original value');
like($search->checkbox('mapped', 1), qr/checked="checked"/, 'initial checkbox default preserved');
$search->{submit} = 'Search';
unlike($search->checkbox('mapped', 1), qr/checked="checked"/, 'submitted unchecked field stays unchecked');

load_method('lib/SGN/Controller/AJAX/DecisionMeeting.pm', '_parse_decision_upload_file', 'LocalDecision');
my $decision = bless {}, 'LocalDecision';
my ($rows, $errors) = $decision->_parse_decision_upload_file(filename => 'data.txt');
ok(!defined $rows, 'unsupported upload type rejected');
is_deeply($errors, ['O arquivo enviado deve ser uma planilha Excel .xls ou .xlsx.'],
          'unsupported upload type returns localized validation error');

{
    package JSON;
    sub new { JSON::PP->new }
    package Email::Simple;
    sub create { my ($class, %args) = @_; bless \%args, $class }
    package LocalReport;
    use Encode qw(encode);
    use MIME::QuotedPrint qw(encode_qp);
    our $mail;
    sub sendmail { $mail = $_[0] }  # Capture locally; never call an SMTP client.
    sub email_addresses { +{email_from => 'solgs@example.test', email_to => 'user@example.test', email_cc => ''} }
    sub email_body { $_[0]->generic_analysis_email_message($_[1]) }
}
load_method('lib/solGS/AnalysisReport.pm', 'generic_analysis_email_message', 'LocalReport');
load_method('lib/solGS/AnalysisReport.pm', 'email_analysis_status', 'LocalReport');
my $profile = {
    analysis_type => 'pca',
    analysis_profile => { analysis_name => 'Predição de café', arguments => JSON::PP->new->encode({first_name => 'João'}) },
    referer => 'https://example.test/pca', contact_page => 'https://example.test/contact',
    pca_result => { success => 1, output_page => 'https://example.test/results?trait=yield&id=27' },
};
my $report = bless {}, 'LocalReport';
$report->email_analysis_status($profile);
my %headers = @{$LocalReport::mail->{header}};
is($headers{'Content-Type'}, 'text/plain; charset=UTF-8', 'notification declares UTF-8');
is($headers{'Content-Transfer-Encoding'}, 'quoted-printable', 'notification declares transfer encoding');
is(decode('MIME-Header', $headers{Subject}), 'Relatório solGS: Predição de café', 'subject accents survive MIME encoding');
my $body = decode('UTF-8', decode_qp($LocalReport::mail->{body}));
like($body, qr/Olá, João,/, 'personalized greeting accents survive MIME encoding');
like($body, qr/foi concluída/, 'success notification localized');
like($body, qr{https://example\.test/results\?trait=yield&id=27}, 'result URL preserved');
ok($LocalReport::mail->{body} !~ /[^\x00-\x7f]/, 'wire body contains only transfer-safe ASCII bytes');
$profile->{pca_result}{success} = 0;
$profile->{pca_result}{failure_reason} = 'Detalhes técnicos: PC1';
like($report->generic_analysis_email_message($profile), qr/Detalhes técnicos: PC1/, 'failure details preserved');
is($profile->{analysis_type}, 'pca', 'analysis type remains unchanged');

{
    package LocalBlast;
    use Encode qw(encode);
    sub read_file {
        my ($file, $options) = @_;
        my $mode = $options && $options->{binmode} ? '<' . $options->{binmode} : '<';
        open my $fh, $mode, $file or die "$file: $!";
        local $/;
        return <$fh>;
    }
    package LocalBlastDatabase;
    sub blast_db_id { 42 }
}
load_method('lib/CXGN/Blast/Parse/Plugin/Table.pm', 'parse', 'LocalBlast');
my $dir = tempdir(CLEANUP => 1);
my $blast_file = "$dir/report.txt";
{
    open my $fh, '>:encoding(UTF-8)', $blast_file or die $!;
    print $fh "BLASTN\nQuery= query_A\n>subject_A Descrição original de café\n";
    print $fh " Score = 50\n Identities = 10/10\nQuery: 1 ACGT 10\nSbjct: 3 ACGT 12\n";
}
my $blast = bless {}, 'LocalBlast';
my $db = bless {}, 'LocalBlastDatabase';
my $table = $blast->parse(undef, $blast_file, $db);
like($table, qr/<th>Descrição<\/th>/, 'BLAST HTML header decoded as UTF-8');
like($table, qr/Descrição original de café/, 'BLAST user description retains its accents');
like($table, qr/subject_A/, 'BLAST sequence ID retained');
{
    open my $fh, '<:encoding(UTF-8)', "${blast_file}_tabular.txt" or die $!;
    my $line = <$fh>;
    like($line, qr/^query_A\tsubject_A\t100\.00\t10\t0\t0\t1\t10\t3\t12\t0\t50\tDescrição original de café/,
         'BLAST tabular data remains unchanged');
}

done_testing();

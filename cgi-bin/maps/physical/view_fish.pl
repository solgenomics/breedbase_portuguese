use utf8;
use strict;
use warnings;
use CXGN::Page;
use CXGN::Fish;
use CXGN::DB::Connection;
use SGN::Image;

use CatalystX::GlobalContext '$c';

my $page = CXGN::Page->new("view_fish.pl","john,marty");
my ($image_size) = $page->get_encoded_arguments('size');
my ($clone_id) = $page->get_encoded_arguments('id');
my ($image_id) = $page->get_encoded_arguments('image_id');

# Argument validation.
unless ($clone_id && $image_id) {
  $page->message_page ("Esta página exige dois argumentos e pelo menos um deles não foi informado.");
}
unless (($clone_id =~ /\d+/) && ($image_id =~ /\d+/)) {
  $page->message_page ("Bogus page arguments supplied ($clone_id, $image_id)");
}

# Argument coercion.
unless ($image_size  =~ /(full|small)/i) {
  $image_size = 'small';
}

my $dbh = CXGN::DB::Connection->new;
# ensure that the image_id is a fish image
my $image;
if ($dbh->selectrow_array("select fish_result_id from fish_result_image where image_id = ?", undef, $image_id)) {
 $image = SGN::Image->new( $dbh, $image_id, $c );
}

if ($image) {
  my $fish_table = CXGN::Fish::fish_image_html_table($dbh, $clone_id);
  my $image_url;
  my $size_control;
  if ($image_size =~ /full/i) {
    $image_url = $image->get_image_url('large');
    $size_control = "<b>Size:</b>&nbsp;&nbsp;&nbsp;
<a href=\"?id=$clone_id&amp;image_id=$image_id&amp;size=small\">Small</a>
&nbsp;&nbsp;&nbsp;Full"
  } else {
    $image_url = $image->get_image_url();
    $size_control = "<b>Size:</b>&nbsp;&nbsp;&nbsp;Small&nbsp;&nbsp;&nbsp;
<a href=\"?id=$clone_id&amp;image_id=$image_id&amp;size=full\">Full</a>"
  }

  $page->header("Visualizar imagem FISH");
  print <<EOHTML;
<a href="/maps/physical/clone_info.pl?id=$clone_id">Voltar às informações do clone</a>
<br />
<br />
$fish_table
<br />
$size_control
<br />
<br />
<a href="/image/index.pl?image_id=$image_id"><img src=\"$image_url\" /></a>
EOHTML
  $page->footer();
} else {
  $page->message_page("Imagem do clone não encontrada.");
}
#EOF

#!/usr/bin/perl -w
use utf8;

# This script will simply have links to other scripts which will do the
# actual work in managing data.
use strict;
use warnings;

use CXGN::Page;
use CXGN::People;
use CXGN::Insitu::Toolbar;
our $debug = 2; # higher for more verbosity

# default operation; print form
#
sub print_default {
	print "Please select which data you want to update:<br /><br />\n\n";

        print "<div class=\"subheading\">Experimentos / Imagens</div>\n";
	print "<ul>\n";
        print "<li><a href=\"detail/experiment.pl?action=new\"><strong>Adicionar experimento</strong></a></li>\n";
	print "</ul>\n";

# 	print "<div class=\"subheading\">Categories</div>\n";
# 	print "<ul>\n";
# 	print "<li><a href=\"/insitu/detail/tag.pl?action=new\"><strong>Adicionar etiqueta</strong></a></li>\n";
# #	print "<li><a href=\"/cgi-bin/edit_cats.pl?op=edit\"><strong>Editar categorias</strong></a><br /> <em>Altere nomes e descrições de categorias e adicione categorias implícitas às etiquetas.</em></li>\n";
# 	print "</ul>\n";

	print qq { <div class="subheading">Probes</div>\n
		       <ul>\n
                       <li><a href="/insitu/detail/probe.pl?action=new"><strong>Adicionar sonda</strong></a></li>
		       </ul> 
		   };
                      
	

	# only curators can add/edit organisms
	# FIXME -- the first submitters shouldn't be curators, but they should
	# be allowed to enter the species they want regardless
	#if ($user_type eq 'curator') {
                print "<div class=\"subheading\">Organismos</div>\n";
		print "<ul>\n";
                print "<li><a href=\"/insitu/detail/organism.pl?action=new\"><strong>Adicionar organismos</strong></a></li>\n";
                #print "<li><a href=\"/cgi-bin/edit_species.pl?op=edit\"><strong>Editar organismos</strong></a></li>\n";
                #print "<li><a href=\"/cgi-bin/edit_species.pl?op=del\"><strong>Excluir organismos</strong></a></li>\n";
		print "</ul>\n";
	#}

}

#####################################################################
#####################################################################
# Stuff happens here
#####################################################################
#####################################################################

# display what needs displaying, do what needs doing
####################################################
my $page = CXGN::Page->new( "Gerenciar dados", "Teri");
$page->header("Insitu Manager", "<a href=\"/insitu\">Insitu</a>: Manage Data");

CXGN::Insitu::Toolbar::display_toolbar("Manage");

print_default();

$page->footer();

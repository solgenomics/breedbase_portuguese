JSAN.use('MochiKit.Logging');

/*

=head1 NAME

CXGN.Base

=head1 SYNOPSIS

Basic SGN javascript functions to export to all pages

=head1 AUTHOR

Christopher Carpita <csc32@cornell.edu>

=cut

*/

/*

=head2 alertBeta(content)

Special Alert for development sites with beta users, same pop-up alert box, but other information pre-pended, telling the beta user that the alert box is temporary and stuff.

=cut

*/

function alertBeta(content) {
	var notification = "======== Developer Error Box ======== \n";
		notification += "Ocorreu um problema no JavaScript:\n";
	notification += content;
	alert(notification);
}

/*

=head2 notify(content) 

Set the notification in a closable box at the top of the page.  
Similar to the Undo notifications on GMail.  For make benefit glorious user.

=cut

*/

function notify(content) {
	var NOTIFY_BOX_ID = "SGN_NOTIFY_BOX"; //site-wide standard
	var NOTIFY_CONTENT_ID = "SGN_NOTIFY_CONTENT";
	document.getElementById("SGN_NOTIFY_BOX").style.display = "block";
	if(!document.getElementById(NOTIFY_CONTENT_ID) || !document.getElementById(NOTIFY_BOX_ID)){
		var warning = "O desenvolvedor deveria ter usado a caixa de notificações no topo\nda página, mas o elemento de notificação com os\nIDs: '" + NOTIFY_BOX_ID + "' or '" + NOTIFY_CONTENT_ID + "' não foi encontrado.\n\nNotificação: ";
		alertBeta(warning + content);
		return false;
	}
	var notify_content = document.getElementById(NOTIFY_CONTENT_ID);
	notify_content.innerHTML = content;
	var notify_box = document.getElementById(NOTIFY_BOX_ID);
	notify_box.style.display = "block";
	return true;
	//The box will take care of closing itself (setting display to "none")
}

/*

=head1 alert()

 Redefine the javascript function.  An sgn user should never see an alert
 box.  Instead, write the alert to the MochiKit Logger.

*/



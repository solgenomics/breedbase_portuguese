/*jslint browser: true, devel: true */

/**

=head1 UploadGrafts.js

Dialogs for uploading grafts


=head1 AUTHORS

Lukas Mueller <lam87@cornell.edu>, based on code by
Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

    $('#upload_grafts_link').click(function () {
        open_upload_grafts_dialog();
    });

    $("#upload_graft_dialog_submit").click( function () {
        $('#upload_graft_dialog').modal("hide");
        upload_grafts_file();
    });

    $("#grafts_upload_spreadsheet_format_info").click( function () {
        $('#upload_graft_dialog').modal("hide");
        $("#grafts_upload_spreadsheet_info_dialog" ).modal("show");
    });

    var archived_filename;
    $('#upload_graft_form').iframePostForm({
        json: false,
        post: function () {
            var uploadedGraftsFile = $("#graft_uploaded_file").val();
            $('#working_modal').modal("show");
            if (uploadedGraftsFile === '') {
                $('#working_modal').modal("hide");
                alert("Nenhum arquivo selecionado");
            }
        },
        complete: function (r) {
    	    var clean_r = r.replace('<pre>', '');
	    clean_r = clean_r.replace('</pre>', '');
	    console.log(clean_r);
	    var response = JSON.parse(clean_r);
            $('#working_modal').modal("hide");

            var html;

            if (response.error) {
                html = '<h3>Foram identificados os seguintes problemas</h3><p class="bg-warning">'+response.error+'</p>';
		$('#upload_graft_store').prop("disabled", true);
            }
            else {

                archived_filename = response.archived_filename_with_path;

		$('#upload_graft_store').prop("disabled", false);
                html = '<h3>Nenhum problema foi identificado</h3>Clique no botão "Armazenar" para salvar os enxertos no banco de dados.';
            }
            $("#upload_graft_validate_display tbody").html(html);
            $("#upload_graft_validate_display").modal('show');
        }
    });

    function upload_grafts_file() {
        var uploadFile = $("#graft_uploaded_file").val();
        $('#upload_graft_form').attr("action", "/ajax/grafts/upload_verify");
        if (uploadFile === '') {
            alert("Selecione um arquivo");
            return;
        }
        $("#upload_graft_form").submit();
    }

    function open_upload_grafts_dialog() {
        $('#upload_graft_dialog').modal("show");
    }

    jQuery('#upload_graft_store').click(function(){
	//alert('Archive path: '+archived_filename);
        jQuery.ajax( {
            url: '/ajax/grafts/upload_store',
            data: {
                'archived_filename':archived_filename,
            },
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            success: function(response) {
                jQuery('#working_modal').modal('hide');
                if (response.error) {
                    alert('Ocorreu um erro: nenhum enxerto foi salvo! Corrija no arquivo os problemas identificados na validação. '+response.error);
                }
                else {
		    //alert("RESPONSE: "+JSON.stringify(response));
                    jQuery('#graft_upload_success_dialog_message').modal('show');
		    jQuery('#list_of_uploaded_grafts').val(response.added_grafts);
		    jQuery('#list_of_already_uploaded_grafts').val(response.grafts_already_present);
                }
            },
            error: function(response) {
                jQuery('#working_modal').modal('hide');
		jQuery('#list_of_grafts_with_problems').html(response.list_of_grafts_with_problems);
                alert('Ocorreu um erro ao armazenar os enxertos. Nenhum foi enviado. '+response.responseText);
            }
        });
    });

});

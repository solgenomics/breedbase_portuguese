
function stock_detail_page_init_dialogs() {
        jQuery('#stock_trials_info_popup').dialog({
	'autoOpen' : false,
	'modal' : true,
	'height' : 600,
	'width' : 700,
	'buttons' : {
	    'OK' : function() {
		jQuery('#stock_trials_info_popup').dialog("close");
	    }
	}

    });

    jQuery('#remove_parent_dialog').dialog({
	'autoOpen' : false,
	'modal' : true,
	'title' : "Remover um parental",
	'height' : 300,
	'width' : 400,
	'buttons' : {
	    "Concluído" : function() {
		jQuery('#remove_parent_dialog').dialog("close");
	    },

	}

    });


}

function show_stock_trial_detail(stock_id, stock_name, trial_id, trial_name) {
    jQuery('#stock_trials_info_popup').dialog("option", "title", "Dados fenotípicos de "+stock_name+" do ensaio "+trial_name);
    jQuery('#stock_trials_info_popup').dialog("open");
    jQuery('#stock_trials_info_table').DataTable().destroy();

    jQuery('#stock_trials_info_table').DataTable( {
	ajax: '/stock/'+stock_id+'/datatables/trial/'+trial_id,
    });
}

function get_remove_parents_list(stock_id) {
    jQuery.ajax( {
	url : '/ajax/stock/parents?stock_id='+stock_id,
	success: function(response) {
	    var html = "";
	    for (var n=0; n<response.parents.length; n++) {
		html += response.parents[n][1]+ '&nbsp;&nbsp;<a href="javascript:remove_parents('+response.stock_id+','+ response.parents[n][0]+');" ><font color="red" >X</font></a><br /><br />';

	    }

	    jQuery('#remove_parent_list').html(html);
	},
	error: function(response) {
	    alert("ocorreu um erro.");
	}
    });

}

function remove_parents(stock_id, parent_id) {
    var yes = confirm("Tem certeza de que deseja remover este parental?");
    if (yes) {
	jQuery.ajax( {
	    url: '/ajax/stock/parent/remove',
	    data: { 'stock_id' : stock_id, 'parent_id' : parent_id },
	    success : function(response) {
		if (response.error) {
		    alert(response.error);
		}
		else {
		    alert("O parental foi removido.");
		    jQuery('#remove_parent_dialog').dialog("close");
		    window.location.href = '/stock/'+stock_id+'/view';

		}
	    }
	});

    }

}

function obsoleteStock(stock_id, stock_name){
    showObsoleteDialog(stock_id, stock_name, true);
}

function unObsoleteStock(stock_id, stock_name){
    showObsoleteDialog(stock_id, stock_name, false);
}

function showObsoleteDialog(stock_id, stock_name, obsolete) {
    let html = '';
    html = html + "<form class=\"form-horizontal\"><div class=\"form-group\"><label class=\"col-sm-4 control-label\">Nome do material: </label><div class=\"col-sm-8\" ><input class=\"form-control\" id=\"obsolete_stock_name\" name=\"obsolete_stock_name\" value=\""+stock_name+'" disabled></div></div>';
    html = html + "<div class=\"form-group\"><label class=\"col-sm-4 control-label\">Observação: </label><div class=\"col-sm-8\" ><input class=\"form-control\" id=\"obsolete_note\" name=\"obsolete_note\" placeholder=\"Opcional\"></div></div></form>";
    html = html + '<div class="form-group"><input id="obsolete_stock_id" type="hidden" value="'+stock_id+'"/>';

    jQuery("#obsoleteStockDialog").html(obsolete ? "Tornar este material obsoleto" : "Reativar este material");
    jQuery("#obsolete_stock_submit").html(obsolete ? "Obsoleto" : "Reativar");
    jQuery("#obsolete_stock_submit").data("obsolete", obsolete ? 'true' : 'false');
    jQuery('#obsolete_stock_div').html(html);
    jQuery('#obsolete_stock_dialog').modal('show');
}

jQuery(document).ready(function($) {

    jQuery('#obsolete_stock_submit').click( function() {
        const obsolete = jQuery(this).data("obsolete") === 'true';
        const note = jQuery('#obsolete_note').val();
        const stock_id = jQuery('#obsolete_stock_id').val();
        if (!stock_id) {
            alert ("Erro ao recuperar o ID do material");
            return;
        }

        const stock_name = jQuery('#obsolete_stock_name').val();
        if (!stock_name) {
            alert ("Erro ao recuperar o nome do material");
            return;
        }

        const confirmation = confirm("Tem certeza de que deseja " + (obsolete ? "tornar obsoleto" : "reativar") + " este material?" + "  " + stock_name);

        if (confirmation) {
            jQuery.ajax({
                url: '/stock/obsolete',
                data : {
                    'stock_id' : stock_id,
                    'is_obsolete': obsolete ? 1 : 0,
                    'obsolete_note': note,
                },
                beforeSend: function(response){
                    jQuery('#working_modal').modal('show');
                },
                success: function(response){
                    console.log(response);
                    jQuery('#working_modal').modal('hide');
                    if (response.error) {
                        alert(response.error);
                    }
                    if (response.success == 1) {
                        jQuery('#obsolete_stock_dialog').modal('hide');
                        jQuery('#obsolete_stock_message_dialog').modal('show');
                    }
                },                
                error: function(response){
                    jQuery('#working_modal').modal('hide');
                    alert("Erro ao tornar o material obsoleto.");
                }
            });
        }
    });

    jQuery("#dismiss_obsolete_stock_message_dialog").click(function(){
        location.reload();
    });

});

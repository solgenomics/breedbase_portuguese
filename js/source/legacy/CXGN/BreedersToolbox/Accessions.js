/*jslint browser: true, devel: true */
/**

=head1 Accessions.js

Dialogs for managing accessions


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/

var $j = jQuery.noConflict();
var list = new CXGN.List();
var accessionList;
var accession_list_id;
var validSpecies;
var fuzzyResponse;
var fullParsedData;
var infoToAdd;
var accessionListFound;
var speciesNames;
var doFuzzySearch;
var upload_in_progress = false;

function disable_ui() {
    jQuery('#working_modal').modal("show");
}

function enable_ui() {
    jQuery('#working_modal').modal("hide");
    jQuery('.modal-backdrop').hide();
}

jQuery(document).ready(function ($) {

    jQuery('#manage_accessions_populations_new').click(function(){
        jQuery('#manage_populations_add_population_dialog').modal('show');
    });

    jQuery("#create_population_submit").click(function(){
        const lo = new CXGN.List();

        const population_name = jQuery('#create_population_name').val();
        if (!population_name) {
            alert ("Informe o nome da população");
            return;
        }

        const member_type = jQuery('#member_type').val();
        if (!member_type) {
            alert ("Informe o tipo dos membros");
            return;
        }

        let list_id;
        let list_validation = 1;

        if (member_type == 'accessions') {
            list_id =  jQuery('#create_population_accession_list_div_list_select').val();
            if (!list_id) {
                alert ("Informe uma lista de acessos");
                return;
            } else {
                list_validation = lo.legacy_validate(list_id, 'accessions', true);
                if (list_validation != 1) {
                    alert("A lista de acessos não passou na validação. Os nomes devem ser identificadores únicos de materiais do tipo acesso no banco de dados");
                    return;
                }
            }
        } else if (member_type == 'plots') {
            list_id =  jQuery('#create_population_plot_list_div_list_select').val();
            if (!list_id) {
                alert ("Informe uma lista de parcelas");
                return;
            } else {
                list_validation = lo.legacy_validate(list_id, 'plots', true);
                if (list_validation != 1) {
                    alert("A lista de parcelas não passou na validação. Os nomes devem ser identificadores únicos de materiais do tipo parcela no banco de dados");
                    return;
                }
            }
        } else if (member_type == 'plants') {
            list_id =  jQuery('#create_population_plant_list_div_list_select').val();
            if (!list_id) {
                alert ("Informe uma lista de plantas");
                return;
            } else {
                list_validation = lo.legacy_validate(list_id, 'plants', true);
                if (list_validation != 1) {
                    alert("A lista de plantas não passou na validação. Os nomes devem ser identificadores únicos de materiais do tipo planta no banco de dados");
                    return;
                }
            }
        }

        jQuery.ajax({
            type: 'POST',
            url: '/ajax/population/new',
            dataType: "json",
            data: {
                'population_name': population_name,
                'member_type': member_type,
                'list_id': list_id,
            },
            beforeSend: function(){
                disable_ui();
            },
            success: function (response) {
                enable_ui();
                if (response.error){
                    alert(response.error);
                }
                if (response.success){
                    jQuery("#manage_populations_add_population_dialog").modal("hide");
                    jQuery("#create_population_saved_dialog_message tbody").html('');
                    jQuery("#create_population_saved_dialog_message tbody").append(response.success);
                    jQuery('#create_population_saved_dialog_message').modal("show");
                    return;
                }
            },
            error: function (r) {
                alert("Ocorreu um erro ao adicionar a população. "+r.responseText);
            }
        });
    });

    jQuery("#dismiss_create_population_saved_dialog").click(function(){
        location.reload();
    });

    jQuery('#manage_accessions_populations_onswitch').click( function() {
      var already_loaded_tables = jQuery('#accordion').find("table");
      if (already_loaded_tables.length > 0) { return; }

      jQuery.ajax ( {
        url : '/ajax/manage_accessions/populations',
        beforeSend: function() {
          disable_ui();
        },
        success: function(response){
          var populations = response.populations;
          for (var i in populations) {
            var name = populations[i].name;
            var population_id = populations[i].stock_id;
            var accessions = populations[i].members;
            var member_type = populations[i].member_type
            var table_id = population_id+i+"_pop_table";

            var section_html = '<div class="row"><div class="panel panel-default"><div class="panel-heading" >';
            section_html += '<div class="panel-title" name="populations_members_table_toggle" data-table_id="#'+table_id+'" data-population_id="'+population_id+'" data-population_name="'+name+'"><div class="row"><div class="col-sm-6" data-toggle="collapse" data-parent="#accordion" data-target="#collapse'+i+'"><a href="#'+table_id+'" class="accordion-toggle">'+name+'</a></div><div class="col-sm-3"><a href="/stock/'+population_id+"Vista<small>[Ir para a página da população]</small></a></div><div class=\"col-sm-3\"><a name=\"manage_populations_add_members\" data-population_id=\""+population_id+'" data-population_name="'+name+'" data-member_type="'+member_type+"\"><small>[Adicionar membros à população]</small></a><br/><a name=\"manage_populations_delete_population\" data-population_id=\""+population_id+'" data-population_name="'+name+"\"><small>[Excluir população]</small></a></div></div></div></div>";
            section_html += '<div id="collapse'+i+'" class="panel-collapse collapse">';
            section_html += '<div class="panel-body" style="overflow:hidden"><div class="table-responsive" style="margin-top: 10px;"><table id="'+table_id+'" class="table table-hover table-striped table-bordered" width="100%"></table><div id="populations_members_add_to_list_data_'+population_id+'" style="display:none"></div><br/><div id="populations_members_add_to_list_menu_'+population_id+'"></div></div>';
            section_html += '</div><br/></div></div></div><br/>';

            jQuery('#accordion').append(section_html);
          }
          enable_ui();
        },
        error: function(response) {
          enable_ui();
          alert("Ocorreu um erro ao recuperar os dados da população.");
        }
      });
    });

    jQuery(document).on("click", "div[name='populations_members_table_toggle']", function(){
        var table_id = jQuery(this).data('table_id');
        var population_id = jQuery(this).data('population_id');
        var population_name = jQuery(this).data('population_name');

        var table = jQuery(table_id).DataTable({
            ajax: '/ajax/manage_accessions/population_members/'+population_id,
            destroy: true,
            columns: [
                { title: "Nome do membro", "data": null, "render": function ( data, type, row ) { return "<a href='/stock/"+row.stock_id+"/view'>"+row.name+"</a>"; } },
                { title: "Tipo do membro", "data": "stock_type" },
                { title: "Descrição", "data": "description" },
                { title: "Sinônimos", "data": "synonyms[, ]" },
                { title: "Remover da população", "data": null, "render": function ( data, type, row ) { return "<a name='populations_member_remove' data-stock_relationship_id='"+row.stock_relationship_id+"'>X</a>"; } },
            ],
            "fnInitComplete": function(oSettings, json) {
                //console.log(json);
                var html = "";
                for(var i=0; i<json.data.length; i++){
                    html += json.data[i].name+"\n";
                }
                jQuery("#populations_members_add_to_list_data_"+population_id).html(html);
                addToListMenu("populations_members_add_to_list_menu_"+population_id, "populations_members_add_to_list_data_"+population_id, {
                    selectText: true,
                    listType: 'accessions',
                    listName: population_name
                });
            }
        });

    });

    var population_id;
    var population_name;
    var member_type;

    jQuery(document).on("click", "a[name='manage_populations_add_members']", function(){

        population_id = jQuery(this).data('population_id');
        population_name = jQuery(this).data('population_name');
        member_type = jQuery(this).data('member_type');
        if (member_type == 'plots') {
            jQuery("#add_member_to_population_list_div").html(list.listSelect("add_member_to_population_list_div", ['plots'], "selecione uma lista de parcelas", undefined, undefined));
        } else if (member_type == 'plants') {
            jQuery("#add_member_to_population_list_div").html(list.listSelect("add_member_to_population_list_div", ['plants'], "selecione uma lista de plantas", undefined, undefined));
        } else {
            jQuery("#add_member_to_population_list_div").html(list.listSelect("add_member_to_population_list_div", ['accessions'], "selecione uma lista de acessos", undefined, undefined));
        }
        jQuery('#add_member_population_name').html(population_name);
        jQuery('#manage_populations_add_members_dialog').modal('show');
    });

    jQuery(document).on("click", "a[name='manage_populations_delete_population']", function(){
        population_id = jQuery(this).data('population_id');
        population_name = jQuery(this).data('population_name');
        jQuery('#delete_population_name').html(population_name);
        jQuery('#manage_populations_delete_dialog').modal('show');
    });

    jQuery('#organization_name_input').autocomplete({
       source: '/ajax/stock/stockproperty_autocomplete?property=organization',
    });

    jQuery('#population_name_input').autocomplete({
       source: '/ajax/stock/population_autocomplete',
    });

    jQuery("#add_members_to_population_submit").click(function(){
        const lo = new CXGN.List();
        let list_validation = 1;
        const member_list_id = jQuery('#add_member_to_population_list_div_list_select').val();

        if (member_type == 'accessions') {
            if (!member_list_id) {
                alert ("Informe uma lista de acessos");
                return;
            } else {
                list_validation = lo.legacy_validate(member_list_id, 'accessions', true);
                if (list_validation != 1) {
                    alert("A lista de acessos não passou na validação. Os nomes devem ser identificadores únicos de materiais do tipo acesso no banco de dados");
                    return;
                }
            }
        } else if (member_type == 'plots') {
            if (!member_list_id) {
                alert ("Informe uma lista de parcelas");
                return;
            } else {
                list_validation = lo.legacy_validate(member_list_id, 'plots', true);
                if (list_validation != 1) {
                    alert("A lista de parcelas não passou na validação. Os nomes devem ser identificadores únicos de materiais do tipo parcela no banco de dados");
                    return;
                }
            }
        } else if (member_type == 'plants') {
            if (!member_list_id) {
                alert ("Informe uma lista de plantas");
                return;
            } else {
                list_validation = lo.legacy_validate(member_list_id, 'plants', true);
                if (list_validation != 1) {
                    alert("A lista de plantas não passou na validação. Os nomes devem ser identificadores únicos de materiais do tipo planta no banco de dados");
                    return;
                }
            }
        } else {
            if (!member_list_id) {
                alert ("Informe uma lista de acessos");
                return;
            } else {
                list_validation = lo.legacy_validate(member_list_id, 'accessions', true);
                if (list_validation != 1) {
                    alert("A lista de acessos não passou na validação. Os nomes devem existir no banco de dados");
                    return;
                }
            }
        }

        jQuery.ajax({
            type: 'POST',
            url: '/ajax/population/add_members',
            dataType: "json",
            data: {
                'population_name': population_name,
                'list_id': jQuery('#add_member_to_population_list_div_list_select').val(),
            },
            beforeSend: function(){
                disable_ui();
            },
            success: function (response) {
                enable_ui();
                if (response.error){
                    alert(response.error);
                }
                if (response.success){
                    alert(response.success);
                }
            },
            error: function () {
                alert("Ocorreu um erro ao adicionar membros à população.");
            }
        });
    });

    jQuery("#delete_population_submit").click(function(){
        jQuery.ajax({
            type: 'POST',
            url: '/ajax/population/delete',
            dataType: "json",
            data: {
                'population_id': population_id,
                'population_name': population_name,
            },
            beforeSend: function(){
                disable_ui();
            },
            success: function (response) {
                enable_ui();
                if (response.error){
                    alert(response.error);
                }
                if (response.success){
                    if (confirm(response.success)) {
                        location.reload();
                    }
                }
            },
            error: function () {
                alert("Ocorreu um erro ao excluir a população.");
            }
        });
    });

    jQuery(document).on("click", "a[name='populations_member_remove']", function(){
        var stock_relationship_id= jQuery(this).data("stock_relationship_id");
        if (confirm("Tem certeza?")){
            jQuery.ajax({
                url: '/ajax/population/remove_member?stock_relationship_id='+stock_relationship_id,
                dataType: "json",
                beforeSend: function(){
                    disable_ui();
                },
                success: function (response) {
                    enable_ui();
                    if (response.error){
                        alert(response.error);
                    }
                    if (response.success){
                        if (confirm(response.success)) {
                            location.reload();
                        }
                    }
                },
                error: function () {
                    alert("Ocorreu um erro ao remover o acesso da população.");
                }
            });
        }
    });

    function toggleEmailField() {
        var checkbox = jQuery('#email_option_to_recieve_accession_upload_status');
        var emailField = jQuery('#email_address_upload');
        var emailLabel = jQuery('#email_label_upload');
        if (checkbox.prop('checked')) {
            emailField.show();
            emailLabel.show();
        } else {
            emailField.hide();
            emailLabel.hide();
        }
    }

    jQuery('#email_option_to_recieve_accession_upload_status').on('change', toggleEmailField);
    toggleEmailField();

    function toggleAccessionListName() {
        var checkbox = jQuery('#create_accession_list');
        var nameInput = jQuery('#create_accession_list_name');
        if ( checkbox.prop('checked')) {
            nameInput.show();
        }
        else {
            nameInput.hide();
        }
    }
    jQuery('#create_accession_list').on('change', toggleAccessionListName);
    toggleAccessionListName();

    function add_accessions(full_info, species_names) {
        var email_address = jQuery('#email_address_upload').val();
        var email_option_enabled = jQuery('#email_option_to_recieve_accession_upload_status').prop('checked') ? 1 : 0;
        console.log("check email address:", email_address);
        console.log(full_info);

        if (email_option_enabled) {
            var user_response = confirm("Você receberá um e-mail quando o processamento for concluído. Deseja continuar?");
            if (!user_response) {
                console.log("no accessions saved + no email sent");
                return;
            }
        }
        else {
            disable_ui();
        }

        upload_in_progress = true;

        $.ajax({
            type: 'POST',
            url: '/ajax/accession_list/add',
            dataType: "json",
            timeout: 36000000,
            data: {
                'full_info': JSON.stringify(full_info),
                'allowed_organisms': JSON.stringify(species_names),
                'email_address_upload': email_address,
                'email_option_enabled': email_option_enabled,
            },
            // beforeSend: function(){ //UI gets disabled before ajax call if email option is not enabled
            //     disable_ui();
            // },
            success: function (response) {
                console.log("email_option_enabled on success:", email_option_enabled);
                if (response.error) {
                    enable_ui();
                    alert(response.error);
                } else {
                    enable_ui();
                    var html = "Os seguintes materiais foram adicionados!<br/>";
                    for (var i=0; i<response.added.length; i++){
                        html = html + '<a href="/stock/'+response.added[i][0]+'/view">'+response.added[i][1]+'</a><br/>';
                    }
                    jQuery('#add_accessions_saved_message').html(html);
                    jQuery('#add_accessions_saved_message_modal').modal('show');

                    // Remove list_id from the URL query params, if present
                    const url = new URL(window.location.href);
                    url.searchParams.delete('list_id');
                    history.replaceState({}, '', url);
                }
            },
            error: function (response) {
                console.log("email_option_enabled on error:", email_option_enabled);
                alert("Ocorreu um erro durante o processamento."+response.responseText);
            },
            complete: function () {
                upload_in_progress = false;
                if (!email_option_enabled) enable_ui();
            },
        });
    }

    jQuery(window).on('beforeunload', function (e) {
        if (upload_in_progress) {
            e.preventDefault();
            e.returnValue = ''; // required for Chrome
            return '';          // required for some older browsers
        }
    });

    function verify_species_name() {
        var speciesName = $("#species_name_input").val();
        validSpecies = 0;
        return $.ajax({
            type: 'GET',
            url: '/organism/verify_name',
            dataType: "json",
            data: {
                'species_name': speciesName,
            }
            // success: function (response) {
            //     if (response.error) {
            //         alert(response.error);
            //         validSpecies = 0;
            //     } else {
            //         validSpecies = 1;
            //     }
            // },
            // error: function (response) {
            //     alert('An error occurred verifying species name. sorry'+response.responseText);
            //     validSpecies = 0;
            // }
        });
    }

    $('#species_name_input').focusout(function () {
        verify_species_name().then( function(r) { if (r.error) { alert(r.error); } }, function(r) { alert("Ocorreu um erro. O site pode estar indisponível no momento."); });
    });

    $('#review_absent_accessions_submit').click(function () {
        if (fullParsedData == undefined){
            var speciesName = $("#species_name_input").val();
            var populationName = $("#population_name_input").val();
            var organizationName = $("#organization_name_input").val();
            var accessionsToAdd = accessionList;
            var emailAddress = $("#email_option_to_recieve_accession_upload_status").prop('checked') ? $("#email_address_upload").val() : "";
            var email_option_enabled = $("#email_option_to_recieve_accession_upload_status").prop('checked') ? 1 : 0;

            if (!speciesName) {
                alert("Informe o nome da espécie");
                return;
            }

            if (!populationName) {
                populationName = '';
            }
            if (!accessionsToAdd || accessionsToAdd.length == 0) {
                alert("Nenhum acesso para adicionar");
                return;
	        }

	        verify_species_name().then(
		    function(r) {
		        if (r.error) { alert(r.error); }
		        else {
		    	    for(var i=0; i<accessionsToAdd.length; i++){
		    	        infoToAdd.push({
		    	    	    'species':speciesName,
		    	    	    'defaultDisplayName':accessionsToAdd[i],
		    	    	    'germplasmName':accessionsToAdd[i],
		    	    	    'organizationName':organizationName,
		    	    	    'populationName':populationName,
		    	        });
		    	        speciesNames.push(speciesName);
		    	    }
		        }
		        add_accessions(infoToAdd, speciesNames);
		        $('#review_absent_dialog').modal("hide");

		    },
		    function(r) {
		        alert("ERRO! Tente novamente mais tarde.");
		    }
	        );
	    } else {
	        add_accessions(infoToAdd, speciesNames, emailAddress, email_option_enabled);
	        $('#review_absent_dialog').modal("hide");
	    }

        //window.location.href='/breeders/accessions';
    });

    $('#new_accessions_submit').click(function () {
        var selected_tab = jQuery('#add_new_accessions_tab_select .active').attr('id');
        if (selected_tab == "add_new_accessions_list_tab"){
            accession_list_id = $('#list_div_list_select').val();
            fullParsedData = undefined;
	    verify_accession_list(accession_list_id);
        } else if (selected_tab == "add_new_accessions_file_tab"){
	    var uploadFile = jQuery("#new_accessions_upload_file").val();
	    jQuery('#upload_new_accessions_form').attr("action", "/ajax/accessions/verify_accessions_file");
	    if (uploadFile === '') {
                alert("Selecione um arquivo");
                return;
	    }

	    jQuery("#upload_new_accessions_form").submit();
        }
	$('#add_accessions_dialog').modal("hide");
    });

    jQuery('#upload_new_accessions_form').iframePostForm({
        json: false,
        post: function () {
            var uploadedSeedlotFile = jQuery("#new_accessions_upload_file").val();
            jQuery('#working_modal').modal("show");
            if (uploadedSeedlotFile === '') {
                jQuery('#working_modal').modal("hide");
            }
        },
        complete: function (r) {
            //alert("DONE WITH UPLOAD "+r);
            var clean_r = r.replace(/^<pre[^>]*>/, '');
            clean_r = clean_r.replace('</pre>', '');
            clean_r = clean_r.trim(); // Removes any leading or trailing whitespace
            // Remove all remaining HTML tags (if any)
            clean_r = clean_r.replace(/<[^>]*>/g, '');
            response = JSON.parse(clean_r); //decodeURIComponent(clean_r));
            // console.log(response);
            console.log(JSON.stringify(response, null, 2));
            jQuery('#working_modal').modal("hide");

            if (response.error || response.error_string) {
                fullParsedData = undefined;
                alert(response.error || response.error_string);
            }
            else if (response.success) {
                fullParsedData = response.full_data;
                doFuzzySearch = jQuery('#fuzzy_check_upload_accessions').prop('checked');
                review_verification_results(doFuzzySearch, response, response.list_id);
            }
            else {
                fullParsedData = undefined;
                alert("Ocorreu um erro desconhecido. Tente novamente mais tarde ou entre em contato conosco.");
            }
        }
    });

    $('[name="add_accessions_link"]').click(function () {
        var list = new CXGN.List();
        accessionList	= [];
        accession_list_id = undefined;
        validSpecies	= undefined;
        fuzzyResponse	= undefined;
        fullParsedData	= undefined;
        infoToAdd	= [];
        accessionListFound	= {};
        speciesNames	= [];
        doFuzzySearch	= undefined;
        $('#add_accessions_dialog').modal("show");
        $('#review_found_matches_dialog').modal("hide");
        $('#review_fuzzy_matches_dialog').modal("hide");
        $('#review_absent_dialog').modal("hide");
        $("#list_div").html(list.listSelect("list_div", ["accessions"], undefined, undefined, undefined));
    });

    jQuery('#accessions_upload_spreadsheet_format_info').click(function(){
        jQuery('#accessions_upload_spreadsheet_format_modal').modal("show");
    });

    $('body').on('hidden.bs.modal', '.modal', function () {
        $(this).removeData('bs.modal');
    });

	$(document).on('change', 'select[name="fuzzy_option"]', function() {
		var value = $(this).val();
		if ($('#add_accession_fuzzy_option_all').is(":checked")){
			$('select[name="fuzzy_option"] option[value='+value+']').attr('selected','selected');
		}
	});

    $('#review_fuzzy_matches_download').click(function(){
        console.log(fuzzyResponse);
        openWindowWithPost(JSON.stringify(fuzzyResponse));
        //window.open('/ajax/accession_list/fuzzy_download?fuzzy_response='+JSON.stringify(fuzzyResponse));
    });

    jQuery('#review_absent_dialog').on('shown.bs.modal', function (e) {
        jQuery('#infoToAdd_updated_table').DataTable({});
        jQuery('#infoToAdd_new_table').DataTable({});
    });

});

function openWindowWithPost(fuzzyResponse) {
    var f = document.getElementById('add_accession_fuzzy_match_download');
    f.fuzzy_response.value = fuzzyResponse;
    window.open('', 'TheWindow');
    f.submit();
}

function verify_accession_list(accession_list_id) {
    accessionList = JSON.stringify(list.getList(accession_list_id));
    doFuzzySearch = jQuery('#fuzzy_check').prop('checked');

    jQuery.ajax({
        type: 'POST',
        url: '/ajax/accession_list/verify',
        timeout: 36000000,
        //async: false,
        dataType: "json",
        data: {
            'accession_list': accessionList,
            'do_fuzzy_search': doFuzzySearch,
        },
        beforeSend: function(){
            disable_ui();
        },
        success: function (response) {
            enable_ui();
            if (response.error) {
                alert(response.error);
            }
            review_verification_results(doFuzzySearch, response, accession_list_id);
        },
        error: function (response) {
            enable_ui();
	    console.log(response.responseText);

            alert("Ocorreu um erro durante o processamento."+response.responseText);
        }
    });
}

function review_verification_results(doFuzzySearch, verifyResponse, accession_list_id){
    var i;
    var j;
    accessionListFound = {};
    accessionList = [];
    infoToAdd = [];
    speciesNames = [];
    //console.log(verifyResponse);
    //console.log(accession_list_id);

    if (verifyResponse.found) {
        jQuery('#count_of_found_accessions').html("Número total já existente no banco de dados ("+verifyResponse.found.length+")");
        var found_html = "<table class=\"table table-bordered\" id=\"found_accessions_table\"><thead><tr><th>Nome pesquisado</th><th>Encontrado no banco de dados</th></tr></thead><tbody>";
        for( i=0; i < verifyResponse.found.length; i++){
            found_html = found_html
                +'<tr><td>'+verifyResponse.found[i].matched_string
                +'</td><td>'
                +verifyResponse.found[i].unique_name
                +'</td></tr>';
            accessionListFound[verifyResponse.found[i].unique_name] = 1;
        }
        found_html = found_html +'</tbody></table>';

        jQuery('#view_found_matches').html(found_html);

        jQuery('#review_found_matches_dialog').modal('show');

        jQuery('#found_accessions_table').DataTable({});

        accessionList = verifyResponse.absent;

    }

    if (verifyResponse.fuzzy.length > 0 && doFuzzySearch) {
        fuzzyResponse = verifyResponse.fuzzy;
        var fuzzy_html = "<table id=\"add_accession_fuzzy_table\" class=\"table\"><thead><tr><th class=\"col-xs-4\">Nome na sua lista</th><th class=\"col-xs-4\">Nome(s) existente(s) no banco de dados</th><th class=\"col-xs-4\">Opções<input type=\"checkbox\" id=\"add_accession_fuzzy_option_all\"/> Usar a mesma opção para todos</th></tr></thead><tbody>";
        for( i=0; i < verifyResponse.fuzzy.length; i++) {
            fuzzy_html = fuzzy_html + '<tr id="add_accession_fuzzy_option_form'+i+'"><td>'+ verifyResponse.fuzzy[i].name + '<input type="hidden" name="fuzzy_name" value="'+ verifyResponse.fuzzy[i].name + '" /></td>';
            fuzzy_html = fuzzy_html + '<td><select class="form-control" name ="fuzzy_select">';
            for(j=0; j < verifyResponse.fuzzy[i].matches.length; j++){
                if (verifyResponse.fuzzy[i].matches[j].is_synonym){
                    fuzzy_html = fuzzy_html + '<option value="' + verifyResponse.fuzzy[i].matches[j].synonym_of + '">' + verifyResponse.fuzzy[i].matches[j].name + " (SINÔNIMO DE: "+verifyResponse.fuzzy[i].matches[j].synonym_of+')</option>';
                } else {
                    fuzzy_html = fuzzy_html + '<option value="' + verifyResponse.fuzzy[i].matches[j].name + '">' + verifyResponse.fuzzy[i].matches[j].name + '</option>';
                }
            }
            fuzzy_html = fuzzy_html + "</select></td><td><select class=\"form-control\" name=\"fuzzy_option\"><option value=\"keep\">Continuar salvando o nome da sua lista</option><option value=\"replace\">Substituir o nome da sua lista pelo nome existente selecionado</option><option value=\"remove\">Remover o nome da sua lista e ignorá-lo</option><option value=\"synonymize\">Adicionar o nome da sua lista como sinônimo do nome existente selecionado</option></select></td></tr>";
        }
        fuzzy_html = fuzzy_html + '</tbody></table>';
        jQuery('#view_fuzzy_matches').html(fuzzy_html);

        //Add to absent
        for( i=0; i < verifyResponse.fuzzy.length; i++) {
            verifyResponse.absent.push(verifyResponse.fuzzy[i].name);
        }
        accessionList = verifyResponse.absent;
    }

    if (verifyResponse.full_data){
        for(var key in verifyResponse.full_data){
            infoToAdd.push(verifyResponse.full_data[key]);
            speciesNames.push(verifyResponse.full_data[key]['species'])
        }
    }

    jQuery('#review_found_matches_hide').off('click').on('click', function(){

        if (verifyResponse.fuzzy.length > 0 && doFuzzySearch){
            jQuery('#review_fuzzy_matches_dialog').modal('show');
        } else {
            jQuery('#review_fuzzy_matches_dialog').modal('hide');
	    //alert(JSON.stringify(verifyResponse.absent));
	    //alert(JSON.stringify(infoToAdd));
            if (verifyResponse.absent.length > 0 || infoToAdd.length>0){
                populate_review_absent_dialog(verifyResponse.absent, infoToAdd);
            } else {
                alert("Todos os acessos da sua lista já existem no banco de dados. (3)");
            }
        }
    });

    jQuery(document).off('click', '#review_fuzzy_matches_continue').on('click', '#review_fuzzy_matches_continue', function(){
        process_fuzzy_options(accession_list_id);
    });

}

function populate_review_absent_dialog(absent, infoToAdd){
    console.log(infoToAdd);
    console.log(absent);

    jQuery('#count_of_absent_accessions').html("Número total a adicionar ("+absent.length+")");
    var absent_html = '';
    jQuery("#species_name_input").autocomplete({
        source: '/organism/autocomplete'
    });

    for( i=0; i < absent.length; i++){
        absent_html = absent_html
        +'<div class="left">'+absent[i]
        +'</div>';
    }
    jQuery('#view_absent').html(absent_html);
    jQuery('#view_infoToAdd').html('');

    if (infoToAdd.length>0){
        var infoToAdd_html = "<div class=\"well\"><b>Os seguintes novos acessos serão adicionados:</b><br/><br/><table id=\"infoToAdd_new_table\" class=\"table table-bordered table-hover\"><thead><tr><th>Nome único</th><th>Propriedades</th></tr></thead><tbody>";
        for( i=0; i < infoToAdd.length; i++){
            if (!('stock_id' in infoToAdd[i])){
                infoToAdd_html = infoToAdd_html + '<tr><td>'+infoToAdd[i]['germplasmName']+'</td>';
                var infoToAdd_properties_html = '';
                for (key in infoToAdd[i]){
                    if (key != 'uniquename' && key != 'other_editable_stock_props'){
                        infoToAdd_properties_html = infoToAdd_properties_html + key+':'+infoToAdd[i][key]+'   ';
                    }
                    else if (key == 'other_editable_stock_props') {
                        for (key_other in infoToAdd[i][key]) {
                            infoToAdd_properties_html = infoToAdd_properties_html + key_other+':'+infoToAdd[i][key][key_other]+'   ';
                        }
                    }
                }
                infoToAdd_html = infoToAdd_html + '<td>'+infoToAdd_properties_html+'</td></tr>';
            }
        }
        infoToAdd_html = infoToAdd_html + "</tbody></table></div>";
        infoToAdd_html = infoToAdd_html + "<div class=\"well\"><b>Os seguintes acessos serão atualizados:</b><br/><br/><table id=\"infoToAdd_updated_table\" class=\"table table-bordered table-hover\"><thead><tr><th>Nome único</th><th>Propriedades</th></tr></thead><tbody>";
        for( i=0; i < infoToAdd.length; i++){
            if ('stock_id' in infoToAdd[i]){
                infoToAdd_html = infoToAdd_html + '<tr><td>'+infoToAdd[i]['germplasmName']+'</td>';
                var infoToAdd_properties_html = '';
                for (key in infoToAdd[i]){
                    if (key != 'uniquename' && key != 'other_editable_stock_props') {
                        infoToAdd_properties_html = infoToAdd_properties_html + key+':'+infoToAdd[i][key]+'   ';
                    }
                    else if (key == 'other_editable_stock_props') {
                        for (key_other in infoToAdd[i][key]) {
                            infoToAdd_properties_html = infoToAdd_properties_html + key_other+':'+infoToAdd[i][key][key_other]+'   ';
                        }
                    }
                }
                infoToAdd_html = infoToAdd_html + '<td>'+infoToAdd_properties_html+'</td></tr>';
            }
        }
        infoToAdd_html = infoToAdd_html + "</tbody></table></div>";
        jQuery('#view_infoToAdd').html(infoToAdd_html);
        jQuery('#add_accessions_using_list_inputs').hide();
    } else {
        jQuery('#add_accessions_using_list_inputs').show();
    }

    jQuery('#review_absent_dialog').modal('show');
}

function process_fuzzy_options(accession_list_id) {
    var data={};
    jQuery('#add_accession_fuzzy_table').find('tr').each(function(){
        var id=jQuery(this).attr('id');
        if (id !== undefined){
            var row={};
            jQuery(this).find('input,select').each(function(){
                var type = jQuery(this).attr('type');
                if (type == 'radio'){
                    if (jQuery(this).is(':checked')){
                        row[jQuery(this).attr('name')]=jQuery(this).val();
                    }
                } else {
                    row[jQuery(this).attr('name')]=jQuery(this).val();
                }
            });
            data[id]=row;
        }
    });
    console.log(data);
    jQuery.ajax({
        type: 'POST',
        url: '/ajax/accession_list/fuzzy_options',
        dataType: "json",
        data: {
            'accession_list_id': accession_list_id,
            'fuzzy_option_data': JSON.stringify(data),
            'names_to_add': JSON.stringify(accessionList)
        },
        success: function (response) {
            //console.log(response);
            infoToAdd = [];
            speciesNames = [];
            accessionList = response.names_to_add;
            if (accessionList.length > 0){

                if (fullParsedData != null){
                    for (var i=0; i<accessionList.length; i++){
                        var accession_name = accessionList[i];
                        infoToAdd.push(fullParsedData[accession_name]);
                        speciesNames.push(fullParsedData[accession_name]['species']);
                    }
                    for (var accession_name in accessionListFound) {
                        if (accessionListFound.hasOwnProperty(accession_name)) {
                            infoToAdd.push(fullParsedData[accession_name]);
                            speciesNames.push(fullParsedData[accession_name]['species']);
                        }
                    }
                }
                populate_review_absent_dialog(accessionList, infoToAdd);
                jQuery('#review_absent_dialog').modal('show');
            } else {
                alert("Todos os acessos da sua lista agora existem no banco de dados. 2");
            }
        },
        error: function () {
            alert("Ocorreu um erro ao verificar as opções de correspondência aproximada! Não adicione sinônimos a outros sinônimos nem use caracteres especiais!");
        }
    });
}

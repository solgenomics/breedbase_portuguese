/*jslint browser: true, devel: true */
/**

=head1 Vectors.js

Dialogs for managing vectors


=head1 AUTHOR

Mirella Flores<mrf252@cornell.edu>

=cut

*/

var $j = jQuery.noConflict();
var list = new CXGN.List();
var vectorList;
var vector_list_id;
var fuzzyResponse;
var fullParsedData;
var infoToAdd;
var vectorListFound;
var doFuzzySearch;

function disable_ui() {
    jQuery('#working_modal').modal("show");
}

function enable_ui() {
    jQuery('#working_modal').modal("hide");
}

jQuery(document).ready(function ($) {

    function add_vectors(full_info) {

        $.ajax({
            type: 'POST',
            url: '/ajax/create_vector_construct',
            dataType: "json",
            timeout: 36000000,
            data: {
                'data': JSON.stringify(full_info),
            },
            beforeSend: function(){
                disable_ui();
            },
            success: function (response) {
                enable_ui();

                if (response.error) {
                    alert(response.error);
                } else {
                    var html = "Os seguintes vetores foram adicionados!<br/>";
                    for (var i=0; i<response.added.length; i++){
                        html = html + '<a href="/stock/'+response.added[i][0]+'/view">'+response.added[i][1]+'</a><br/>';
                    }
                    jQuery('#add_vectors_saved_message').html(html);
                    jQuery('#add_vectors_saved_message_modal').modal('show');
                }
            },
            error: function (response) {
                alert("Ocorreu um erro durante o processamento."+response.responseText);
            }
        });
    }

    //  review absent vectors
    $('#review_absent_vectors_submit').click(function () {
        if (fullParsedData == undefined){
            var vectorsToAdd = vectorList;

            if (!vectorsToAdd || vectorsToAdd.length == 0) {
                alert("Nenhum vetor para adicionar");
                return;
	        }

            for(var i=0; i<vectorsToAdd.length; i++){
                infoToAdd.push({
                    'defaultDisplayName':vectorsToAdd[i],
                });
            }
        }
        add_vectors(infoToAdd);
        $('#review_absent_dialog').modal("hide");
    });

    $('#new_vectors_submit').click(function () {

	    var uploadFile = jQuery("#new_vectors_upload_file").val();
	    jQuery('#upload_new_vectors_form').attr("action", "/ajax/vectors/verify_vectors_file");
	    if (uploadFile === '') {
                alert("Selecione um arquivo");
                return;
	    }
	    jQuery("#upload_new_vectors_form").submit();

	$('#add_vectors_dialog').modal("hide");
    });

    jQuery('#upload_new_vectors_form').iframePostForm({
        json: false,
        post: function () {
            var vectorFile = jQuery("#new_vectors_upload_file").val();
            jQuery('#working_modal').modal("show");
            if (vectorFile === '') {
                jQuery('#working_modal').modal("hide");
            }
        },
        complete: function (r) {
            var clean_r = r.replace('<pre>', '');
            clean_r = clean_r.replace('</pre>', '');
            response = JSON.parse(clean_r);
            console.log(response);
            jQuery('#working_modal').modal("hide");

            if (response.error || response.error_string) {
                fullParsedData = undefined;
                alert(response.error || response.error_string);
            }
            else if (response.success) {
                fullParsedData = response.full_data;
                doFuzzySearch = jQuery('#fuzzy_check_upload_vectors').attr('checked');
                review_verification_results(doFuzzySearch, response, response.list_id);
            }
            else {
                fullParsedData = undefined;
                alert("Ocorreu um erro desconhecido. Tente novamente mais tarde ou entre em contato conosco.");
            }
        }
    });

    $('[name="add_vectors_link"]').click(function () {

        $('#add_vectors_dialog').modal("show");
        $('#review_found_matches_dialog').modal("hide");
        $('#review_fuzzy_matches_dialog').modal("hide");
        $('#review_absent_dialog').modal("hide");

    });

    jQuery('#vectors_upload_spreadsheet_format_info').click(function(){
        jQuery('#vectors_upload_spreadsheet_format_modal').modal("show");
    });

    $('body').on('hidden.bs.modal', '.modal', function () {
        $(this).removeData('bs.modal');
    });

	$(document).on('change', 'select[name="fuzzy_option"]', function() {
		var value = $(this).val();
		if ($('#add_vector_fuzzy_option_all').is(":checked")){
			$('select[name="fuzzy_option"] option[value='+value+']').attr('selected','selected');
		}
	});

    $('#review_fuzzy_matches_download').click(function(){
        console.log(fuzzyResponse);
        openWindowWithPost(JSON.stringify(fuzzyResponse));
        //window.open('/ajax/vector_list/fuzzy_download?fuzzy_response='+JSON.stringify(fuzzyResponse));
    });

    jQuery('#review_absent_dialog').on('shown.bs.modal', function (e) {
        jQuery('#infoToAdd_updated_table').DataTable({});
        jQuery('#infoToAdd_new_table').DataTable({});
    });

    jQuery('#close_add_vectors_saved_message_modal').click( function() {
        location.reload();
    });

});

function openWindowWithPost(fuzzyResponse) {
    var f = document.getElementById('add_vector_fuzzy_match_download');
    f.fuzzy_response.value = fuzzyResponse;
    window.open('', 'TheWindow');
    f.submit();
}

function review_verification_results(doFuzzySearch, verifyResponse, vector_list_id){
    var i;
    var j;
    vectorListFound = {};
    vectorList = [];
    infoToAdd = [];
    //console.log(verifyResponse);
    //console.log(vector_list_id);

    if (verifyResponse.found) {
        jQuery('#count_of_found_vectors').html("Número total já existente no banco de dados ("+verifyResponse.found.length+")");
        var found_html = "<table class=\"table table-bordered\" id=\"found_vectors_table\"><thead><tr><th>Nome pesquisado</th><th>Encontrado no banco de dados</th></tr></thead><tbody>";
        for( i=0; i < verifyResponse.found.length; i++){
            found_html = found_html
                +'<tr><td>'+verifyResponse.found[i].matched_string
                +'</td><td>'
                +verifyResponse.found[i].unique_name
                +'</td></tr>';
            vectorListFound[verifyResponse.found[i].unique_name] = 1;
        }
        found_html = found_html +'</tbody></table>';

        jQuery('#view_found_matches').html(found_html);

        jQuery('#review_found_matches_dialog').modal('show');

        jQuery('#found_vectors_table').DataTable({});

        vectorList = verifyResponse.absent;
    }

    if (verifyResponse.fuzzy.length > 0 && doFuzzySearch) {
        fuzzyResponse = verifyResponse.fuzzy;
        var fuzzy_html = "<table id=\"add_vector_fuzzy_table\" class=\"table\"><thead><tr><th class=\"col-xs-4\">Nome na sua lista</th><th class=\"col-xs-4\">Nome(s) existente(s) no banco de dados</th><th class=\"col-xs-4\">Opções<input type=\"checkbox\" id=\"add_vector_fuzzy_option_all\"/> Usar a mesma opção para todos</th></tr></thead><tbody>";
        for( i=0; i < verifyResponse.fuzzy.length; i++) {
            fuzzy_html = fuzzy_html + '<tr id="add_vector_fuzzy_option_form'+i+'"><td>'+ verifyResponse.fuzzy[i].name + '<input type="hidden" name="fuzzy_name" value="'+ verifyResponse.fuzzy[i].name + '" /></td>';
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
        vectorList = verifyResponse.absent;
    }

    if (verifyResponse.full_data){
        for(var key in verifyResponse.full_data){
            infoToAdd.push(verifyResponse.full_data[key]);
        }
    }

    jQuery('#review_found_matches_hide').click(function(){

        if (verifyResponse.fuzzy.length > 0 && doFuzzySearch){
            jQuery('#review_fuzzy_matches_dialog').modal('show');

        } else {
            jQuery('#review_fuzzy_matches_dialog').modal('hide');

            if (verifyResponse.absent.length > 0 || infoToAdd.length>0){
                populate_review_absent_dialog(verifyResponse.absent, infoToAdd);
            } else {
                alert("Todos os vetores da sua lista já existem no banco de dados. (3)");
            }
        }
    });

    jQuery(document).on('click', '#review_fuzzy_matches_continue', function(){
        process_fuzzy_options(vector_list_id);
    });

}

function populate_review_absent_dialog(absent, infoToAdd){
    console.log(infoToAdd);
    console.log(absent);

    jQuery('#count_of_absent_vectors').html("Número total a adicionar ("+absent.length+")");
    var absent_html = '';

    for( i=0; i < absent.length; i++){
        absent_html = absent_html
        +'<div class="left">'+absent[i]
        +'</div>';
    }
    jQuery('#view_absent').html(absent_html);
    jQuery('#view_infoToAdd').html('');

    if (infoToAdd.length>0){
        var infoToAdd_html = "<div class=\"well\"><b>Os seguintes novos vetores serão adicionados:</b><br/><br/><table id=\"infoToAdd_new_table\" class=\"table table-bordered table-hover\"><thead><tr><th>Nome único</th><th>Propriedades</th></tr></thead><tbody>";
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
        infoToAdd_html = infoToAdd_html + "<div class=\"well\"><b>Os seguintes vetores serão atualizados:</b><br/><br/><table id=\"infoToAdd_updated_table\" class=\"table table-bordered table-hover\"><thead><tr><th>Nome único</th><th>Propriedades</th></tr></thead><tbody>";
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
    }

    jQuery('#review_absent_dialog').modal('show');
}

function process_fuzzy_options(vector_list_id) {
    var data={};
    jQuery('#add_vector_fuzzy_table').find('tr').each(function(){
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
        url: '/ajax/vector_list/fuzzy_options',
        dataType: "json",
        data: {
            'vector_list_id': vector_list_id,
            'fuzzy_option_data': JSON.stringify(data),
            'names_to_add': JSON.stringify(vectorList)
        },
        success: function (response) {
            //console.log(response);
            infoToAdd = [];
            vectorList = response.names_to_add;
            if (vectorList.length > 0){

                if (fullParsedData != null){
                    for (var i=0; i<vectorList.length; i++){
                        var vector_name = vectorList[i];
                        infoToAdd.push(fullParsedData[vector_name]);
                    }
                    for (var vector_name in vectorListFound) {
                        if (vectorListFound.hasOwnProperty(vector_name)) {
                            infoToAdd.push(fullParsedData[vector_name]);
                        }
                    }
                }
                populate_review_absent_dialog(vectorList, infoToAdd);
                jQuery('#review_absent_dialog').modal('show');
            } else {
                alert("Todos os vetores da sua lista agora existem no banco de dados. 2");
            }
        },
        error: function () {
            alert("Ocorreu um erro ao verificar as opções de correspondência aproximada! Não adicione sinônimos a outros sinônimos nem use caracteres especiais!");
        }
    });
}

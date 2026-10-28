/*jslint browser: true, devel: true */

/**

=head1 AddTrial.js

Dialogs for adding trials


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

    var list = new CXGN.List();

    var design_json;
    var trial_id;
    var stock_list_id;
    var stock_list;
    var check_stock_list_id;
    var check_stock_list;
    var crbd_check_stock_list_id;
    var crbd_check_stock_list;
    var unrep_stock_list_id;
    var unrep_stock_list;
    var rep_stock_list_id;
    var rep_stock_list;
    var seedlot_list_id;
    var seedlot_list;
    var accession_list_seedlot_hash = {};
    var checks_list_seedlot_hash = {};
    var crbd_checks_list_seedlot_hash = {};
    var unrep_list_seedlot_hash = {};
    var rep_list_seedlot_hash = {};
    var plants_per_plot;
    var include_plant_coordinates;
    var num_rows;
    var num_cols;
    var inherits_plot_treatments;

    jQuery('#create_trial_validate_form_button').click(function(){
        create_trial_validate_form();
    });

    jQuery('#add_plant_entries').on('change', function() {
        let plants_per_plot = jQuery(this).val();
        jQuery('#greenhouse_default_num_plants_per_accession_val').val(plants_per_plot);
        //jQuery('#num_plants_per_treatment').val(plants_per_plot);
        greenhouse_show_num_plants_section()
    });

    // jQuery('#num_plants_per_treatment').on('change', function(){
    //     let plants_per_plot = jQuery(this).val();
    //     jQuery('#add_plant_entries').val(plants_per_plot);
    // });

    jQuery('#greenhouse_default_num_plants_per_accession_val').on('change', function() {
        let plants_per_plot = jQuery(this).val();
        jQuery('#add_plant_entries').val(plants_per_plot);
        greenhouse_show_num_plants_section()
    });

    function create_trial_validate_form(){
        var trial_name = $("#new_trial_name").val();
        var breeding_program = $("#select_breeding_program").val();
        var location = $("#add_project_location").val().toString().trim(); // remove whitespace
        var trial_year = $("#add_project_year").val();
        var planting_date = $("#add_project_planting_date").val();
        var description = $("#add_project_description").val();
        var design_type = $("#select_design_method").val();
        var stock_type = $("#select_stock_type").val();
        var plot_width = $("#add_project_plot_width").val();
        var plot_length = $("#add_project_plot_length").val();
	    var plot_numbering_scheme = jQuery('input[name="plot_numbering_scheme"]:checked').val();
        plants_per_plot = $("#add_plant_entries").val();
        num_rows = jQuery('#trial_create_rows_per_plot').val();
        num_cols = jQuery('#trial_create_cols_per_plot').val();
        if (jQuery('#trial_create_rows_and_columns_to_plants').is(':checked')) { 

            include_plant_coordinates = 1;

            if (num_rows == "" || num_cols == "" || num_rows * num_cols == 0) {
                alert("Informe o número de linhas e colunas para atribuir coordenadas às plantas dentro das parcelas.");
                return;
            }
            if (num_rows * num_cols < plants_per_plot) {
                alert("É permitida apenas uma planta por coordenada (linha, coluna). Reduza o número de plantas por parcela ou adicione linhas e colunas.");
                return;
            }
        }
        inherits_plot_treatments = $("trial_create_plants_per_plot_inherit_treatments").val();

        if (trial_name === '') {
            alert("Informe um nome para o ensaio");
        }
        else if (breeding_program === '') {
            alert("Selecione um programa de melhoramento");
        }
        else if (location === '') {
            alert("Selecione pelo menos um local");
        }
        else if (trial_year === '') {
            alert("Selecione o ano do ensaio");
        }
        else if (plot_width < 0 ){
            alert("Verifique a largura da parcela");
        }
        else if (plot_width > 13){
            alert("Verifique a largura da parcela: o valor está muito alto");
        }
        else if (plot_length < 0){
            alert("Verifique o comprimento da parcela");
        }
        else if (plot_length > 13){
            alert("Verifique o comprimento da parcela: o valor está muito alto");
        }
        else if (plants_per_plot > 500) {
            alert("Informe no máximo 500 plantas por parcela.");
        }
        else if (description === '') {
            alert("Informe uma descrição!");
        }
        else if (design_type === '') {
            alert("Selecione um tipo de delineamento");
        }
        else if (stock_type === '') {
            alert("Selecione um tipo de material");
        }
        else {
            verify_create_trial_name(trial_name);
        }
    }

    function verify_create_trial_name(trial_name){
        jQuery.ajax( {
            url: '/ajax/trial/verify_trial_name?trial_name='+trial_name,
            beforeSend: function() {
                jQuery("#working_modal").modal("show");
            },
            success: function(response) {
                jQuery("#working_modal").modal("hide");
                if (response.error){
                    alert(response.error);
                    jQuery('[name="create_trial_submit"]').attr('disabled', true);
                }
                else {
                    jQuery('[name="create_trial_submit"]').attr('disabled', false);
                }
            },
            error: function(response) {
                jQuery("#working_modal").modal("hide");
                alert('Ocorreu um erro ao verificar o nome do ensaio');
            }
        });
    }

    $(document).on('focusout', '#select_list_list_select', function() {
        if ($('#select_list_list_select').val()) {
            stock_list_id = $('#select_list_list_select').val();
            stock_list = JSON.stringify(list.getList(stock_list_id));
            verify_stock_list(stock_list);
            if(stock_list && seedlot_list){
                verify_seedlot_list(stock_list, seedlot_list, 'stock_list');
            } else {
                accession_list_seedlot_hash = {};
            }
        }
    });

    $(document).on('focusout', '#select_cross_list_list_select', function() {
        if ($('#select_cross_list_list_select').val()) {
            cross_list_id = $('#select_cross_list_list_select').val();
            cross_list = JSON.stringify(list.getList(cross_list_id));
            verify_cross_list(cross_list);
        }
    });

    $(document).on('focusout', '#select_family_name_list_list_select', function() {
        if ($('#select_family_name_list_list_select').val()) {
            family_name_list_id = $('#select_family_name_list_list_select').val();
            family_name_list = JSON.stringify(list.getList(family_name_list_id));
            verify_family_name_list(family_name_list);
        }
    });

    $(document).on('focusout', '#list_of_checks_section_list_select', function() {
        if ($('#list_of_checks_section_list_select').val()) {
            check_stock_list_id = $('#list_of_checks_section_list_select').val();
            check_stock_list = JSON.stringify(list.getList(check_stock_list_id));
            verify_stock_list(check_stock_list);
            if(check_stock_list && seedlot_list){
                verify_seedlot_list(check_stock_list, seedlot_list, 'check_stock_list');
            } else {
                checks_list_seedlot_hash = {};
            }
        }
    });

    $(document).on('focusout', '#list_of_cross_checks_section_list_select', function() {
        if ($('#list_of_cross_checks_section_list_select').val()) {
            check_cross_list_id = $('#list_of_cross_checks_section_list_select').val();
            check_cross_list = JSON.stringify(list.getList(check_cross_list_id));
            verify_stock_list(check_cross_list);
        }
    });

    $(document).on('focusout', '#list_of_family_name_checks_section_list_select', function() {
        if ($('#list_of_family_name_checks_section_list_select').val()) {
            check_family_name_list_id = $('#list_of_family_name_checks_section_list_select').val();
            check_family_name_list = JSON.stringify(list.getList(check_family_name_list_id));
            verify_stock_list(check_family_name_list);
        }
    });

    $(document).on('focusout', '#crbd_list_of_checks_section_list_select', function() {
        if ($('#crbd_list_of_checks_section_list_select').val()) {
            crbd_check_stock_list_id = $('#crbd_list_of_checks_section_list_select').val();
            crbd_check_stock_list = JSON.stringify(list.getList(crbd_check_stock_list_id));
            verify_stock_list(crbd_check_stock_list);
            if(crbd_check_stock_list && seedlot_list){
                verify_seedlot_list(crbd_check_stock_list, seedlot_list, 'crbd_check_stock_list');
            } else {
                crbd_checks_list_seedlot_hash = {};
            }
        }
    });

    $(document).on('focusout', '#crbd_list_of_cross_checks_section_list_select', function() {
        if ($('#crbd_list_of_cross_checks_section_list_select').val()) {
            crbd_check_cross_list_id = $('#crbd_list_of_cross_checks_section_list_select').val();
            crbd_check_cross_list = JSON.stringify(list.getList(crbd_check_cross_list_id));
            verify_stock_list(crbd_check_cross_list);
        }
    });

    $(document).on('focusout', '#crbd_list_of_family_name_checks_section_list_select', function() {
        if ($('#crbd_list_of_family_name_checks_section_list_select').val()) {
            crbd_check_family_name_list_id = $('#crbd_list_of_family_name_checks_section_list_select').val();
            crbd_check_family_name_list = JSON.stringify(list.getList(crbd_check_family_name_list_id));
            verify_stock_list(crbd_check_family_name_list);
        }
    });

    $(document).on('focusout', '#list_of_unrep_accession_list_select', function() {
        if ($('#list_of_unrep_accession_list_select').val()) {
            unrep_stock_list_id = $('#list_of_unrep_accession_list_select').val();
            unrep_stock_list = JSON.stringify(list.getList(unrep_stock_list_id));
            verify_stock_list(unrep_stock_list);
            if(unrep_stock_list && seedlot_list){
                verify_seedlot_list(unrep_stock_list, seedlot_list, 'unrep_stock_list');
            } else {
                unrep_list_seedlot_hash = {};
            }
        }
    });

    $(document).on('focusout', '#list_of_unrep_cross_list_select', function() {
        if ($('#list_of_unrep_cross_list_select').val()) {
            unrep_cross_list_id = $('#list_of_unrep_cross_list_select').val();
            unrep_cross_list = JSON.stringify(list.getList(unrep_cross_list_id));
            verify_cross_list(unrep_cross_list);
        }
    });

    $(document).on('focusout', '#list_of_unrep_family_name_list_select', function() {
        if ($('#list_of_unrep_family_name_list_select').val()) {
            unrep_family_name_list_id = $('#list_of_unrep_family_name_list_select').val();
            unrep_family_name_list = JSON.stringify(list.getList(unrep_family_name_list_id));
            verify_family_name_list(unrep_family_name_list);
        }
    });

    $(document).on('focusout', '#list_of_rep_accession_list_select', function() {
        if ($('#list_of_rep_accession_list_select').val()) {
            rep_stock_list_id = $('#list_of_rep_accession_list_select').val();
            rep_stock_list = JSON.stringify(list.getList(rep_stock_list_id));
            verify_stock_list(rep_stock_list);
            if(rep_stock_list && seedlot_list){
                verify_seedlot_list(rep_stock_list, seedlot_list, 'rep_stock_list');
            } else {
                rep_list_seedlot_hash = {};
            }
        }
    });

    $(document).on('focusout', '#list_of_rep_cross_list_select', function() {
        if ($('#list_of_rep_cross_list_select').val()) {
            rep_cross_list_id = $('#list_of_rep_cross_list_select').val();
            rep_cross_list = JSON.stringify(list.getList(rep_cross_list_id));
            verify_cross_list(rep_cross_list);
        }
    });

    $(document).on('focusout', '#list_of_rep_family_name_list_select', function() {
        if ($('#list_of_rep_family_name_list_select').val()) {
            rep_family_name_list_id = $('#list_of_rep_family_name_list_select').val();
            rep_family_name_list = JSON.stringify(list.getList(rep_family_name_list_id));
            verify_family_name_list(rep_family_name_list);
        }
    });

    $(document).on('focusout', '#select_seedlot_list_list_select', function() {
        if ($('#select_seedlot_list_list_select').val() ) {
            seedlot_list_id = $('#select_seedlot_list_list_select').val();
            seedlot_list = JSON.stringify(list.getList(seedlot_list_id));
            if(stock_list && seedlot_list){
                verify_seedlot_list(stock_list, seedlot_list, 'stock_list');
            } else {
                alert('Selecione uma lista de acessos acima!');
            }
            if(check_stock_list && seedlot_list){
                verify_seedlot_list(check_stock_list, seedlot_list, 'check_stock_list');
            }
            if(crbd_check_stock_list && seedlot_list){
                verify_seedlot_list(crbd_check_stock_list, seedlot_list, 'crbd_check_stock_list');
            }
            if(unrep_stock_list && seedlot_list){
                verify_seedlot_list(unrep_stock_list, seedlot_list, 'unrep_stock_list');
            }
            if(rep_stock_list && seedlot_list){
                verify_seedlot_list(rep_stock_list, seedlot_list, 'rep_stock_list');
            }
        } else {
            seedlot_list = undefined;
            seedlot_list_verified = 1;
            if (stock_list){
                verify_stock_list(stock_list);
            }
            accession_list_seedlot_hash = {};
            checks_list_seedlot_hash = {};
            crbd_checks_list_seedlot_hash = {};
            unrep_list_seedlot_hash = {};
            rep_list_seedlot_hash = {};
        }
    });

    $(document).on('click', 'button[name="convert_accessions_to_seedlots"]', function(){
        if (!stock_list_id){
            alert('Selecione primeiro uma lista de acessos acima!');
        } else {
            var list = new CXGN.List();
            list.seedlotSearch(stock_list_id);
        }
    });

    var stock_list_verified = 0;
    function verify_stock_list(stock_list) {
        $.ajax({
            type: 'POST',
            timeout: 3000000,
            url: '/ajax/trial/verify_stock_list',
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            dataType: "json",
            data: {
                'stock_list': stock_list,
            },
            success: function (response) {
                //console.log(response);
                jQuery('#working_modal').modal('hide');
                if (response.error) {
                    alert(response.error);
                    stock_list_verified = 0;
                }
                if (response.success){
                    stock_list_verified = 1;
                }
            },
            error: function () {
                jQuery('#working_modal').modal('hide');
                alert('Ocorreu um erro.');
                stock_list_verified = 0;
            }
        });
    }

    var seedlot_list_verified = 1;
    function verify_seedlot_list(stock_list, seedlot_list, type) {
        $.ajax({
            type: 'POST',
            timeout: 3000000,
            url: '/ajax/trial/verify_seedlot_list',
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            dataType: "json",
            data: {
                'stock_list': stock_list,
                'seedlot_list': seedlot_list,
            },
            success: function (response) {
                //console.log(response);
                jQuery('#working_modal').modal('hide');
                if (response.error) {
                    alert(response.error);
                    seedlot_list_verified = 0;
                }
                if (response.success){
                    seedlot_list_verified = 1;
                    if (type == 'stock_list'){
                        accession_list_seedlot_hash = response.seedlot_hash;
                    }
                    if (type = 'check_stock_list'){
                        checks_list_seedlot_hash = response.seedlot_hash;
                    }
                    if (type == 'crbd_check_stock_list'){
                        crbd_checks_list_seedlot_hash = response.seedlot_hash;
                    }
                    if (type == 'unrep_stock_list'){
                        unrep_list_seedlot_hash = response.seedlot_hash;
                    }
                    if (type == 'rep_stock_list'){
                        rep_list_seedlot_hash = response.seedlot_hash;
                    }
                }
            },
            error: function () {
                jQuery('#working_modal').modal('hide');
                alert('Ocorreu um erro.');
                seedlot_list_verified = 0;
            }
        });
    }

    var cross_list_verified = 0;
    function verify_cross_list(cross_list) {
        $.ajax({
            type: 'POST',
            timeout: 3000000,
            url: '/ajax/trial/verify_cross_list',
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            dataType: "json",
            data: {
                'cross_list': cross_list,
            },
            success: function (response) {
                //console.log(response);
                jQuery('#working_modal').modal('hide');
                if (response.error) {
                    alert(response.error);
                    cross_list_verified = 0;
                }
                if (response.success){
                    cross_list_verified = 1;
                }
            },
            error: function () {
                jQuery('#working_modal').modal('hide');
                alert('Ocorreu um erro.');
                cross_list_verified = 0;
            }
        });
    }

    var family_name_list_verified = 0;
    function verify_family_name_list(family_name_list) {
        $.ajax({
            type: 'POST',
            timeout: 3000000,
            url: '/ajax/trial/verify_family_name_list',
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            dataType: "json",
            data: {
                'family_name_list': family_name_list,
            },
            success: function (response) {
                //console.log(response);
                jQuery('#working_modal').modal('hide');
                if (response.error) {
                    alert(response.error);
                    family_name_list_verified = 0;
                }
                if (response.success){
                    family_name_list_verified = 1;
                }
            },
            error: function () {
                jQuery('#working_modal').modal('hide');
                alert('Ocorreu um erro.');
                family_name_list_verified = 0;
            }
        });
    }

    jQuery('#add_project_trial_sourced').change(function(){
        if(jQuery(this).val() == 'yes'){
            jQuery('#add_trial_source_trial_section').show();
        } else {
            jQuery('#add_trial_source_trial_section').hide();
        }
    });

    jQuery(document).on('click', '#create_trial_with_treatment_additional_treatment_buton', function(){
        var count = jQuery('#create_trial_with_treatment_additional_count').val();
        var new_count = parseInt(count) + 1;
        var return_count = new_count + 4;
        var html = '';
        for (var i=0; i<new_count; i++){
            var display_count = i + 5;
            html = html + '<div class="form-group form-group-sm" ><label class="col-sm-7 control-label">Tratamento '+display_count+ ': </label><div class="col-sm-5" ><input class="form-control  treatment-name-input-box" id="create_trial_with_treatment_name_input'+display_count+'" name="create_trial_with_treatment_name_input'+display_count+'" type="text" placeholder="Tratamento opcional '+display_count+'"/><input class="form-control treatment-value-input-box" id="create_trial_with_treatment_value_input'+display_count+'" name="create_trial_with_treatment_value_input'+display_count+'" type="text" placeholder="valor do tratamento"/></div></div>';
        }
        html = html + '<input type="hidden" id="create_trial_with_treatment_additional_count" value='+return_count+'><div class="form-group form-group-sm" ><label class="col-sm-7 control-label">Adicionar outro tratamento: </label><div class="col-sm-5" ><button class="btn btn-info btn-sm" id="create_trial_with_treatment_additional_treatment_buton">+ Tratamento</button></div></div>';
        jQuery('#create_trial_with_treatment_additional_treatment').html(html);
        apply_treatment_autocomplete();
        return false;
    });

    apply_treatment_autocomplete();

    function apply_treatment_autocomplete() {
        jQuery('.treatment-name-input-box').each( function() {
            jQuery(this).autocomplete({
                source : '/ajax/cvterm/autocompleteslim' + "?db_name=_TREATMENT",
                appendTo : '#add_project_dialog'
            });
        });
    }

    var num_plants_per_plot = 0;
    var num_subplots_per_plot = 0;

    function generate_experimental_design() {
        var name = $('#new_trial_name').val();
        var year = $('#add_project_year').val();
        var planting_date = $('#add_project_planting_date').val();
        // date formatting here from js to breedbase format
        if (planting_date) {
            planting_date = new Date(planting_date).toLocaleDateString("en-CA");
        }
        var desc = $('#add_project_description').val();
        var locations = jQuery('#add_project_location').val();
        var trial_location =  JSON.stringify(locations);
        var trial_stock_type = jQuery('#select_stock_type').val();
        var block_number = $('#block_number').val();
        var row_number= $('#row_number').val();
        var row_number_per_block=$('#row_number_per_block').val();
        var col_number_per_block=$('#col_number_per_block').val();
        var col_number=$('#col_number').val();
	    var plot_numbering_scheme = jQuery('input[name="plot_numbering_scheme"]:checked').val();

        var stock_list_id;
        var control_stock_list_id;
        var control_stock_list_id_crbd;
        var replicated_stock_list_id;
        var unreplicated_stock_list_id;

        if (trial_stock_type == "accession"){
            stock_list_id = $('#select_list_list_select').val();
            control_stock_list_id = $('#list_of_checks_section_list_select').val();
            control_stock_list_id_crbd = $('#crbd_list_of_checks_section_list_select').val();
            replicated_stock_list_id = $('#list_of_rep_accession_list_select').val();
            unreplicated_stock_list_id = $('#list_of_unrep_accession_list_select').val();
        } else if (trial_stock_type == "cross") {
            stock_list_id = $('#select_cross_list_list_select').val();
            control_stock_list_id = $('#list_of_cross_checks_section_list_select').val();
            control_stock_list_id_crbd = $('#crbd_list_of_cross_checks_section_list_select').val();
            replicated_stock_list_id = $('#list_of_rep_cross_list_select').val();
            unreplicated_stock_list_id = $('#list_of_unrep_cross_list_select').val();
        } else if (trial_stock_type == "family_name") {
            stock_list_id = $('#select_family_name_list_list_select').val();
            control_stock_list_id = $('#list_of_family_name_checks_section_list_select').val();
            control_stock_list_id_crbd = $('#crbd_list_of_family_name_checks_section_list_select').val();
            replicated_stock_list_id = $('#list_of_rep_family_name_list_select').val();
            unreplicated_stock_list_id = $('#list_of_unrep_family_name_list_select').val();
        }

        var stock_list;
        var stock_list_array;
        if (stock_list_id) {
            stock_list_array = list.getList(stock_list_id);
            stock_list = JSON.stringify(stock_list_array);
        }

        var control_list;
        var control_list_array;
        if(control_stock_list_id) {
            control_list_array = list.getList(control_stock_list_id);
            control_list = JSON.stringify(control_list_array);
        }

        var control_list_crbd;
        var control_list_crbd_array;
        if (control_stock_list_id_crbd) {
            control_list_crbd_array = list.getList(control_stock_list_id_crbd);
            control_list_crbd = JSON.stringify(control_list_crbd_array);
        }

        var design_type = $('#select_design_method').val();
        if (design_type == "") {
            var design_type = $('#select_multi-design_method').val();
        }

        var rep_count = $('#rep_count').val();
        var block_size = $('#block_size').val();
        var max_block_size = $('#max_block_size').val();
        var plot_prefix = $('#plot_prefix').val();
        var start_number = $('#start_number').val();
        var increment = $('#increment').val();
        var fieldmap_col_number = $('#fieldMap_col_number').val();
        var fieldmap_row_number = $('#fieldMap_row_number').val();
        var plot_layout_format = $('#plot_layout_format').val();
        var row_in_design_number = $('#no_of_row_in_design').val();
        var col_in_design_number = $('#no_of_col_in_design').val();
        var no_of_rep_times = $('#no_of_rep_times').val();
        var no_of_block_sequence = $('#no_of_block_sequence').val();
        var no_of_sub_block_sequence = $('#no_of_sub_block_sequence').val();
        var num_seed_per_plot = $('#num_seed_per_plot').val();
        var westcott_check_1 = $('#westcott_check_1').val();
        var westcott_check_2 = $('#westcott_check_2').val();
        var westcott_col = $('#westcott_col').val();
        var westcott_col_between_check = $('#westcott_col_between_check').val();
        var plot_width = $('#add_project_plot_width').val();
        var plot_length = $('#add_project_plot_length').val();
        var field_size = $('#new_trial_field_size').val();
        var seedlot_hash_combined = {};
        seedlot_hash_combined = extend_obj(accession_list_seedlot_hash, checks_list_seedlot_hash);
        seedlot_hash_combined = extend_obj(seedlot_hash_combined, crbd_checks_list_seedlot_hash);
        seedlot_hash_combined = extend_obj(seedlot_hash_combined, unrep_list_seedlot_hash);
        seedlot_hash_combined = extend_obj(seedlot_hash_combined, rep_list_seedlot_hash);
        if (!jQuery.isEmptyObject(seedlot_hash_combined)){
            if (num_seed_per_plot == ''){
                alert('Informe o número de sementes por parcela ao selecionar uma lista de lotes de sementes!');
                return;
            }
        }

        var unreplicated_stock_list;
        if (unreplicated_stock_list_id) {
            unreplicated_stock_list = JSON.stringify(list.getList(unreplicated_stock_list_id));
        }

        var replicated_stock_list;
        if (replicated_stock_list_id) {
            replicated_stock_list = JSON.stringify(list.getList(replicated_stock_list_id));
        }

        var treatments = {};
        if (design_type == 'splitplot'){
            var count = jQuery('#create_trial_with_treatment_additional_count').val();
            if (count == 0) {
                count = 4; //Interface starts with 4 inputs and user can add additional ones..
            }
            var int_count = parseInt(count);
            for(var i=1; i<=int_count; i++){
                var treatment_name = jQuery('#create_trial_with_treatment_name_input'+i).val();
                var treatment_value = jQuery('#create_trial_with_treatment_value_input'+i).val();
                if(treatment_name != '' && treatment_value != ''){
                    if (treatment_name in treatments) {
                        treatments[treatment_name].push(treatment_value);
                    } else {
                        treatments[treatment_name] = [];
                        treatments[treatment_name].push(treatment_value);
                    }
                }
            }
            var num_plants_per_treatment = $('#num_plants_per_treatment').val();
            num_plants_per_plot = 0;
            var aggregator = 1;
            for (treatment in treatments) {
                var num_levels = Object.keys(treatments[treatment]).length
                aggregator = aggregator * num_levels;
            }
            num_subplots_per_plot = aggregator;
            if (num_plants_per_treatment){
                num_plants_per_plot = num_plants_per_treatment*num_subplots_per_plot;
            } else {
                alert("Informe o número de plantas por tratamento.");
                return;
            }
        }

        var greenhouse_num_plants = [];
        if (stock_list_id && design_type == 'greenhouse') {
            for (var i=0; i<stock_list_array.length; i++) {
                var value = jQuery("input#greenhouse_num_plants_input_" + i).val();
                if (value == '') {
                    value = 1;
                }
                greenhouse_num_plants.push(value);
            }
            //console.log(greenhouse_num_plants);
        }

        var num_rows_per_plot = $('#trial_create_rows_per_plot').val();
        var num_cols_per_plot = $('#trial_create_cols_per_plot').val();
        if ($('#trial_create_rows_and_columns_to_plants').prop('checked') && (
            $('#add_plant_entries').val() > num_rows_per_plot * num_cols_per_plot ||
            num_rows_per_plot * num_cols_per_plot < Math.max(...greenhouse_num_plants.map(Number)) ||
            num_rows_per_plot * num_cols_per_plot < num_plants_per_treatment
        )) {
            alert("Você especificou coordenadas dentro das parcelas, mas o número de plantas por parcela excede o número de posições disponíveis. Reduza o número de plantas por parcela ou aumente o número de posições disponíveis. Em ensaios em casa de vegetação, verifique se nenhum acesso tem mais plantas do que posições disponíveis. Em delineamentos em parcelas subdivididas, verifique se o número de plantas por parcela informado na seção (2) corresponde ao número de plantas por tratamento.");
            return;
        }

        var use_same_layout;
        if ($('#use_same_layout').is(':checked')) {
           use_same_layout = $('#use_same_layout').val();
        }
        else {
           use_same_layout = "";
        }

	    var plot_numbering_scheme = $('input[name="plot_numbering_scheme"]:checked').val();

        var plot_name_template = null;
        var active_plot_naming_tab = jQuery('#plot_naming_tabs li.active a').attr('href');
        if (active_plot_naming_tab === '#plot_naming_tab_template') {
            var selected_template = jQuery('input[name="plot_name_template_idx"]:checked');
            if (selected_template.length > 0) {
                var template_idx = selected_template.val();
                var templates = jQuery('#plot_template_radios').data('templates');
                if (templates && templates[template_idx]) {
                    plot_name_template = JSON.stringify(templates[template_idx]);
                }
            }
        }

        $.ajax({
            type: 'POST',
            timeout: 3000000,
            url: '/ajax/trial/generate_experimental_design',
            dataType: "json",
            beforeSend: function() {
                $('#working_modal').modal("show");
            },
            data: {
                'project_name': name,
                'project_description': desc,
                'year': year,
                'planting date' : planting_date,
                'trial_location': trial_location,
                'trial_stock_type': trial_stock_type,
                'stock_list': stock_list,
                'control_list': control_list,
                'control_list_crbd': control_list_crbd,
                'design_type': design_type,
                'rep_count': rep_count,
                'block_number': block_number,
                'row_number': row_number,
                'row_number_per_block': row_number_per_block,
                'col_number_per_block': col_number_per_block,
                'col_number': col_number,
                'block_size': block_size,
                'max_block_size': max_block_size,
                'plot_prefix': plot_prefix,
                'start_number': start_number,
                'increment': increment,
                'greenhouse_num_plants': JSON.stringify(greenhouse_num_plants),
                'fieldmap_col_number': fieldmap_col_number,
                'fieldmap_row_number': fieldmap_row_number,
                'plot_layout_format': plot_layout_format,
                'treatments': JSON.stringify(treatments),
                'num_plants_per_plot':num_plants_per_plot,
                'row_in_design_number': row_in_design_number,
                'col_in_design_number': col_in_design_number,
                'no_of_rep_times': no_of_rep_times,
                'no_of_block_sequence': no_of_block_sequence,
                'unreplicated_stock_list': unreplicated_stock_list,
                'replicated_stock_list': replicated_stock_list,
                'no_of_sub_block_sequence': no_of_sub_block_sequence,
                'seedlot_hash': JSON.stringify(seedlot_hash_combined),
                'num_seed_per_plot': num_seed_per_plot,
                'westcott_check_1': westcott_check_1,
                'westcott_check_2': westcott_check_2,
                'westcott_col': westcott_col,
                'westcott_col_between_check': westcott_col_between_check,
                'field_size': field_size,
                'plot_width': plot_width,
                'plot_length': plot_length,
                'use_same_layout' : use_same_layout,
		        'plot_numbering_scheme' : plot_numbering_scheme,
                'num_cols_per_plot' : num_cols_per_plot,
                'num_rows_per_plot' : num_rows_per_plot,
                'plot_name_template': plot_name_template,
                'breeding_program_name': jQuery('#select_breeding_program option:selected').text()
            },
            success: function (response) {
                $('#working_modal').modal("hide");
                if (response.error) {
                    alert(response.error);
                } else {

                    Workflow.focus("#trial_design_workflow", 6); //Go to review page

                    if(response.warning_message){
                        jQuery('#trial_design_warning_message').html("<center><div class='well'><h4 class='text-warning'>Aviso: "+response.warning_message+"</h4></div></center>");
                    } else {
                        jQuery('#trial_design_warning_message').html('');
                    }

                    $('#trial_design_information').html(response.design_info_view_html);
                    var layout_view = JSON.parse(response.design_layout_view_html);
                    //console.log(layout_view);
                    var layout_html = '';
                    for (var i=0; i<layout_view.length; i++) {
                        //console.log(layout_view[i]);
                        layout_html += layout_view[i] + '<br>';
                    }
                    $('#trial_design_view_layout_return').html(layout_html);

                    $('#working_modal').modal("hide");
                    design_json = response.design_json;

                    var col_length = response.design_map_view.coord_col[0];
                    var row_length = response.design_map_view.coord_row[0];
                    var block_max = response.design_map_view.max_block;
                    var rep_max = response.design_map_view.max_rep;
                    var col_max =  response.design_map_view.max_col;
                    var row_max =  response.design_map_view.max_row;
                    var controls = response.design_map_view.controls;
                    var false_coord = response.design_map_view.false_coord;

                    var dataset = [];
                    if (design_type == 'splitplot'){
                        row_length = response.design_map_view.coord_row[1];
                        dataset = response.design_map_view.result;
                        dataset.shift();
                    }else {
                        dataset = response.design_map_view.result;
                    }

                    if (col_length && row_length) {
                        jQuery("#container_field_map_view").css({"display": "inline-block", "overflow": "auto"});
                        jQuery("#d3_legend").css("display", "inline-block");

                      var margin = { top: 50, right: 0, bottom: 100, left: 30 },
                          width = 50 * col_max + 30 - margin.left - margin.right,
                          height = 50 * row_max + 100 - margin.top - margin.bottom,
                          gridSize = 50,
                          legendElementWidth = gridSize*2,
                          rows = response.design_map_view.unique_row,
                          columns = response.design_map_view.unique_col;
                          //datasets = response.design_map_view.result;
                          datasets = dataset;

                      var svg = d3.select("#container_field_map_view").append("svg")
                          .attr("width", width + margin.left + margin.right)
                          .attr("height", height + margin.top + margin.bottom)
                          .append("g")
                          .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

                      var rowLabels = svg.selectAll(".rowLabel")
                          .data(rows)
                          .enter().append("text")
                            .text(function (d) { return d; })
                            .attr("x", 0 )
                            .attr("y", function (d, i) { return i * gridSize; })
                            .style("text-anchor", "end")
                            .attr("transform", "translate(-6," + gridSize / 1.5 + ")")
                            .attr("class", function (d, i) { return ((i >= 0 && i <= 4) ? "rowLabel mono axis axis-workweek" : "rowLabel mono axis"); });

                      var columnLabels = svg.selectAll(".columnLabel")
                          .data(columns)
                          .enter().append("text")
                            .text(function(d) { return d; })
                            .attr("x", function(d, i) { return i * gridSize; })
                            .attr("y", 0 )
                            .style("text-anchor", "middle")
                            .attr("transform", "translate(" + gridSize / 2 + ", -6)")
                            .attr("class", function(d, i) { return ((i >= 7 && i <= 16) ? "columnLabel mono axis axis-worktime" : "columnLabel mono axis"); });

                      var heatmapChart = function(datasets) {

                        datasets.forEach(function(d) {

                            d.row = +d.row;
                            d.col = +d.col;
                            d.blkn = +d.blkn;
                        });

                          var cards = svg.selectAll(".col")
                              .data(datasets, function(d) {return d.row+':'+d.col;});

                          cards.append("title");

                          var colors = function (d, i){
                              if (block_max == 1){
                                color = '#41b6c4';
                              }
                              else if (block_max > 1){
                                if (d.blkn % 2 == 0){
                                    color = '#c7e9b4';
                                }
                                else{
                                    color = '#41b6c4'
                                }
                              }
                              else{
                                color = '#c7e9b4';
                              }
                              if (controls) {
                                for (var i = 0; i < controls.length; i++) {
                                  if ( controls[i] == d.stock) {
                                    color = '#081d58';
                                  }
                                }
                              }
                              return color;
                            }

                            var strokes = function (d, i){
                                var stroke;
                                if (rep_max == 1){
                                  stroke = 'green';
                                }
                                else if (rep_max > 1){
                                  if (d.rep % 2 == 0){
                                      stroke = 'red';
                                  }
                                  else{
                                      stroke = 'green'
                                  }
                                }
                                else{
                                  stroke = 'red';
                                }
                                return stroke;
                              }

                          cards.enter().append("rect")
                              .attr("x", function(d) { return (d.col - 1) * gridSize; })
                              .attr("y", function(d) { return (d.row - 1) * gridSize; })
                              .attr("rx", 4)
                              .attr("ry", 4)
                              .attr("class", "col bordered")
                              .attr("width", gridSize)
                              .attr("height", gridSize)
                              .style("stroke-width", 2)
                              .style("stroke", strokes)
                              .style("fill", colors)
                              .on("mouseover", function(d) { d3.select(this).style('fill', 'green'); })
                              .on("mouseout", function(d) {
                                                              var cards = svg.selectAll(".col")
                                                                  .data(datasets, function(d) {return d.row+':'+d.col;});

                                                              cards.append("title");

                                                              cards.enter().append("rect")
                                                                .attr("x", function(d) { return (d.col - 1) * gridSize; })
                                                                .attr("y", function(d) { return (d.row - 1) * gridSize; })
                                                                .attr("rx", 4)
                                                                .attr("ry", 4)
                                                                .attr("class", "col bordered")
                                                                .attr("width", gridSize)
                                                                .attr("height", gridSize)
                                                                .style("stroke-width", 2)
                                                                .style("stroke", strokes)
                                                                .style("fill", colors);

                                                                cards.style("fill", colors) ;

                                                                cards.select("title").text(function(d) { return d.plot_msg; }) ;

                                                                cards.exit().remove();
                                                                //console.log('out');
                                                            });


                          cards.style("fill", colors) ;

                          cards.select("title").text(function(d) { return d.plot_msg; }) ;

                          cards.append("text");
                          cards.enter().append("text")
                            .attr("x", function(d) { return (d.col - 1) * gridSize + 10; })
                            .attr("y", function(d) { return (d.row - 1) * gridSize + 20 ; })
                            .text(function(d) { return d.plotn; });

                          cards.select("text").text(function(d) { return d.plotn; }) ;

                          cards.exit().remove();

                        // });
                        } ;

                      heatmapChart(datasets);
                      if (false_coord){
                          alert("Foram gerados números provisórios de linhas e colunas para exibir a disposição espacial ou o mapa. As parcelas são exibidas em zigue-zague. Esses números de linhas e colunas não serão salvos no banco de dados. Clique em OK para continuar...");
                      }
                  }else {
                      jQuery("#d3_legend").css("display", "none");
                      jQuery("#container_field_map_view").css("display", "none");
                      jQuery("#no_map_view_MSG").css("display", "inline-block");
                  }

                }
            },
            error: function () {
                $('#working_modal').modal("hide");
                alert('Ocorreu um erro.');
            }
       });
    }

    //When the user submits the form, input validation happens here before proceeding to design generation
    $(document).on('click', '#new_trial_submit', function () {
        d3.selectAll("#container_field_map_view > *").remove();
        jQuery("#container_field_map_view").css("display", "none");
        var name = $('#new_trial_name').val();
        var year = $('#add_project_year').val();
        var planting_date = $('#add_project_planting_date').val();
        var desc = $('textarea#add_project_description').val();
        if (name == '') {
            alert('Informe o nome do ensaio');
            return;
        }
        if (year === '' || desc === '') {
            alert('Informe o ano e a descrição.');
            return;
        }
        if(desc === '') {
            alert('Informe a descrição.');
            return;
        }
        if (stock_list_verified == 1 && seedlot_list_verified == 1){
            generate_experimental_design();
        } else if (cross_list_verified == 1 && stock_list_verified == 0 && family_name_list_verified == 0){
            generate_experimental_design();
        } else if (family_name_list_verified == 1 && cross_list_verified == 0 && stock_list_verified == 0){
            generate_experimental_design();
        } else {
            alert('A lista de acessos, lotes de sementes, cruzamentos ou nomes de famílias é inválida!');
            return;
        }
    });

    $(document).on('change', '#select_stock_type', function () {

        var stock_type = jQuery('#select_stock_type').val();

        //add lists to the list select and list of checks select dropdowns based on stock type.
        if (stock_type == "accession"){
            document.getElementById("select_list").innerHTML = list.listSelect("select_list", [ 'accessions' ], 'selecione uma lista', 'refresh', undefined);
            document.getElementById("select_seedlot_list").innerHTML = list.listSelect("select_seedlot_list", [ 'seedlots' ], 'nenhuma', 'refresh', undefined);
            document.getElementById("list_of_checks_section").innerHTML = list.listSelect("list_of_checks_section", [ 'accessions' ], 'selecione uma lista opcional de testemunhas', 'refresh', undefined);
            document.getElementById("crbd_list_of_checks_section").innerHTML = list.listSelect("crbd_list_of_checks_section", [ 'accessions' ], "selecione uma lista opcional de testemunhas", 'refresh', undefined);
            document.getElementById("list_of_unrep_accession").innerHTML = list.listSelect("list_of_unrep_accession", [ 'accessions' ], "Obrigatório: ex. 200", 'refresh', undefined);
            document.getElementById("list_of_rep_accession").innerHTML = list.listSelect("list_of_rep_accession", [ 'accessions' ], "Obrigatório: ex. 119", 'refresh', undefined);
        } else if (stock_type == "cross") {
            document.getElementById("select_cross_list").innerHTML = list.listSelect("select_cross_list", [ 'crosses' ], 'selecione uma lista', 'refresh', undefined);
            document.getElementById("list_of_cross_checks_section").innerHTML = list.listSelect("list_of_cross_checks_section", [ 'accessions' ], 'selecione uma lista opcional de testemunhas', 'refresh', undefined);
            document.getElementById("crbd_list_of_cross_checks_section").innerHTML = list.listSelect("crbd_list_of_cross_checks_section", [ 'accessions' ], "selecione uma lista opcional de testemunhas", 'refresh', undefined);
            document.getElementById("list_of_unrep_cross").innerHTML = list.listSelect("list_of_unrep_cross", [ 'crosses' ], "Obrigatório: ex. 200", 'refresh', undefined);
            document.getElementById("list_of_rep_cross").innerHTML = list.listSelect("list_of_rep_cross", [ 'crosses' ], "Obrigatório: ex. 119", 'refresh', undefined);
        } else if (stock_type == "family_name") {
            document.getElementById("select_family_name_list").innerHTML = list.listSelect("select_family_name_list", [ 'family_names' ], 'selecione uma lista', 'refresh', undefined);
            document.getElementById("list_of_family_name_checks_section").innerHTML = list.listSelect("list_of_family_name_checks_section", [ 'accessions' ], 'selecione uma lista opcional de testemunhas', 'refresh', undefined);
            document.getElementById("crbd_list_of_family_name_checks_section").innerHTML = list.listSelect("crbd_list_of_family_name_checks_section", [ 'accessions' ], "selecione uma lista opcional de testemunhas", 'refresh', undefined);
            document.getElementById("list_of_unrep_family_name").innerHTML = list.listSelect("list_of_unrep_family_name", [ 'family_names' ], "Obrigatório: ex. 200", 'refresh', undefined);
            document.getElementById("list_of_rep_family_name").innerHTML = list.listSelect("list_of_rep_family_name", [ 'family_names' ], "Obrigatório: ex. 119", 'refresh', undefined);
        }

    });

    $(document).on('change', '#select_design_method', function () {

        var design_method = $("#select_design_method").val();
        var stock_type = jQuery('#select_stock_type').val();
        console.log("The method is: ", design_method);
        if (design_method == "CRD"){
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Gera um delineamento inteiramente casualizado (CRD), com número igual ou diferente de repetições, usando os métodos de geração de números aleatórios do R. Cria registros de parcelas no banco de dados.</p></div>');
        } else if (design_method == "RCBD") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Gera um delineamento em blocos completos casualizados (RCBD), usando os métodos de geração de números aleatórios do R. Cria registros de parcelas no banco de dados.</p></div>');
        } else if (design_method == "RRC") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Gera um delineamento resolúvel em linhas e colunas (RRC), usando o pacote blocksdesign do R. Além dos blocos em uma direção, impõe a restrição de que nenhum tratamento apareça mais de uma vez em cada linha (latinização). Cada linha constitui um bloco incompleto.</p></div>');
        } else if (design_method == "DRRC") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Gera um delineamento duplamente resolúvel em linhas e colunas (DRRC), usando o pacote blocksdesign do R. Cria blocos completos nas colunas e nas linhas. O número de acessos deve ser divisível pelo número de colunas e pelo número de linhas.</p></div>');
        } else if (design_method == "URDD") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Gera um delineamento diagonal sem repetição (URDD), usando o pacote FieldHub do R, com opção de criar blocos. Todas as testemunhas são distribuídas em diagonais.</p></div>');
        } else if (design_method == "Alpha") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Gera um delineamento alfa a partir das quatro séries formuladas por Patterson e Williams. Cria registros de parcelas no banco de dados.</p></div>');
        } else if (design_method == "Lattice") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Gera delineamentos em látice simples e triplo usando a função design.lattice do pacote agricolae do R. Casualiza os tratamentos em um látice K x K. Cria registros de parcelas no banco de dados.</p></div>');
        } else if (design_method == "Augmented") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Gera um delineamento aumentado. Alguns tratamentos (testemunhas) são repetidos r vezes e os demais (novos) aparecem uma única vez. Cria registros de parcelas no banco de dados.</p></div>');
        } else if (design_method == "MAD") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Os ajustes são calculados usando os dados de todas as testemunhas. Cria registros de parcelas no banco de dados.</p></div>');
        } else if (design_method == "greenhouse") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Uma casa de vegetação ou viveiro abriga plantas sem um delineamento espacial específico. As plantas podem pertencer a acessos identificados ou, no caso de viveiros de mudas oriundas de cruzamentos, a cruzamentos identificados. Cria registros de parcelas com suas plantas no banco de dados.</p></div>');
        } else if (design_method == "splitplot") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Delineamentos em parcelas subdivididas permitem aplicar tratamentos às subparcelas de uma parcela. Ao informar dois tratamentos com dois níveis cada, haverá quatro subparcelas, com as quatro combinações de tratamentos distribuídas aleatoriamente entre elas. Cria registros de parcelas, subparcelas e plantas no banco de dados.</p></div>');
        } else if (design_method == "p-rep") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Possui tratamentos sem repetição e utiliza os tratamentos repetidos para permitir a análise do ensaio. Recomenda-se que pelo menos 20% das unidades experimentais sejam ocupadas por tratamentos repetidos. Cria registros de parcelas no banco de dados.</p></div>');
        } else if (design_method == "Westcott") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Gera um plano de campo para um delineamento sem repetição, com genótipos distribuídos aleatoriamente e testemunhas dispostas conforme o método descrito por Westcott (1981).</p></div>');
        } else {
            jQuery('#create_trial_design_description_div').html('');
        }


        if (design_method == "CRD") {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").show();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").show();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").show();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#trial_multi-design_more_info").show();
            $("#FieldMap").show();
            $("#prephelp").hide();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
            $("#rep_count_section").show();
            $("#block_number_section").hide();
            $("#block_size_section").hide();
            $("#max_block_section").hide();
            $("#row_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#col_number_per_block_section").hide();
            $("#col_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#other_parameter_section").hide();
            $("#design_info").show();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        } else if (design_method == "RCBD") {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").show();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").show();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").show();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#trial_multi-design_more_info").show();
            $("#FieldMap").show();
            $("#prephelp").hide();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
            $("#rep_count_section").hide();
            $("#block_number_section").show();
            $("#block_size_section").hide();
            $("#max_block_size_section").hide();
            $("#row_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#col_number_per_block_section").hide();
            $("#col_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#other_parameter_section").hide();
            $("#design_info").show();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        } else if (design_method == "RRC") {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").show();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").show();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").show();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#trial_multi-design_more_info").show();
            $("#FieldMap").show();
            $("#prephelp").hide();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
            $("#rep_count_section").hide();
            $("#block_number_section").show();
            $("#block_size_section").hide();
            $("#max_block_size_section").hide();
            $("#row_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#col_number_per_block_section").hide();
            $("#col_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#other_parameter_section").hide();
            $("#design_info").show();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        } else if (design_method == "DRRC") {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").show();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").show();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").show();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#field_map_row_aug").hide();
            $("#trial_multi-design_more_info").show();
            $("#FieldMap").show();
            $("#prephelp").hide();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
            $("#rep_count_section").show();
            $("#block_number_section").hide();
            $("#block_size_section").hide();
            $("#max_block_size_section").hide();
            $("#row_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#col_number_per_block_section").hide();
            $("#col_number_section").show();
            $("#row_number_per_block_section").hide();
            $("#other_parameter_section").hide();
            $("#design_info").show();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        } else if (design_method == "URDD") {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").show();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").show();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").show();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#field_map_row_aug").hide();
            $("#trial_multi-design_more_info").show();
            $("#FieldMap").show();
            $("#prephelp").hide();
            $("#show_no_of_row_in_design").show();
            $("#show_no_of_col_in_design").show();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
            $("#rep_count_section").hide();
            $("#block_number_section").show();
            $("#block_size_section").hide();
            $("#max_block_size_section").hide();
            $("#row_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#col_number_per_block_section").hide();
            $("#col_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#other_parameter_section").hide();
            $("#design_info").show();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        } else if (design_method == "Alpha") {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").show();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").show();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").show();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#FieldMap").hide();
            $("#prephelp").hide();
            $("#trial_multi-design_more_info").show();
            $("#show_no_of_row_in_design").show();
            $("#show_no_of_col_in_design").show();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").show();
            $("#show_no_of_sub_block_sequence").hide();
            $("#rep_count_section").show();
            $("#block_number_section").hide();
            $("#block_size_section").show();
            $("#max_block_size_section").hide();
            $("#row_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#col_number_per_block_section").hide();
            $("#col_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#other_parameter_section").hide();
            $("#design_info").show();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        } else if (design_method == "Lattice") {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").show();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").show();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").show();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#FieldMap").show();
            $("#prephelp").hide();
            $("#trial_multi-design_more_info").show();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
            $("#rep_count_section").show();
            $("#block_number_section").hide();
            $("#block_size_section").hide();
            $("#max_block_size_section").hide();
            $("#row_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#col_number_per_block_section").hide();
            $("#col_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#other_parameter_section").hide();
            $("#design_info").show();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        } else if (design_method == "Augmented") {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").show();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").show();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").show();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#field_map_row_aug").hide();
            $("#FieldMap").show();
            $("#prephelp").hide();
            $("#trial_multi-design_more_info").show();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
            $("#rep_count_section").hide();
            $("#block_number_section").hide();
            $("#block_size_section").hide();
            $("#max_block_size_section").show();
            $("#row_number_section").hide();
            $("#row_number_per_block_section").show();
            $("#col_number_per_block_section").hide();
            $("#col_number_section").hide();
            $("#other_parameter_section").hide();
            $("#design_info").show();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        } else if (design_method == "") {
            $("#FieldMap").hide();
            $("#prephelp").hide();
            $("#show_list_of_checks_section").hide();
            $("#crbd_show_list_of_checks_section").hide();
            $("#show_list_of_accession_section").hide();
            $("#show_list_of_unrep_accession").hide();
            $("#show_list_of_rep_accession").hide();
            $("#show_list_of_cross_checks_section").hide();
            $("#crbd_show_list_of_cross_checks_section").hide();
            $("#show_list_of_cross_section").hide();
            $("#show_list_of_unrep_cross").hide();
            $("#show_list_of_rep_cross").hide();
            $("#show_list_of_family_name_checks_section").hide();
            $("#crbd_show_list_of_family_name_checks_section").hide();
            $("#show_list_of_family_name_section").hide();
            $("#show_list_of_unrep_family_name").hide();
            $("#show_list_of_rep_family_name").hide();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
            $("#trial_multi-design_more_info").hide();
            $("#rep_count_section").hide();
            $("#block_number_section").hide();
            $("#block_size_section").hide();
            $("#max_block_size_section").hide();
            $("#row_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#col_number_per_block_section").hide();
            $("#col_number_section").hide();
            $("#row_number_per_block_section").show();
            $("#other_parameter_section").hide();
            $("#design_info").show();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        }
        else if (design_method == "MAD") {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").show();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").show();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").show();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#FieldMap").hide();
            $("#prephelp").hide();
            $("#trial_multi-design_more_info").show();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
            $("#rep_count_section").hide();
            $("#row_number_section").show();
            $("#block_number_section").hide();
            $("#block_size_section").hide();
            $("#row_number_per_block_section").show();
            $("#col_number_per_block_section").show();
            $("#col_number_section").show();
            $("#max_block_size_section").hide();
            $("#row_number_per_block_section").show();
            $("#other_parameter_section").show();
            $("#design_info").show();

            $("#show_other_parameter_options").click(function () {
                if ($('#show_other_parameter_options').is(':checked')) {
                    $("#other_parameter_options").show();
                }
                else {
                    $("#other_parameter_options").hide();
                }
            });
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        }
        else if (design_method == 'greenhouse') {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#FieldMap").hide();
            $("#prephelp").hide();
            $("#trial_multi-design_more_info").show();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
            $("#rep_count_section").hide();
            $("#block_number_section").hide();
            $("#block_size_section").hide();
            $("#max_block_section").hide();
            $("#row_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#col_number_per_block_section").hide();
            $("#col_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#other_parameter_section").hide();
            $("#design_info").hide();
            $('#greenhouse_default_num_plants_per_accession').show();
            $("#greenhouse_num_plants_per_accession_section").show();
            $('#greenhouse_default_num_plants_per_accession').show();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        }
        else if (design_method == 'splitplot') {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#FieldMap").show();
            $("#prephelp").hide();
            $("#trial_multi-design_more_info").show();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
            $("#rep_count_section").hide();
            $("#block_number_section").show();
            $("#block_size_section").hide();
            $("#max_block_section").hide();
            $("#row_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#col_number_per_block_section").hide();
            $("#col_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#other_parameter_section").hide();
            $("#design_info").show();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").show();
            $("#num_plants_per_plot_section").show();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        }
        else if (design_method == 'p-rep') {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").show();
                $("#show_list_of_rep_accession").show();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").show();
                $("#show_list_of_rep_cross").show();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").show();
                $("#show_list_of_rep_family_name").show();
            }
            $("#FieldMap").hide();
            $("#trial_multi-design_more_info").show();
            $("#prephelp").show();
            $("#show_no_of_row_in_design").show();
            $("#show_no_of_col_in_design").show();
            $("#show_no_of_rep_times").show();
            $("#show_no_of_block_sequence").show();
            $("#show_no_of_sub_block_sequence").show();
            $("#rep_count_section").hide();
            $("#block_number_section").hide();
            $("#block_size_section").hide();
            $("#max_block_section").hide();
            $("#row_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#col_number_per_block_section").hide();
            $("#col_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#other_parameter_section").hide();
            $("#design_info").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        }
        else if (design_method == 'Westcott') {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#FieldMap").hide();
            $("#trial_multi-design_more_info").show();
            $("#prephelp").hide();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
            $("#rep_count_section").hide();
            $("#block_number_section").hide();
            $("#block_size_section").hide();
            $("#max_block_section").hide();
            $("#row_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#col_number_per_block_section").hide();
            $("#col_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#other_parameter_section").hide();
            $("#design_info").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").show();
            $("#westcott_num_col_between_check_section").show();
            $("#westcott_check_1_section").show();
            $("#westcott_check_2_section").show();
            $("#FieldMap_westcott").show();
            $("#field_map_options").hide();
        }

        else {
            alert("Método de delineamento não suportado");
        }
    });

    jQuery("#westcott_check_1").autocomplete({
        appendTo: "#add_project_dialog",
        source: '/ajax/stock/accession_autocomplete',
    });

    jQuery("#westcott_check_2").autocomplete({
        appendTo: "#add_project_dialog",
        source: '/ajax/stock/accession_autocomplete',
    });

    jQuery(document).on('change', '#select_list_list_select', function() {
        if (jQuery("#select_design_method").val() == 'greenhouse') {
            greenhouse_show_num_plants_section();
        }
    });

    jQuery(document).on('change', '#select_cross_list_list_select', function() {
        if (jQuery("#select_design_method").val() == 'greenhouse') {
            greenhouse_show_num_plants_section();
        }
    });

    jQuery(document).on('change', '#select_family_name_list_list_select', function() {
        if (jQuery("#select_design_method").val() == 'greenhouse') {
            greenhouse_show_num_plants_section();
        }
    });

    jQuery(document).on('keyup', '#greenhouse_default_num_plants_per_accession_val', function() {
        if (jQuery("#select_design_method").val() == 'greenhouse') {
            greenhouse_show_num_plants_section();
        }
    });

    jQuery(document).on('keyup', '#greenhouse_default_num_plants_per_accession_val', function() {
        if (jQuery("#select_design_method").val() == 'greenhouse') {
            greenhouse_show_num_plants_section();
        }
    });

    jQuery('#plot_naming_tabs a').on('shown.bs.tab', function(e) {
        if (jQuery(e.target).attr('href') === '#plot_naming_tab_template') {
            load_plot_name_templates();
        }
    });

    jQuery(document).on('click', '#trial_design_add_plot_name_template_button', function(e) {
        e.preventDefault();
        var breeding_program_id = jQuery('#select_breeding_program').val();
        if (!breeding_program_id) {
            alert("Selecione primeiro um programa de melhoramento");
            return;
        }
        jQuery('#autogenerated_name_metadata_program').val(breeding_program_id);
        jQuery('#name_type').val('plot').trigger('change');
        jQuery('#add_autogenerated_name_metadata_dialog').data('refresh_callback', load_plot_name_templates);
        jQuery('#add_autogenerated_name_metadata_dialog').modal({backdrop: false});
    });

    function load_plot_name_templates() {
        var breeding_program_id = jQuery('#select_breeding_program').val();
        if (!breeding_program_id) {
            jQuery('#plot_template_radios').html('<p><em>Selecione primeiro um programa de melhoramento.</em></p>');
            return;
        }
        jQuery('#plot_template_radios').html('<p><em>Carregando os modelos disponíveis...</em></p>');
        var templates = {};
        jQuery.ajax({
            url: '/ajax/breeders/program/' + breeding_program_id + '/autogenerated_name_metadata',
            type: 'GET',
            success: function(response) {
                var $container = jQuery('#plot_template_radios').empty();
                if (response && response.data && response.data.length > 0) {
                    var has_plot_templates = false;
                    response.data.forEach(function(template_obj) {
                        var format_name = Object.keys(template_obj)[0];
                        var tmpl = template_obj[format_name];
                        if (tmpl.name_type !== 'plot') { return; }

                        has_plot_templates = true;
                        templates[format_name] = template_obj;

                        var $radio = jQuery('<div class="radio">');
                        var $label = jQuery('<label>');
                        $label.append(jQuery('<input type="radio" name="plot_name_template_idx">').val(format_name));
                        $label.append(jQuery('<strong>').text(' ' + format_name));
                        $radio.append($label);

                        var name_attributes = tmpl.name_attributes || [];
                        if (name_attributes.length > 0) {
                            var $components = jQuery('<div style="margin-left:20px; margin-top:4px">');
                            name_attributes.forEach(function(attr, i) {
                                if (typeof attr === 'object') {
                                    $components.append(document.createTextNode(attr.text));
                                } else {
                                    $components.append(jQuery('<code>').text(attr));
                                }
                                if (i < name_attributes.length - 1) {
                                    $components.append(document.createTextNode('_'));
                                }
                            });
                            $radio.append($components);
                        }

                        $container.append($radio);
                    });
                    if (!has_plot_templates) {
                        $container.html('<p><em>Não há modelos de nomes de parcelas disponíveis para este programa de melhoramento.</em></p>');
                    }
                } else {
                    $container.html('<p><em>Não há modelos de nomes de parcelas disponíveis para este programa de melhoramento.</em></p>');
                }
                jQuery('#plot_template_radios').data('templates', templates);
            },
            error: function() {
                jQuery('#plot_template_radios').html('<p class="text-danger">Erro ao carregar os modelos.</p>');
            }
        });
    }

    $("#show_field_map_options").click(function () {
      if ($('#show_field_map_options').is(':checked')) {
        $("#field_map_options").show();
      }
      else {
        $("#field_map_options").hide();
      }
    });


    function add_plants_per_plot() {
        if (plants_per_plot && plants_per_plot != 0) {
            jQuery.ajax( {
                url: '/ajax/breeders/trial/'+trial_id+'/create_plant_entries/',
                type: 'POST',
                data: {
                  'plants_per_plot' : plants_per_plot,
                  'inherits_plot_treatments' : inherits_plot_treatments,
                  'include_plant_coordinates' : include_plant_coordinates,
                  'rows_per_plot' : num_rows,
                  'cols_per_plot' : num_cols
                },
                success: function(response) {
                    //console.log(response);
                  if (response.error) {
                    alert(response.error);
                  }
                  else {
                    jQuery('#add_plants_dialog').modal("hide");
                  }
                },
                error: function(response) {
                  alert(response);
                },
              });
        }
    }

    function save_experimental_design(design_json) {
        
        var list = new CXGN.List();
        var name = jQuery('#new_trial_name').val();
        var year = jQuery('#add_project_year').val();
        var planting_date = jQuery('#add_project_planting_date').val();
        // date formatting here from js to breedbase format
        if (planting_date) {
            planting_date = new Date(planting_date).toLocaleDateString("en-CA");
        }
        var desc = jQuery('#add_project_description').val();
        var locations = jQuery('#add_project_location').val();
        var trial_location =  JSON.stringify(locations);
        var trial_stock_type = jQuery('#select_stock_type').val();

        var block_number = jQuery('#block_number').val();
        var stock_list_id = jQuery('#select_list_list_select').val();
        var control_list_id = jQuery('#list_of_checks_section_list_select').val();
        var stock_list;
        if (stock_list_id) {
            stock_list_array = list.getList(stock_list_id);
            stock_list = JSON.stringify(list.getList(stock_list_id));
        }
        var control_list;
        if (control_list_id) {
           control_list = JSON.stringify(list.getList(control_list_id));
        }
        var design_type = jQuery('#select_design_method').val();
        if (design_type == "undefined") {
            var design_type = jQuery('#select_multi-design_method').val();
        }
        var greenhouse_num_plants = [];
        if (stock_list_id && design_type == 'greenhouse') {
            for (var i=0; i<stock_list_array.length; i++) {
                var value = jQuery("input#greenhouse_num_plants_input_" + i).val();
                if (value == '') {
                    value = 1;
                }
                greenhouse_num_plants.push(value);
            }
            //console.log(greenhouse_num_plants);
        }

        var rep_count = jQuery('#rep_count').val();
        var block_size = jQuery('#block_size').val();
        var max_block_size = jQuery('#max_block_size').val();
        var plot_prefix = jQuery('#plot_prefix').val();
        var start_number = jQuery('#start_number').val();
        var increment = jQuery('#increment').val();
        var breeding_program_name = jQuery('#select_breeding_program option:selected').text();
        var breeding_program_id = jQuery('#select_breeding_program').val();
        var fieldmap_col_number = jQuery('#fieldMap_col_number').val();
        var fieldmap_row_number = jQuery('#fieldMap_row_number').val();
        var plot_layout_format = jQuery('#plot_layout_format').val();
        var trial_type = jQuery('#add_project_type').val();
        var westcott_check_1 = $('#westcott_check_1').val();
        var westcott_check_2 = $('#westcott_check_2').val();
        var westcott_col = $('#westcott_col').val();
        var westcott_col_between_check = $('#westcott_col_between_check').val();

        var plot_width = $('#add_project_plot_width').val();
        var plot_length = $('#add_project_plot_length').val();
        var field_size = $('#new_trial_field_size').val();
        var field_trial_is_planned_to_be_genotyped = $('#add_project_trial_will_be_genotyped').val();
        var field_trial_is_planned_to_cross = $('#add_project_trial_will_be_crossed').val();
        var selectedTrials = [];
        jQuery('#add_project_trial_source_select :selected').each(function(i, selectedElement) {
            selectedTrials.push(jQuery(selectedElement).val());
        });

        var use_same_layout;
        if ($('#use_same_layout').is(':checked')) {
           use_same_layout = $('#use_same_layout').val();
        }
        else {
           use_same_layout = "";
        }

	    var plot_numbering_scheme = jQuery('input[name="plot_numbering_scheme"]:checked').val();

        var save_plot_name_template = null;
        if (jQuery('#plot_naming_tabs li.active a').attr('href') === '#plot_naming_tab_template') {
            var saved_selected = jQuery('input[name="plot_name_template_idx"]:checked');
            if (saved_selected.length > 0) {
                var saved_format_name = saved_selected.val();
                var saved_templates = jQuery('#plot_template_radios').data('templates');
                if (saved_templates && saved_templates[saved_format_name]) {
                    save_plot_name_template = JSON.stringify(saved_templates[saved_format_name]);
                }
            }
        }

        jQuery.ajax({
           type: 'POST',
           timeout: 3000000,
           url: '/ajax/trial/save_experimental_design',
           dataType: "json",
           beforeSend: function() {
               jQuery('#working_modal').modal("show");
           },
           data: {
                'project_name': name,
                'project_description': desc,
                //'trial_name': trial_name,
                'year': year,
                'planting_date' : planting_date,
                'trial_type': trial_type,
                'trial_location': trial_location,
                'trial_stock_type': trial_stock_type,
                'stock_list': stock_list,
                'control_list': control_list,
                'design_type': design_type,
                'rep_count': rep_count,
                'block_number': block_number,
                'block_size': block_size,
                'max_block_size': max_block_size,
                'plot_prefix': plot_prefix,
                'plot_numbering_scheme' : plot_numbering_scheme,
                'start_number': start_number,
                'increment': increment,
                'design_json': design_json,
                'breeding_program_name': breeding_program_name,
                'breeding_program_id' : breeding_program_id,
                'greenhouse_num_plants': JSON.stringify(greenhouse_num_plants),
                'fieldmap_col_number': fieldmap_col_number,
                'fieldmap_row_number': fieldmap_row_number,
                'plot_layout_format': plot_layout_format,
                'has_plant_entries': num_plants_per_plot,
                'has_subplot_entries': num_subplots_per_plot,
                'westcott_check_1': westcott_check_1,
                'westcott_check_2': westcott_check_2,
                'westcott_col': westcott_col,
                'westcott_col_between_check': westcott_col_between_check,
                'field_size': field_size,
                'plot_width': plot_width,
                'plot_length': plot_length,
                'field_trial_is_planned_to_be_genotyped': field_trial_is_planned_to_be_genotyped,
                'field_trial_is_planned_to_cross': field_trial_is_planned_to_cross,
                'add_project_trial_source': selectedTrials,
                'use_same_layout' : use_same_layout,
                'plot_name_template': save_plot_name_template
            },
            success: function (response) {
                trial_id = response.trial_id;
                jQuery('#working_modal').modal("hide");
                if (response.error) {
                    alert(response.error);
                } else {
                    refreshTrailJsTree(0);
                    Workflow.complete('#new_trial_confirm_submit');
                    Workflow.focus("#trial_design_workflow", -1); //Go to success page
                    Workflow.check_complete("#trial_design_workflow");
                    if (design_type != "greenhouse" && design_type != "splitplot") {
                        add_plants_per_plot();
                    }
                }
            },
            error: function () {
                jQuery('#working_modal').modal("hide");
                alert('Ocorreu um erro ao salvar o ensaio.');
            }
        });
    }

    jQuery(document).on('click', '[name="create_trial_success_complete_button"]', function(){
        jQuery('#add_project_dialog').modal('hide');
        window.location.href = '/breeders/trials';
        return false;
    });

    jQuery('#new_trial_confirm_submit').click(function () {
        save_experimental_design(design_json);
    });

    $('#redo_trial_layout_button').click(function () {
        generate_experimental_design();
        return false;
    });

    function open_project_dialog() {
        $('#add_project_dialog').modal("show");

        //add a blank line to location select dropdown that dissappears when dropdown is opened
        $("#add_project_location").prepend("<option value=''></option>").val('');
        $("#add_project_location").one('mousedown', function () {
            $("option:first", this).remove();
        });

        //add a blank line to list select dropdown that dissappears when dropdown is opened
        $("#select_list_list_select").prepend("<option value=''></option>").val('');
        $("#select_list_list_select").one('mousedown', function () {
            $("option:first", this).remove();
        });

        $("#select_cross_list_list_select").prepend("<option value=''></option>").val('');
        $("#select_cross_list_list_select").one('mousedown', function () {
            $("option:first", this).remove();
        });

        $("#select_family_name_list_list_select").prepend("<option value=''></option>").val('');
        $("#select_family_name_list_list_select").one('mousedown', function () {
            $("option:first", this).remove();
        });

        //add a blank line to list select dropdown that dissappears when dropdown is opened
        $("#select_seedlot_list_list_select").prepend("<option value=''></option>").val('');
        $("#select_seedlot_list_list_select").one('mousedown', function () {
            $("option:first", this).remove();
        });


        //add a blank line to list of checks select dropdown that dissappears when dropdown is opened
        $("#list_of_checks_section_list_select").prepend("<option value=''></option>").val('');
        $("#list_of_checks_section_list_select").one('mousedown', function () {
            $("option:first", this).remove();
        });

        $("#crbd_list_of_checks_section_list_select").prepend("<option value=''></option>").val('');
        $("#crbd_list_of_checks_section_list_select").one('mousedown', function () {
            $("option:first", this).remove();
        });

        $("#list_of_cross_checks_section_list_select").prepend("<option value=''></option>").val('');
        $("#list_of_cross_checks_section_list_select").one('mousedown', function () {
            $("option:first", this).remove();
        });

        $("#crbd_list_of_cross_checks_section_list_select").prepend("<option value=''></option>").val('');
        $("#crbd_list_of_cross_checks_section_list_select").one('mousedown', function () {
            $("option:first", this).remove();
        });

        $("#list_of_family_name_checks_section_list_select").prepend("<option value=''></option>").val('');
        $("#list_of_family_name_checks_section_list_select").one('mousedown', function () {
            $("option:first", this).remove();
        });

        $("#crbd_list_of_family_name_checks_section_list_select").prepend("<option value=''></option>").val('');
        $("#crbd_list_of_family_name_checks_section_list_select").one('mousedown', function () {
            $("option:first", this).remove();
        });

        //add a blank line to design method select dropdown that dissappears when dropdown is opened
        $("#select_design_method").prepend("<option value=''></option>").val('');
        $("#select_design_method").one('mousedown', function () {
            $("option:first", this).remove();
            //trigger design method change events in case the first one is selected after removal of the first blank select item
            $("#select_design_method").change();
        });

        //reset previous selections
        $("#select_design_method").change();
    }

    $('#add_project_link').click(function () {
        get_select_box('years', 'add_project_year', {'auto_generate': 1 });
        get_select_box('trial_types', 'add_project_type', {'empty':1} );
        populate_trial_linkage_selects();

        // preselect user's program and filter locations

        open_project_dialog();
    });

    jQuery('#select_breeding_program').change(function(){
        populate_trial_linkage_selects();
        if (jQuery('#plot_naming_tabs li.active a').attr('href') === '#plot_naming_tab_template') {
            load_plot_name_templates();
        }
    });

    function populate_trial_linkage_selects(){
        get_select_box('trials', 'add_project_trial_source', {'id':'add_project_trial_source_select', 'name':'add_project_trial_source_select', 'breeding_program_id':jQuery('#select_breeding_program').val(), 'multiple':1, 'empty':1} );
    }

    jQuery('button[name="new_trial_add_treatments"]').click(function(){
        jQuery('#trial_design_add_treatments').modal('show');
    });

    jQuery('#new_trial_add_treatments_continue').click(function(){
        var treatment_name = jQuery('#new_treatment_name').val();
        var html = "";
        var design_array = JSON.parse(design_json);
        for (var i=0; i<design_array.length; i++){
            html += "<table class='table table-hover'><thead><tr><th>Nome da parcela</th><th>Acesso</th><th>Número da parcela</th><th>Número do bloco</th><th>Número da repetição</th><th>É testemunha</th><th>Número da linha</th><th>Número da coluna</th><th class='table-success'>"+treatment_name+" [Selecionar todas <input type='checkbox' name='add_trial_treatment_select_all' />]</th></tr></thead><tbody>";
            var design_hash = JSON.parse(design_array[i]);
            //console.log(design_hash);
            var keys = Object.keys(design_hash);
            keys.sort();
            keys.forEach(function(key){
                if (key != 'treatments'){
                    var plot_obj = design_hash[key];
                    //console.log(plot_obj);
                    html += "<tr><td>"+plot_obj.plot_name+"</td><td>"+plot_obj.stock_name+"</td><td>"+plot_obj.plot_number+"</td><td>"+plot_obj.block_number+"</td><td>"+plot_obj.rep_number+"</td><td>"+plot_obj.is_a_control+"</td><td>"+plot_obj.row_number+"</td><td>"+plot_obj.col_number+"</td><td><input data-plot_name='"+plot_obj.plot_name+"' data-trial_index='"+i+"' data-trial_treatment='"+treatment_name+"'  data-plant_names='"+JSON.stringify(plot_obj.plant_names)+"' data-subplot_names='"+JSON.stringify(plot_obj.subplots_names)+"' type='checkbox' name='add_trial_treatment_input'/></td></tr>";
                }
            });
            html += "</tbody></table>";
        }
        html += "<br/><br/>";
        jQuery('#trial_design_add_treatment_select_html').html(html);
        jQuery('#trial_design_add_treatment_select').modal('show');
    });

    jQuery(document).on('change', 'input[name="add_trial_treatment_select_all"]', function(){
        if(jQuery(this).is(":checked")){
            jQuery('input[name="add_trial_treatment_input"]').each(function(){
                jQuery(this).prop("checked", true);
            });
        } else {
            jQuery('input[name="add_trial_treatment_input"]').each(function(){
                jQuery(this).prop("checked", false);
            });
        }
    });

    jQuery('#new_trial_add_treatments_submit').click(function(){
        var new_treatment_year = jQuery('#new_treatment_year').val();
        var new_treament_planting_date = jQuery('#new_treatment_planting_date').val();
        var new_treatment_description = jQuery('#new_treatment_description').val();
        var new_treatment_date = jQuery('#new_treatment_date').val();
        var new_treatment_type = jQuery('#new_treatment_type').val();
        new_treatment_date = moment(new_treatment_date).format('YYYY/MM/DD HH:mm:ss')

        var trial_treatments = [];
        jQuery('input[name="add_trial_treatment_input"]').each(function() {
            if (this.checked){
                var plot_name = jQuery(this).data('plot_name');
                var plant_names = jQuery(this).data('plant_names');
                var subplot_names = jQuery(this).data('subplot_names');
                var trial_index = jQuery(this).data('trial_index');
                var trial_treatment = jQuery(this).data('trial_treatment');
                if (trial_index in trial_treatments){
                    var trial = trial_treatments[trial_index];
                    if (trial_treatment in trial){
                        trial[trial_treatment]['new_treatment_stocks'].push(plot_name);
                    } else {
                        trial[trial_treatment]['new_treatment_stocks'] = [plot_name];
                    }
                    if (plant_names != 'undefined'){
                        for(var i=0; i<plant_names.length; i++){
                            trial[trial_treatment]['new_treatment_stocks'].push(plant_names[i]);
                        }
                    }
                    if (subplot_names != 'undefined'){
                        for(var i=0; i<subplot_names.length; i++){
                            trial[trial_treatment]['new_treatment_stocks'].push(subplot_names[i]);
                        }
                    }
                    trial[trial_treatment]["new_treatment_type"] = new_treatment_type;
                    trial[trial_treatment]["new_treatment_date"] = new_treatment_date;
                    trial[trial_treatment]["new_treatment_year"] = new_treatment_year;
                    trial[trial_treatment]["new_treatment_planting_date"] = new_treatment_planting_date;
                    trial[trial_treatment]["new_treatment_description"] = new_treatment_description;

                    trial_treatments[trial_index] = trial;
                } else {
                    obj = {};
                    obj[trial_treatment] = {};
                    obj[trial_treatment]['new_treatment_stocks'] = [plot_name];
                    if (plant_names != 'undefined'){
                        for(var i=0; i<plant_names.length; i++){
                            obj[trial_treatment]['new_treatment_stocks'].push(plant_names[i]);
                        }
                    }
                    if (subplot_names != 'undefined'){
                        for(var i=0; i<subplot_names.length; i++){
                            obj[trial_treatment]['new_treatment_stocks'].push(subplot_names[i]);
                        }
                    }
                    trial_treatments[trial_index] = obj;
                }
            }
        });

        var new_design_array = [];
        var design_array = JSON.parse(design_json);
        for (var i=0; i<design_array.length; i++){
            var design_hash = JSON.parse(design_array[i]);
            if ('treatments' in design_hash){
                treatment_obj = design_hash['treatments'];
                new_treatments = trial_treatments[i];
                for (var key in new_treatments){
                    treatment_obj[key] = new_treatments[key];
                }
                design_hash['treatments'] = treatment_obj;
            } else {
                design_hash['treatments'] = trial_treatments[i];
            }
            new_design_array[i] = JSON.stringify(design_hash);
        }
        design_json = JSON.stringify(new_design_array);

        var html = '';
        for (var i=0; i<new_design_array.length; i++){
            var design_hash = JSON.parse(new_design_array[i]);
            var treatments = design_hash['treatments'];
            //html += "Trial "+i+"<br/>";
            for (var key in treatments){
                html += "Tratamento: <b>"+key+"</b> Parcelas: ";
                var plot_array = treatments[key]['new_treatment_stocks'];
                html += plot_array.join(', ') + "<br/>";
            }
        }
        jQuery('#trial_design_confirm_treatments').html(html);
        jQuery('#trial_design_add_treatment_select').modal('hide');
        jQuery('#trial_design_add_treatments').modal('hide');
    });

});

function greenhouse_show_num_plants_section(){
    var list = new CXGN.List();

    var accession_list_id = jQuery('#select_list_list_select').val();
    var cross_list_id = jQuery('#select_cross_list_list_select').val();
    var family_name_list_id = jQuery('#select_family_name_list_list_select').val();

    var default_num = jQuery('#greenhouse_default_num_plants_per_accession_val').val();
        if (accession_list_id) {
        var accession_list = list.getList(accession_list_id);
        var html = '<form class="form-horizontal">';
        for (var i=0; i<accession_list.length; i++){
            html = html + '<div class="form-group"><label class="col-sm-9 control-label">' + accession_list[i] + ': </label><div class="col-sm-3"><input class="form-control" id="greenhouse_num_plants_input_' + i + '" type="text" placeholder="'+default_num+'" value="'+default_num+'" /></div></div>';
        }
        html = html + '</form>';
        jQuery("#greenhouse_num_plants_per_accession").empty().html(html);
    } else if (cross_list_id) {
        var cross_list = list.getList(cross_list_id);
        var html = '<form class="form-horizontal">';
        for (var i=0; i<cross_list.length; i++){
            html = html + '<div class="form-group"><label class="col-sm-9 control-label">' + cross_list[i] + ': </label><div class="col-sm-3"><input class="form-control" id="greenhouse_num_plants_input_' + i + '" type="text" placeholder="'+default_num+'" value="'+default_num+'" /></div></div>';
        }
        html = html + '</form>';
        jQuery("#greenhouse_num_plants_per_accession").empty().html(html);
    } else if (family_name_list_id) {
        var family_name_list = list.getList(family_name_list_id);
        var html = '<form class="form-horizontal">';
        for (var i=0; i<family_name_list.length; i++){
            html = html + '<div class="form-group"><label class="col-sm-9 control-label">' + family_name_list[i] + ': </label><div class="col-sm-3"><input class="form-control" id="greenhouse_num_plants_input_' + i + '" type="text" placeholder="'+default_num+'" value="'+default_num+'" /></div></div>';
        }
        html = html + '</form>';
        jQuery("#greenhouse_num_plants_per_accession").empty().html(html);
    }
}

function extend_obj(obj, src) {
    for (var key in src) {
        if (src.hasOwnProperty(key)) obj[key] = src[key];
    }
    return obj;
}

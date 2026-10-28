function deleteTransformationID(transformation_stock_id){

    const confirmation = confirm("Tem certeza de que deseja excluir este ID de transformação? A exclusão não pode ser desfeita.");

    if (confirmation) {
        jQuery.ajax({
            url: '/ajax/transformation/delete',
            data: {'transformation_stock_id' : transformation_stock_id},
            method: 'POST',
            destroy: true,
            beforeSend: function(response) {
                jQuery('#working_modal').modal('show');
            },
            success: function(response) {
                jQuery('#working_modal').modal('hide');
                if (response.success == 1) {
                    alert("Exclusão concluída com sucesso");
                    location.reload();
                }
                if (response.error) {
                    alert(response.error);
                }
            },
            error: function(response) {
                jQuery('#working_modal').modal('hide');
                alert("Ocorreu um erro durante a exclusão");
            }
        });
    }
}

function setTransformationControl(transformation_id, control_stock_id, program_name){

    jQuery.ajax({
        url : '/ajax/transformation/set_transformation_control',
        dataType: "json",
        type: 'POST',
        data : {
            'transformation_stock_id': transformation_id,
            'control_stock_id': control_stock_id,
            'program_name': program_name,
        },
        beforeSend: function(response){
            jQuery('#working_modal').modal('show');
        },
        success: function(response) {
            jQuery('#working_modal').modal('hide');
            if (response.success == 1) {
                jQuery('#set_transformation_control_dialog').modal('hide');
                jQuery("#set_transformation_control_saved_dialog_message tbody").html('');
                jQuery("#set_transformation_control_saved_dialog_message tbody").append("A testemunha de transformação foi armazenada com sucesso.");
                jQuery('#set_transformation_control_saved_dialog_message').modal("show");
                return;
            }
            if (response.error) {
                alert(response.error);
            }
        },
        error: function(response){
            jQuery('#working_modal').modal('hide');
            alert("Ocorreu um erro ao definir a testemunha de transformação");
        }
    });

}

function setAsAControl(transformation_id, program_name){
    jQuery.ajax({
        url : '/ajax/transformation/set_as_control',
        dataType: "json",
        type: 'POST',
        data : {
            'transformation_id': transformation_id,
            'is_a_control': 1,
            'program_name': program_name
        },
        beforeSend: function(response){
            jQuery('#working_modal').modal('show');
        },
        success: function(response) {
            jQuery('#working_modal').modal('hide');
            if (response.success == 1) {
                jQuery('#set_as_a_control_dialog').modal('hide');
                jQuery("#set_transformation_control_saved_dialog_message tbody").html('');
                jQuery("#set_transformation_control_saved_dialog_message tbody").append("Este ID de transformação foi definido como testemunha com sucesso.");
                jQuery('#set_transformation_control_saved_dialog_message').modal("show");
                return;
            }
            if (response.error) {
                alert(response.error);
            }
        },
        error: function(response){
            jQuery('#working_modal').modal('hide');
            alert("Ocorreu um erro ao definir a testemunha de transformação");
        }
    });

}

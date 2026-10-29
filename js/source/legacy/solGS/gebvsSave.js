jQuery(document).ready(function () {
  var analysisArgs = solGS.analysisSave.saveGebvsArgs();
  jQuery('#analysis_result_save_type').val('gebvs');
  analysisArgs['analysis_result_save_type'] = 'gebvs';
  solGS.analysisSave.checkStoredAnalysis(analysisArgs).done(function (res) {
    if (res.analysis_id) {
      jQuery("#save_gebvs").hide();
      var link = ' | <a href="/analyses/' + res.analysis_id + "\">Visualizar GEBVs armazenados</a> |";
      jQuery("#gebvs_output").append(link);
    }
  });
  
  jQuery("#save_gebvs").click(function () {
      
    console.log(`analysisArgs: ${JSON.stringify(analysisArgs)}`)
    jQuery("#gebvs_output .multi-spinner-container").show();
    jQuery("#gebvs_save_message")
      .html("Aguarde... Salvar os GEBVs pode levar alguns minutos.")
      .show();
    jQuery("#save_gebvs").hide();

    solGS.analysisSave.checkUserStatus().done(function (res) {
      if (!res.loggedin) {
        solGS.submitJob.loginAlert();
      } else {
      }
    });
  
    solGS.analysisSave.checkUserStatus().fail(function () {
      solGS.alertMessage("Ocorreu um erro ao verificar o status do usuário");
    });
  
      solGS.analysisSave.getGebvsResultDetails(analysisArgs).done(function (res) {
  
        if (res.error) {
          jQuery("#gebvs_output .multi-spinner-container").hide();
          jQuery("#gebvs_save_message")
            .html(res.error + ". As informações registradas podem não existir para este resultado.")
            .show()
            .fadeOut(50000);
  
          jQuery("#save_gebvs").show();
        } else {
          var save = solGS.analysisSave.storeAnalysisResults(res.analysis_details);
  
          save.done(function (res) {
            jQuery("#gebvs_output .multi-spinner-container").hide();
            if (res.error) {
              jQuery("#gebvs_save_message").html(res.error).show().fadeOut(50000);
  
              jQuery("#save_gebvs").show();
            } else {
              jQuery("#gebvs_save_message").hide();
  
              var link = ' | <a href="/analyses/' + res.analysis_id + "\">Visualizar GEBVs armazenados</a> |";
              jQuery("#gebvs_output").append(link);
            }
          });
  
          save.fail(function (res) {
            jQuery("#gebvs_output .multi-spinner-container").hide();
            jQuery("#save_gebvs").show();
            jQuery("#gebvs_save_message").html(res.error).show().fadeOut(50000);
          });
        }
      });
    });
  });


  jQuery(document).ready(function () {
    var analysisArgs = solGS.analysisSave.saveGebvsArgs();
    analysisArgs['analysis_result_save_type'] = 'genetic_values';
    jQuery('#analysis_result_save_type').val('genetic_values');
      solGS.analysisSave.checkStoredAnalysis(analysisArgs).done(function (res) {
      if (res.analysis_id) {
        jQuery("#save_genetic_values").hide();
        var link = ' | <a href="/analyses/' + res.analysis_id + "\">Visualizar valores genéticos armazenados</a> |";
        jQuery("#gebvs_output").append(link);
        }
    });
  
    jQuery("#save_genetic_values").click(function () {
      

      jQuery("#gebvs_output .multi-spinner-container").show();
      jQuery("#gebvs_save_message")
        .html("Aguarde... Salvar os valores genéticos (médias ajustadas) pode levar alguns minutos.")
        .show();
      jQuery("#save_genetic_values").hide();
  
      solGS.analysisSave.checkUserStatus().done(function (res) {
        if (!res.loggedin) {
          solGS.submitJob.loginAlert();
        } else {
        }
      });
  
      solGS.analysisSave.checkUserStatus().fail(function () {
        solGS.alertMessage("Ocorreu um erro ao verificar o status do usuário");
      });
  
      solGS.analysisSave.getGebvsResultDetails(analysisArgs).done(function (res) {
  
        if (res.error) {
          jQuery("#gebvs_output .multi-spinner-container").hide();
          jQuery("#gebvs_save_message")
            .html(res.error + ". As informações registradas podem não existir para este resultado.")
            .show()
            .fadeOut(50000);
  
          jQuery("#save_genetic_values").show();
        } else {
          var save = solGS.analysisSave.storeAnalysisResults(res.analysis_details);
  
          save.done(function (res) {
            jQuery("#gebvs_output .multi-spinner-container").hide();
            if (res.error) {
              jQuery("#gebvs_save_message").html(res.error).show().fadeOut(50000);
  
              jQuery("#save_genetic_values").show();
            } else {
              jQuery("#gebvs_save_message").hide();
  
              var link = '| <a href="/analyses/' + res.analysis_id + "\">Visualizar valores genéticos armazenados</a> |";
              jQuery("#gebvs_output").append(link);
            }
          });
  
          save.fail(function (res) {
            jQuery("#gebvs_output .multi-spinner-container").hide();
            jQuery("#save_genetic_values").show();
            jQuery("#gebvs_save_message").html(res.error).show().fadeOut(50000);
          });
        }
      });
    });
  });
  
  
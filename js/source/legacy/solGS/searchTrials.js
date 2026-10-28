/**
 * search trials
 *
 * @author Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.searchTrials = {
  msgDiv: "#trial_search_progress_message",
  searchResultMsg: "#trial_search_result_message",
  searchResultDiv: "#trial_search_result",



  searchAllTrials: function (url, result) {
    jQuery(this.searchResultMsg)
      .html("Buscando ensaios de seleção genômica...")
      .show();

    var traitTrials = jQuery.ajax({
      type: "POST",
      dataType: "json",
      url: url,
      data: { show_result: result },
      cache: true,
    });

    return traitTrials;

  },

  listAllTrials: function (trials) {
    if (trials) {
      var tableId = "#all_trials_table";
      //var allTrialsDivId = this.searchResultDiv; //"#trial_search_result";

      var tableDetails = {
        divId: this.searchResultDiv,
        tableId: tableId,
        data: trials,
      };

      jQuery(this.searchResultDiv).empty();
      // jQuery(this.searchResultDiv).empty();

      this.displayTrainingPopulations(tableDetails);
    } else {
      jQuery(this.searchResultMsg).html("Nenhum ensaio encontrado.").show();
    }
  },

  checkTrainingPopulation: function (trialId) {
    var protocolId = jQuery("#genotyping_protocol_id").val();

    console.log(`checkTrainingPopulation protocolId: ${protocolId}`);
    var args = { trial_id: trialId, genotyping_protocol_id: protocolId };
    args = JSON.stringify(args);

    var checkTrainingPop = jQuery.ajax({
      type: "POST",
      dataType: "json",
      url: "/solgs/check/training/population",
      data: { arguments: args },
    });

    return checkTrainingPop;
  },

  checkPopulationExists: function (name) {
    var msgDiv = this.msgDiv; // "#trial_search_progress_message";
    var msg =
      "Verificando se o ensaio ou a população de treinamento " +
      name +
      " existe... Aguarde...";
    solGS.showMessage(msgDiv, msg);

    jQuery(this.searchResultMsg).empty();

    var checkPopExists = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { name: name },
      url: "/solgs/check/population/exists/",
    });

    return checkPopExists;
  },

  createTrialsTable: function (tableId) {
    tableId = tableId.replace("#", "");
    var table =
      '<table id="' +
      tableId +
      '" class="table" style="width:100%;text-align:left">';
    table += "<thead><tr>";
    table +=
      "<th></th><th>Ensaio</th><th>Descrição</th><th>Local</th><th>Ano</th><th>Mais detalhes</th>";
    // table    += '<th id="color_tip" title="You can combine Trials with matching color."><span class="glyphicon glyphicon-question-sign"></span></th>';
    table += "</tr></thead>";
    table += "</table>";

    return table;
  },

  displayTrainingPopulations: function (tableDetails) {
    var divId = tableDetails.divId;
    var tableId = tableDetails.tableId;
    var data = tableDetails.data;

    if (data) {
      var tableRows = jQuery(tableId + " tr").length;

      if (tableRows > 1) {
        jQuery(tableId).dataTable().fnAddData(data);
      } else {
        var table = this.createTrialsTable(tableId);
        jQuery(divId).html(table).show();

        jQuery(tableId).dataTable({
          order: [
            [0, "desc"],
            [2, "desc"],
            [3, "desc"],
          ],
          searching: true,
          ordering: true,
          processing: true,
          lengthChange: false,
          bInfo: false,
          paging: false,
          oLanguage: {
            sSearch: "Filtrar resultados por: ",
          },
          data: data,
        });
      }
    }
  },
};

// jQuery(document).ready( function () {

//     jQuery('#search_all_training_pops').on('click', function () {

// 	jQuery("#trial_search_result").empty();
// 	jQuery(searchResultMsg).empty();
// 	var url = '/solgs/search/trials';
//         var result = 'all';
// 	solGS.searchTrials.searchAllTrials(url, result);
//     });

// });

jQuery(document).ready(function () {
  jQuery("#color_tip").tooltip();
});

jQuery(document).ready(function () {
  var searchResultMsg = solGS.searchTrials.searchResultMsg;
  var searchResultDiv = solGS.searchTrials.searchResultDiv;
  jQuery(searchResultDiv).on("click", "div.paginate_nav a", function (e) {
    jQuery(searchResultDiv).empty();
    jQuery(searchResultMsg)
      .html("Buscando mais ensaios de seleção genômica...")
      .show();

    var page = jQuery(this).attr("href");
    if (page) {
      jQuery.ajax({
        type: "POST",
        dataType: "json",
        url: page,
        success: function (res) {
          solGS.searchTrials.listAllTrials(res.trials);
          var pagination = res.pagination;
          jQuery(searchResultMsg).hide();
          jQuery(searchResultDiv).append(pagination);
        },
        error: function () {
          jQuery(searchResultMsg)
            .html("Ocorreu um erro ao recuperar o próximo grupo de ensaios de seleção genômica.")
            .show();
        },
      });
    }
    return false;
  });
});

jQuery(document).ready(function () {
  var url = window.location.pathname;
  var searchResultMsg = solGS.searchTrials.searchResultMsg;
  var searchResultDiv = solGS.searchTrials.searchResultDiv;

  if (url.match(/solgs\/search\/trials\/trait\//) != null) {
    var traitId = jQuery("input[name='trait_id']").val();

    var urlStr = url.split(/\/+/);
    var protocolId = urlStr[7];
    jQuery("#genotyping_protocol_id").val(protocolId);

    url = "/solgs/search/result/populations/" + traitId + "/gp/" + protocolId;
    solGS.searchTrials
      .searchAllTrials(url)
      .done(function (res) {
        if (res) {
          jQuery(searchResultMsg).hide();
          solGS.searchTrials.listAllTrials(res.trials);
          var pagination = res.pagination;

          jQuery(searchResultMsg).hide();
          jQuery(searchResultDiv).append(pagination);
        } else {
          jQuery(searchResultMsg)
            .html("Nenhum ensaio fenotipado para esta característica foi encontrado.")
            .show();
        }
      })
      .fail(function () {
        jQuery(searchResultMsg)
          .html("Ocorreu um erro ao recuperar o primeiro grupo de ensaios de seleção genômica.")
          .show();
      });
  }

  // else {
  // 	url = '/solgs/search/trials/';
  // }
  // 	searchAllTrials(url);
});

jQuery(document).ready(function () {
  var protocolId = solGS.genotypingProtocol.getGenotypingProtocolId();
  console.log(`SearchTrials protocolId: ${protocolId}`);

  jQuery("#trial_search_box").keyup(function (e) {
    jQuery("#trial_search_box").css("border", "solid #96d3ec");
    jQuery("#form-feedback-search-trials").empty();

    if (e.keycode == 13) {
      jQuery("#search_trial").click();
    }
  });

  jQuery("#search_trial").on("click", function () {
    var entry = jQuery("#trial_search_box").val();
    jQuery("#trial_search_progress_message").hide();

    var msgDiv = solGS.searchTrials.msgDiv;
    if (entry) {
        var protocolId = jQuery("#genotyping_protocol_id").val()

        if (!protocolId) {
        var msg =
          "Nenhum protocolo de genotipagem encontrado. Não há um protocolo padrão de genotipagem " +
          "protocolo. Se houver um protocolo de genotipagem no banco de dados, " +
          "selecione um para buscar ensaios que possam ser usados como" +
          "população de treinamento.";

        solGS.showMessage(msgDiv, msg);    
        return;
    }

      solGS.searchTrials
        .checkPopulationExists(entry)
        .done(function (res) {
          if (res.trial_id) {
            msg =
              "<p>Verificando se o ensaio ou a população pode ser usado <br />" +
              "como população de treinamento... Aguarde...</p>";
            solGS.showMessage(msgDiv, msg);

            solGS.searchTrials
              .checkTrainingPopulation(res.trial_id)
              .done(function (res) {
                if (res.is_training_population) {
                  var resultDivId = "#trial_search_result";
                  var tableId = "#searched_trials_table";
        
                  jQuery(msgDiv).hide();
                  jQuery(resultDivId).show();

                  var data = res.training_pop_data;
                  var tableDetails = {
                    divId: resultDivId,
                    tableId: tableId,
                    data: data,
                  };

                  var table = document.querySelector(tableId);
                  if (table) {
                    var rowsCount = table.rows.length;
                    if (rowsCount > 1) {
                      jQuery("#trial_search_result_select").show();
                    }
                  }

                  solGS.searchTrials.displayTrainingPopulations(tableDetails);
                } else {
                  var msg =
                    "<p> População " +
                    popIds +
                    " não pode ser usado como população de treinamento. Não possui dados fenotípicos e/ou genotípicos.";
                  solGS.showMessage(msgDiv, msg);
                  jQuery("#search_all_training_pops").show();
                }
              })
              .fail(function () {
                var msg =
                  "Ocorreu um erro ao verificar se o ensaio pode ser usado como população de treinamento.";
                solGS.showMessage(msgDiv, msg);
              });
          } else {
            msg = "<p>" + entry + " não está no banco de dados.</p>";
            solGS.showMessage(msgDiv, msg);
          }
        })
        .fail(function (res) {
          msg = "Ocorreu um erro ao verificar se a população de treinamento existe.";
          solGS.showMessage(msgDiv, msg);
        });
    } else {
      jQuery("#trial_search_box").css("border", "solid #FF0000");

      jQuery("#form-feedback-search-trials").text("Informe o nome de um ensaio.");
    }
  });
});

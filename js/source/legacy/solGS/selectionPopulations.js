/**
 * search and display selection populations
 * relevant to a training population.
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.selectionPopulation = {
  msgDiv: "#selection_pops_message",
  resultSelDiv: "#selection_pops_result",
  selPopsDiv: "#selection_pops_div",
  searchBtn: "#search_selection_pop",
  searchBox: "#trial_search_box",
  selPopsTable: "#selection_pops_table",
  searchAllSelPops: "#search_all_selection_pops",
  searchFormFeedBack: "#form-feedback-search-trials",

  checkSelectionPopulations: function () {
    var args = solGS.getModelArgs();
    args = JSON.stringify(args);

    var checkPop = jQuery.ajax({
      type: "POST",
      data: { arguments: args },
      dataType: "json",
      url: "/solgs/check/selection/populations/",
    });

    return checkPop;
  },

  checkSelectionPopulationRelevance: function (popName) {
    var modelVars = solGS.getModelArgs();
    modelVars["selection_pop_name"] = popName;

    var popData = JSON.stringify(modelVars);
    var checkRelevance = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: popData },
      url: "/solgs/check/selection/population/relevance/",
    });

    return checkRelevance;
  },

  searchSelectionPopulations: function () {
    var args = solGS.getModelArgs();
    var popId = args.training_pop_id;

    args = JSON.stringify(args);
    var searchPops = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: args },
      url: "/solgs/search/selection/populations/" + popId,
    });

    return searchPops;
  },

  getPredictedTrialTypeSelectionPops: function () {
    var selPopsTable = jQuery(this.selPopsTable).html();
    var selPopsRows;
    if (selPopsTable !== null) {
      selPopsRows = jQuery(this.selPopsTable).find("tbody > tr");

    }

    var popsList = [];

    for (var i = 0; i < selPopsRows.length; i++) {
      var row = selPopsRows[i];
      var popRow = row.innerHTML;
      var predict = popRow.match(/predict/gi);
      if (!predict) {
        var selPopsInput = row.getElementsByTagName("input")[0];
        var selPopData = selPopsInput.value;

        popsList.push(JSON.parse(selPopData));
      }
    }

    return popsList;
  },

  feedbackOnFail: function (msg) {
    jQuery(this.msgDiv).html(msg).show().fadeOut(8000);
  },

  displaySelectionPopulations: function (data) {
    var tableRow = jQuery(`${this.selPopsTable} tr`).length;

    if (tableRow === 1) {
      jQuery(this.selPopsTable).dataTable({
        searching: false,
        ordering: false,
        processing: true,
        paging: false,
        info: false,
        data: data,
      });
    } else {
      jQuery(this.selPopsTable).dataTable().fnAddData(data);
    }
  },
};

jQuery(document).ready(function () {
  var resultSelDiv = solGS.selectionPopulation.resultSelDiv;
  var msgDiv = solGS.selectionPopulation.msgDiv;
  var searchAllSelPops = solGS.selectionPopulation.searchAllSelPops;
  var searchBox = solGS.selectionPopulation.searchBox;
  var selPopsTable = solGS.selectionPopulation.selPopsTable;
  var selPopsDiv = solGS.selectionPopulation.selPopsDiv;
  var searchBtn = solGS.selectionPopulation.searchBtn;
  var searchFormFeedBack = solGS.selectionPopulation.searchFormFeedBack;

  // jQuery(searchBtn).hide();

  solGS.selectionPopulation
    .checkSelectionPopulations()
    .done(function (res) {
      if (res.data) {
        jQuery(resultSelDiv).show();

        solGS.selectionPopulation.displaySelectionPopulations(res.data);
      } else {
        var msg = "Nenhum ensaio em cache encontrado para predição de seleção.";
        solGS.selectionPopulation.feedbackOnFail(msg);
      }

      // jQuery(searchBtn).show();
    })
    .fail(function () {
      var msg = "Ocorreu um erro ao consultar as populações de seleção";
      solGS.selectionPopulation.feedbackOnFail(msg);
      // jQuery(searchBtn).show();
    });

  jQuery(searchAllSelPops).click(function () {
    var msg =
      "<br/><br/>Buscando todas as populações de seleção relevantes para este modelo... Aguarde...";
    jQuery(msgDiv).html(msg).show();

    solGS.selectionPopulation
      .searchSelectionPopulations()
      .done(function (res) {
        if (res.data) {
          jQuery(resultSelDiv).show();
          solGS.selectionPopulation.displaySelectionPopulations(res.data);
          jQuery(searchAllSelPops).hide();
          jQuery(this.msgDiv).hide();
        } else {
          var msg =
            "<p>Não há populações de seleção relevantes no banco de dados." +
            "Se você possui ou deseja criar seu próprio conjunto de candidatos à seleção," +
            "use o formulário abaixo.</p>";

          jQuery(this.msgDiv).html(msg).show().fadeOut(8000);
        }
      })
      .fail(function () {
        var msg = "Ocorreu um erro ao buscar as populações de seleção.";
        jQuery(this.msgDiv).html(msg).show().fadeOut(8000);
      });
  });

  jQuery(searchBox).keyup(function (e) {
    jQuery(searchBox).css("border", "solid #96d3ec");

    jQuery(searchFormFeedBack).empty();

    if (e.keycode == 13) {
      jQuery(searchBtn).click();
    }
  });

  jQuery(searchBtn).on("click", function () {
    jQuery(searchBtn).hide();

    var popName = jQuery(searchBox).val();
    if (popName) {
      var selPopExists = jQuery(`${selPopsTable}:contains(${popName})`).length;

      if (selPopExists) {
        jQuery(searchBtn).show();
        var msg = `${popName} já está na tabela de resultados da busca`;
        solGS.selectionPopulation.feedbackOnFail(msg);
      } else {
        jQuery(msgDiv)
          .html(`Verificando se o modelo pode ser usado em ${popName} ... Aguarde...`)
          .show();
        jQuery(`${selPopsDiv} .multi-spinner-container`).show();

        solGS.selectionPopulation
          .checkSelectionPopulationRelevance(popName)
          .done(function (res) {
            if (res.selection_pop_id) {
              if (res.selection_pop_id != res.training_pop_id) {
                if (res.similarity >= 0.5) {
                  jQuery(msgDiv).hide();
                  jQuery(resultSelDiv).show();

                  var selPopExists = jQuery(`${selPopsTable}:contains(${popName})`).length;
                  if (!selPopExists) {
                    solGS.selectionPopulation.displaySelectionPopulations(res.selection_pop_data);
                  }
                } else {
                  var msg = `${popName} foi genotipada com um conjunto de marcadores diferente do usado na população de treinamento. Portanto, não é possível predizer seus GEBVs com este modelo.`;

                  solGS.selectionPopulation.feedbackOnFail(msg);
                }
              } else {
                var msg = `${popName} é a mesma população usada no treinamento. Selecione outra população de seleção.`;

                solGS.selectionPopulation.feedbackOnFail(msg);
              }
            } else {
              var msg = `${popName} não existe no banco de dados.`;
              solGS.selectionPopulation.feedbackOnFail(msg);
            }

            jQuery(searchBtn).show();
            jQuery(`${selPopsDiv} .multi-spinner-container`).hide();
          })
          .fail(function () {
            var msg = "Ocorreu um erro ao processar a consulta.";
            solGS.selectionPopulation.feedbackOnFail(msg);
            jQuery(searchBtn).show();
            jQuery(`${selPopsDiv} .multi-spinner-container`).hide();
          });
      }
    } else {
      jQuery(searchBox).css("border", "solid #FF0000");

      jQuery(searchFormFeedBack).text("Informe o nome do ensaio.");
      jQuery(searchBtn).show();
    }
  });
});

/**
 * @class solgs
 * general solGS app wide and misc functions
 * @author Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

JSAN.use("jquery.blockUI");
JSAN.use("jquery.form");

var solGS = solGS || function solGS() {};

solGS.submitJob = {
  waitPage: function (page, args) {
    var host = window.location.protocol + "//" + window.location.host;
    page = page.replace(host, "");

    var matchItems =
      "solgs/population/" +
      "|solgs/populations/combined/" +
      "|solgs/trait/" +
      "|solgs/model/combined/trials/" +
      "|solgs/search/trials/trait//" +
      "|solgs/selection/\\d+|\\w+_\\d+/model/" +
      "|solgs/combined/model/\\d+|\\w+_\\d+/selection/" +
      "|solgs/models/combined/trials/" +
      "|solgs/traits/all/population/" +
      "|pca/analysis/" +
      "|kinship/analysis/" +
      "|cluster/analysis/";

    if (page.match(matchItems)) {
      var multiTraitsUrls = "solgs/traits/all/population/" + "|solgs/models/combined/trials/";

      if (page.match(multiTraitsUrls)) {
        this.getTraitsSelectionId(page, args);
      } else {
        //if (page.match(/list_/)) {
        //	askUser(page, args)
        // } else {
        this.checkCachedResult(page, args);
        // }
      }
    } else {
      this.goToPage(page, args);
    }
  },

  checkCachedResult: function (page, args) {
    var trainingTraitsIds = solGS.getTrainingTraitsIds();

    if (trainingTraitsIds) {
      if (!args) {
        args = { training_traits_ids: trainingTraitsIds };
      } else {
        args["training_traits_ids"] = trainingTraitsIds;
      }
    }

    args = this.getArgsFromUrl(page, args);
    args = JSON.stringify(args);

    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { page: page, arguments: args },
      url: "/solgs/check/cached/result/",
      success: function (response) {
        if (response.cached) {
          args = JSON.parse(args);
          solGS.submitJob.goToPage(page, args);
        } else {
          if (document.URL.match(/solgs\/population\/|solgs\/populations\/combined\//)) {
            solGS.submitJob.checkTrainingPopRequirement(page, args);
          } else {
            args = JSON.parse(args);
            solGS.submitJob.askUser(page, args);
          }
        }
      },
      error: function () {
        alert("Ocorreu um erro ao verificar os resultados em cache.");
      },
    });
  },

  checkTrainingPopRequirement: function (page, args) {
    jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: { args: args },
      url: "/solgs/check/training/pop/size/",
      success: function (res) {
        var trainingPopSize = res.member_count;
        if (trainingPopSize >= 20) {
          args = JSON.parse(args);
          solGS.submitJob.askUser(page, args);
        } else {
          var msg =
            "O tamanho da população de treinamento (" +
            trainingPopSize +
            ") é muito pequeno. O mínimo necessário é 20.";

          solGS.alertMessage(msg);
        }
      },
    });
  },

  askUser: function (page, args) {
    var title =
      "<p>Como a tarefa demora, você deve enviá-la e aguardar um e-mail com o link dos resultados. " +
      "Deseja enviar a tarefa e receber um e-mail quando ela for concluída?</p>";

    var jobSubmit = '<div id= "job_submission">' + title + "</div>";

    jQuery(jobSubmit).appendTo("body");

    jQuery("#job_submission").dialog({
      height: 200,
      width: 600,
      modal: true,
      title: "Envio da tarefa",
      buttons: {
        OK: {
          text: "Sim",
          class: "btn btn-success",
          id: "queue_job",
          click: function () {
            jQuery(this).dialog("close");

            solGS.submitJob.checkUserLogin(page, args);
          },
        },
        // No: {
        //     text: 'No, I will wait...',
        //     class: 'btn btn-primary',
        //     id   : 'no_queue',
        //     click: function() {
        // 	jQuery(this).dialog("close");

        // 	analyzeNow(page, args);
        //     },
        // },
        Cancel: {
          text: "Não",
          class: "btn btn-info",
          id: "cancel_queue_info",
          click: function () {
            jQuery(this).dialog("close");
          },
        },
      },
    });
  },

  checkUserLogin: function (page, args) {
    if (args === undefined) {
      args = {};
    }

    jQuery.ajax({
      type: "POST",
      dataType: "json",
      url: "/solgs/check/user/login/",
      success: function (res) {
        if (res.loggedin) {
          var contact = res.contact;

          args["first_name"] = contact.first_name;
          args["user_email"] = contact.email;
          args["user_name"] = contact.user_name;
          solGS.submitJob.getProfileDialog(page, args);
        } else {
          solGS.submitJob.loginAlert();
        }
      },
    });
  },

  loginAlert: function () {
    jQuery("<div />")
      .html("Para usar este recurso, entre na sua conta e reinicie o processo.")
      .dialog({
        height: 200,
        width: 250,
        modal: true,
        title: "Entrar",
        buttons: {
          OK: {
            click: function () {
              jQuery(this).dialog("close");
              solGS.submitJob.loginUser();
            },
            class: "btn btn-success",
            text: "OK",
          },

          Cancel: {
            click: function () {
              jQuery(this).dialog("close");
            },
            class: "btn btn-primary",
            text: "Cancelar",
          },
        },
      });
  },

  loginUser: function () {
    window.location = "/user/login?goto_url=" + window.location.pathname;
  },

  getTraitsSelectionId: function (page, args) {
    var traitIds = args.training_traits_ids;
    var trainingPopId = args.training_pop_id;
    var protocolId = solGS.genotypingProtocol.getGenotypingProtocolId();

    jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: { trait_ids: traitIds, training_pop_id: trainingPopId},
      url: "/solgs/get/traits/selection/id",
      success: function (res) {
        var traitsSelectionId = res.traits_selection_id;
        page = page + "/traits/" + traitsSelectionId + "/gp/" + protocolId;

        //if (page.match(/list_/)) {
        //    askUser(page, args)
        //} else {
        solGS.submitJob.checkCachedResult(page, args);
        //}
      },
      error: function (res, st, error) {
        alert("erro: " + error);
      },
    });
  },

  goToPage: function (page, args) {
    jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
    jQuery.blockUI({ message: "Aguarde..." });

    var matchItems =
      "solgs/submission/feedback" +
      "|solgs/trait/" +
      "|solgs/traits/all/population/" +
      "|solgs/models/combined/trials/" +
      "|solgs/model/combined/trials/" +
      "|pca/analysis" +
      "|kinship/analysis/" +
      "|cluster/analysis/";

    if (page.match(matchItems)) {
      window.location = page;
    } else if (page.match(/solgs\/populations\/combined\//)) {
      solGS.combinedTrials.displayCombinedTrialsTrainingPopPage(args);
    } else if (page.match(/solgs\/population\//)) {
      // if (page.match(/solgs\/population\/list_/)) {
      // 	var listId = args.list_id;
      // 	loadPlotListTypeTrainingPop(listId);
      // } else {
      window.location = page;
      // }
    } else if (page.match(/solgs\/selection\//)) {
      var listTypePages =
        "solgs/selection/\\w+_\\d+/model/\\w+_\\d+/" + "|solgs/selection/\\d+/model/\\w+_\\d+/";

      if (page.match(/listTypePages/)) {
        loadGenotypesListTypeSelectionPop(args);
      } else {
        window.location = page;
      }
    } else {
      window.location = window.location.href;
    }
  },

  submitTraitSelections: function (page, args) {
    wrapTraitsForm();

    if (args == "undefined") {
      document.getElementById("traits_selection_form").submit();
      document.getElementById("traits_selection_form").reset();
    } else {
      jQuery("#traits_selection_form").ajaxSubmit();
      jQuery("#traits_selection_form").resetForm();
    }
  },

  wrapTraitsForm: function () {
    var popId = jQuery("#population_id").val();
    var protocolId = solGS.genotypingProtocol.getGenotypingProtocolId();

    var formId = ' id="traits_selection_form"';

    var action;
    var referer = window.location.href;

    if (referer.match(/solgs\/populations\/combined\//)) {
      action = ' action="/solgs/models/combined/trials/' + popId + "/gp/" + protocolId + '"';
    }

    if (referer.match(/solgs\/population\//)) {
      action = ' action="/solgs/traits/all/population/' + popId + "/gp/" + protocolId + '"';
    }

    var method = ' method="POST"';

    var traitsForm = "<form" + formId + action + method + ">" + "</form>";

    jQuery("#population_traits_list").wrap(traitsForm);
  },

  getProfileDialog: function (page, args) {
    var matchItems =
      "/solgs/population/" +
      "|solgs/trait/" +
      "|solgs/model/combined/trials/" +
      "|solgs/combined/model/\\d+|\\w+_\\d+/selection/" +
      "|solgs/selection/\\d+|\\w+_\\d+/model/";

    if (page.match(matchItems)) {
      args = this.getArgsFromUrl(page, args);
    }

    var form = this.getProfileForm(args);
    jQuery("<div />", { id: "email-form" })
      .html(form)
      .dialog({
        height: 400,
        width: 400,
        modal: true,
        title: "Informações sobre a análise",
        buttons: {
          Submit: {
            click: function (e) {
              var analysisProfile = solGS.submitJob.structureAnalysisProfile(page, args);
              solGS.submitJob.validateAnalysisInput(analysisProfile);
            },
            id: "submit_job",
            class: "btn btn-success",
            text: "Enviar",
          },

          Cancel: {
            click: function () {
              jQuery(this).dialog("close");
            },
            class: "btn btn-primary",
            text: "Cancelar",
          },
        },
      });
  },

  structureAnalysisProfile: function (page, args) {
    var userEmail = jQuery("#user_email").val();
    var analysisName = jQuery("#analysis_name").val();
    var analysisType = args.analysis_type;
    var userName = args.user_name;
    var dataSetType = args.data_set_type;

    args["user_email"] = userEmail;
    args["analysis_name"] = analysisName;
    args["analysis_page"] = page;

    var hostname = `${location.protocol}//${location.hostname}`;
    args['hostname'] = hostname;

    args = JSON.stringify(args);

    var analysisProfile = {
      user_name: userName,
      analysis_name: analysisName,
      analysis_page: page,
      analysis_type: analysisType,
      data_set_type: dataSetType,
      arguments: args,
    };

    return analysisProfile;
  },

  validateAnalysisInput: function (analysisProfile) {
    var analysisName = jQuery("#analysis_name").val();

    if (!analysisName) {
      jQuery("#form-feedback-analysis-name").text("O nome da análise está vazio. Informe um nome.");
    } else {
      var checkName = solGS.submitJob.checkAnalysisName(analysisName);

      checkName.done(function (res) {
        if (res.analysis_exists) {
          jQuery("#analysis_name").css("border", "solid #FF0000");

          jQuery("#form-feedback-analysis-name").text(
            "Já existe outra análise com esse nome. Informe um novo nome."
          );
        } else {
          var email = jQuery("#user_email").val();
          var emailPass = solGS.submitJob.checkEmail(email);

          if (emailPass) {
            jQuery("#email-form").dialog("close");
            solGS.submitJob.saveAnalysisProfile(analysisProfile);
          }
        }
      });
    }

    checkName.fail(function (res) {
      var message =
        "Ocorreu um erro ao enviar a tarefa. Entre em contato com os desenvolvedores." +
        "\n\nDica: " +
        response.result;
      solGS.alertMessage(message);
    });
  },

  checkEmail: function (email) {
    var emailPass;
    var emailRegex = /^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/i;
    if (!email.match(emailRegex)) {
      jQuery("#user_email").css("border", "solid #FF0000");

      jQuery("#form-feedback-user-email").text("Informe um endereço de e-mail válido.");

      emailPass = 0;
    } else {
      emailPass = 1;
    }

    return emailPass;
  },

  checkAnalysisName: function (name) {
    var analysisName = jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: { name: name },
      url: "/solgs/check/analysis/name",
    });

    return analysisName;
  },

  getArgsFromUrl: function (url, args) {
    var referer = document.URL;
    var host = window.location.protocol + "//" + window.location.host;
    referer = referer.replace(host, "");

    if (args === undefined) {
      args = {};
    }

    if (window.Prototype) {
      delete Array.prototype.toJSON;
    }

    if (url.match(/solgs\/trait\//)) {
      var urlStr = url.split(/\/+/);

      args["trait_id"] = [urlStr[3]];
      args["training_pop_id"] = [urlStr[5]];
      args["analysis_type"] = "training_model";
      args["data_set_type"] = "single_population";
    } else if (url.match(/solgs\/model\/combined\/trials\//)) {
      var urlStr = url.split(/\/+/);

      var traitId = [];
      var populationId = [];
      var comboPopsId = [];
      var protocolId;

      if (referer.match(/solgs\/search\/trials\/trait\//)) {
        populationId.push(urlStr[5]);
        comboPopsId.push(urlStr[5]);
        traitId.push(urlStr[7]);
        protocolId = urlStr[9];
      } else if (referer.match(/solgs\/populations\/combined\//)) {
        populationId.push(urlStr[5]);
        comboPopsId.push(urlStr[5]);
        traitId.push(urlStr[7]);
        protocolId = urlStr[9];
      }

      args["trait_id"] = traitId;
      args["training_pop_id"] = populationId;
      args["combo_pops_id"] = comboPopsId;
      args["analysis_type"] = "training_model";
      args["data_set_type"] = "combined_populations";
      args["genotyping_protocol_id"] = protocolId;
    } else if (url.match(/solgs\/population\//)) {
      var urlStr = url.split(/\/+/);

      args["training_pop_id"] = [urlStr[3]];
      args["analysis_type"] = "training_dataset";
      args["data_set_type"] = "single_population";
      args["genotyping_protocol_id"] = urlStr[5];
    } else if (url.match(/solgs\/selection\//)) {
      var traitId = jQuery("#trait_id").val();
      var modelId = jQuery("#model_id").val();
      var urlStr = url.split(/\/+/);

      var dataSetType;

      if (referer.match(/solgs\/model\/combined\/trials\/|solgs\/models\/combined\//)) {
        dataSetType = "combined_populations";
      } else if (referer.match(/solgs\/trait\/|solgs\/traits\/all\/population\//)) {
        dataSetType = "single_population";
      }

      args["trait_id"] = [traitId];
      args["training_pop_id"] = [urlStr[5]];
      args["selection_pop_id"] = [urlStr[3]];
      args["analysis_type"] = "selection_prediction";
      args["data_set_type"] = dataSetType;
    } else if (url.match(/solgs\/combined\/model\//)) {
      var urlStr = url.split(/\/+/);
      //var protocolId = urlStr[10];
      var dataSetType = "combined_populations";

      args["training_pop_id"] = [urlStr[4]];
      args["selection_pop_id"] = [urlStr[6]];
      args["trait_id"] = [urlStr[8]];
      args["analysis_type"] = "selection_prediction";
      args["data_set_type"] = dataSetType;
    }

    var trainingTraitsIds = jQuery("#training_traits_ids").val();

    if (trainingTraitsIds) {
      trainingTraitsIds = trainingTraitsIds.split(",");
      args["training_traits_ids"] = trainingTraitsIds;
      args["trait_id"] = trainingTraitsIds;
    }

    var protocolId = args.genotyping_protocol_id;
    if (!protocolId) {
      protocolId = solGS.genotypingProtocol.getGenotypingProtocolId();
    }

    var popDesc = jQuery("#training_pop_desc").val();

    args["training_pop_desc"] = jQuery("#training_pop_desc").val();
    args["selection_pop_desc"] = jQuery("#selection_pop_desc").val();
    args["genotyping_protocol_id"] = protocolId;
    args["referer"] = referer;

    return args;
  },

  getProfileForm: function (args) {
    var email = "";
    if (args.user_email) {
      email = args.user_email;
    }

    var firstName = "";
    if (args.first_name) {
      firstName = args.first_name;
    }

    var emailForm =
      '<form><div class="form-group">' +
      "<label for=\"first_name\">Nome:</label>" +
      '<input type="text" class="form-control" id="first_name"  value="' +
      firstName +
      '"/>' +
      "</div>" +
      '<div class="form-group">' +
      "<label for=\"analysis_name\">Nome da análise:</label>" +
      '<input type="text" class="form-control" id="analysis_name">' +
      '<div style="color:red" id="form-feedback-analysis-name"> </div>' +
      "</div>" +
      '<div class="form-group">' +
      "<label for=\"user_email\">E-mail:</label>" +
      '<input type="email" class="form-control" id="user_email" value="' +
      email +
      '"/>' +
      '<div style="color:red" id="form-feedback-user-email"> </div>' +
      "</div>" +
      "</form>";

    return emailForm;
  },

  saveAnalysisProfile: function (profile) {
    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: profile,
      url: "/solgs/save/analysis/profile/",
      success: function (response) {
        if (response.result) {
          solGS.submitJob.runAnalysis(profile);
        } else {
          var message = "Falha ao salvar o perfil da análise.";
          solGS.alertMessage(message);
        }
      },
      error: function () {
        var message = "Ocorreu um erro ao chamar a função para salvar o perfil da análise.";
        solGS.alertMessage(message);
      },
    });
  },

  runAnalysis: function (profile) {
    jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: profile,
      url: "/solgs/run/saved/analysis/",
      success: function (res) {
        if (res.result.match(/Submitted/)) {
          solGS.submitJob.submissionFeedback(res.arguments);
        } else {
          var message =
            "Ocorreu um erro ao enviar a tarefa. Entre em contato com os desenvolvedores." +
            "\n\nDica: " +
            res.result;
          solGS.alertMessage(message);
        }
      },
      error: function (response) {
        var message =
          "Ocorreu um erro ao enviar a tarefa. Entre em contato com os desenvolvedores." +
          "\n\nDica: " +
          res.result;
        solGS.alertMessage(message);
      },
    });
  },

  submissionFeedback: function (args) {
    args = JSON.parse(args);
    var analysisType = args.analysis_type;
    analysisType = analysisType.replace(/\s+|-/g, "_");

    solGS.submitJob.goToPage("/solgs/submission/feedback/?job=" + analysisType);
  },

  selectTraitMessage: function () {
    var message =
      '<p style="text-align:justify;">' +
      "Selecione uma ou mais características para construir modelos de predição.</p>";

    jQuery("<div />")
      .html(message)
      .dialog({
        height: 200,
        width: 400,
        modal: true,
        title: "Mensagem da modelagem de predição",
        buttons: {
          Yes: {
            text: "OK",
            class: "btn btn-success",
            id: "select_trait_message",
            click: function () {
              jQuery(this).dialog("close");
            },
          },
        },
      });
  },
};

solGS.waitPage = function (page, args) {
  solGS.submitJob.waitPage(page, args);
};

jQuery(document).ready(function () {
  jQuery("#runGS").on("click", function () {
    if (window.Prototype) {
      delete Array.prototype.toJSON;
    }

    var traitIds = jQuery("#traits_selection_div :checkbox").fieldValue();
    var popId = jQuery("#training_pop_id").val();
    var protocolId = solGS.genotypingProtocol.getGenotypingProtocolId();

    if (traitIds.length) {
      var page;
      var analysisType;
      var dataSetType;

      var referer = window.location.href;

      if (referer.match(/solgs\/populations\/combined\//)) {
        dataSetType = "combined_populations";
      }

      if (referer.match(/solgs\/population\//)) {
        dataSetType = "single_population";
      }

      if (traitIds.length == 1) {
        analysisType = "training_model";

        if (referer.match(/solgs\/populations\/combined\//)) {
          page =
            "/solgs/model/combined/trials/" + popId + "/trait/" + traitIds[0] + "/gp/" + protocolId;
        } else if (referer.match(/solgs\/population\//)) {
          page = "/solgs/trait/" + traitIds[0] + "/population/" + popId + "/gp/" + protocolId;
        }
      } else {
        analysisType = "multiple_models";

        if (referer.match(/solgs\/populations\/combined\//)) {
          page = "/solgs/models/combined/trials/" + popId;
        } else {
          page = "/solgs/traits/all/population/" + popId;
        }
      }

      var args = {
        trait_id: traitIds,
        training_traits_ids: traitIds,
        training_pop_id: [popId],
        analysis_type: analysisType,
        data_set_type: dataSetType,
      };

      solGS.submitJob.waitPage(page, args);
    } else {
      solGS.submitJob.selectTraitMessage();
    }
  });
});

solGS.alertMessage = function (msg, msgTitle, divId) {
  if (!msgTitle) {
    msgTitle = "Mensagem";
  }

  if (!divId) {
    divId = "error_message";
  }

  jQuery("<div />", { id: divId })
    .html(msg)
    .dialog({
      height: "auto",
      width: "auto",
      modal: true,
      title: msgTitle,
      buttons: {
        OK: {
          click: function () {
            jQuery(this).dialog("close");
            //window.location = window.location.href;
          },
          class: "btn btn-success",
          text: "OK",
        },
      },
    });
};

solGS.getTraitDetails = function (traitId) {
  if (!traitId) {
    traitId = jQuery("#trait_id").val();
  }

  if (traitId) {
    jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: { trait_id: traitId },
      url: "/solgs/details/trait/" + traitId,
      success: function (trait) {
        jQuery(document.body).append(
          '<input type="hidden" id="trait_name" value="' + trait.name + '"></input>'
        );
        jQuery(document.body).append(
          '<input type="hidden" id="trait_abbr" value="' + trait.abbr + '"></input>'
        );
      },
    });
  }
};

solGS.getTrainingTraitsIds = function () {
  var trainingTraitsIds = jQuery("#training_traits_ids").val();
  var trainingTraitsCode = jQuery("#training_traits_code").val();
  var traitId = jQuery("#trait_id").val();

  if (trainingTraitsIds) {
    trainingTraitsIds = trainingTraitsIds.split(",");

  } else if (traitId) {
    trainingTraitsIds = [traitId];
  }

  return trainingTraitsIds;
};

solGS.getModelArgs = function () {
  var args = this.getTrainingPopArgs();
  var trainingTraitsIds = this.getTrainingTraitsIds();

  if (trainingTraitsIds) {
    args["training_traits_code"] = jQuery("#training_traits_code").val();
    args["training_traits_ids"] = trainingTraitsIds;
  }

  if (trainingTraitsIds.length == 1) {
    args["trait_id"] = trainingTraitsIds[0];
  }

  return args;
};

solGS.selectMenuModelArgs = function() {
    var modelArgs = this.getModelArgs();

    return {
      id: modelArgs.training_pop_id,
      name: modelArgs.training_pop_name,
      pop_type: "training",
    };
};

solGS.getSelectionPopArgs = function () {
  var args = this.getModelArgs();
  var selPopGenoProtocolId = jQuery("#selection_pop_genotyping_protocol_id").val();
  var selPopId = jQuery("#selection_pop_id").val();

  if (!selPopGenoProtocolId) {
    selPopGenoProtocolId = jQuery("#genotyping_protocol_id").val();
  }
  if (selPopGenoProtocolId) {
    args["selection_pop_genotyping_protocol_id"] = selPopGenoProtocolId;
    args["selection_pop_id"] = selPopId;
  }

  return args;
};

solGS.getTrainingPopArgs = function () {
  var args = {
    training_pop_id: jQuery("#training_pop_id").val(),
    training_pop_name: jQuery("#training_pop_name").val(),
    genotyping_protocol_id: jQuery("#genotyping_protocol_id").val(),
    data_set_type: jQuery("#data_set_type").val(),
    analysis_type: jQuery("#analysis_type").val(),
  };

  return args;
};

solGS.getPopulationDetails = function () {
  var trainingPopId = jQuery("#population_id").val();
  var trainingPopName = jQuery("#population_name").val();

  if (!trainingPopId) {
    trainingPopId = jQuery("#training_pop_id").val();
    trainingPopName = jQuery("#training_pop_name").val();
  }

  var selectionPopId = jQuery("#selection_pop_id").val();
  var selectionPopName = jQuery("#selection_pop_name").val();

  if (!trainingPopId) {
    trainingPopId = jQuery("#model_id").val();
    traininPopName = jQuery("#model_name").val();
  }

  var comboPopsId = jQuery("#combo_pops_id").val();

  var dataSetType;

  if (comboPopsId) {
    dataSetType = "combined_populations";
    trainingPopId = comboPopsId;
  } else {
    dataSetType = "single_population";
  }

  var protocolId = jQuery("#genotyping_protocol_id").val();
  return {
    training_pop_id: trainingPopId,
    population_name: trainingPopName,
    training_pop_name: trainingPopName,
    selection_pop_id: selectionPopId,
    selection_pop_name: selectionPopName,
    combo_pops_id: comboPopsId,
    data_set_type: dataSetType,
    genotyping_protocol_id: protocolId,
  };
};

solGS.showMessage = function (divId, msg) {
  divId = divId.match(/#/) ? divId : "#" + divId;

  jQuery(divId).html(msg).show().delay(4000).fadeOut("slow");
};

solGS.checkPageType = function () {
  var pageType = jQuery.ajax({
    dataType: "json",
    type: "POST",
    data: { page: document.URL },
    url: "/solgs/check/page/type",
  });

  return pageType;
};


solGS.blockSolgsSearchInterface = function () {

	jQuery("#solgs_search_interfaces").hide();

};


//executes two functions alternately
jQuery.fn.alternateFunctions = function (a, b) {
  return this.each(function () {
    var clicked = false;
    jQuery(this).bind("click", function () {
      if (clicked) {
        clicked = false;
        return b.apply(this, arguments);
      }
      clicked = true;
      return a.apply(this, arguments);
    });
  });
};

jQuery.fn.doesExist = function () {
  return jQuery(this).length > 0;
};

jQuery(document).on("keyup", "#user_email", function (e) {
  jQuery("#user_email").css("border", "solid #96d3ec");

  jQuery("#form-feedback-user-email").empty();
});

jQuery(document).on("keyup", "#analysis_name", function (e) {
  jQuery("#analysis_name").css("border", "solid #96d3ec");

  jQuery("#form-feedback-analysis-name").empty();
});

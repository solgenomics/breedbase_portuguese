/**
 * solGS prediction raw, model input downloads
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.download = {
    getTrainingPopRawDataFiles: function () {
        var args = solGS.getTrainingPopArgs();
        args = JSON.stringify(args);

        var popDataReq = jQuery.ajax({
            type: "POST",
            dataType: "json",
            data: {
                arguments: args,
            },
            url: "/solgs/download/training/pop/data",
        });

        return popDataReq;
    },

    getSelectionPopRawDataFiles: function () {
        var args = solGS.getSelectionPopArgs();
        args = JSON.stringify(args);

        var popDataReq = jQuery.ajax({
            type: "POST",
            dataType: "json",
            data: {
                arguments: args,
            },
            url: "/solgs/download/selection/pop/data",
        });

        return popDataReq;
    },

    getTraitsAcronymFile: function () {
        var args = solGS.getTrainingPopArgs();
        args = JSON.stringify(args);

        var popDataReq = jQuery.ajax({
            type: "POST",
            dataType: "json",
            data: {
                arguments: args,
            },
            url: "/solgs/download/traits/acronym",
        });

        return popDataReq;
    },

    createTrainingPopDownloadLinks: function (res) {
        var genoFiles = res.training_pop_raw_geno_file;
        var phenoFiles = res.training_pop_raw_pheno_file;
        var genoFileLink = '';
        var cnt = 1;

        genoFiles.forEach(function (genoFile) {
            var genoFileName = genoFile.split("/").pop();
            var popIdMatch = genoFileName.match(/genotype_data_(\d+)-GP-1/);
            var popId = popIdMatch ? popIdMatch[1] : '';
            var genoLinkName = "Dados genotípicos";

            if (genoFiles.length > 1) { genoLinkName = genoLinkName + "-" + popId; }
            if (cnt > 1) { genoFileLink += ' | '; }

            genoFileLink +=
                '<a href="' + genoFile + '" download=' + genoFileName + '">' + genoLinkName + "</a>";

            cnt++;
        });

        var phenoFileLink = '';
        var cnt = 1;

        phenoFiles.forEach(function (phenoFile) {
            var phenoFileName = phenoFile.split("/").pop();
            var phenoLinkName = "Dados fenotípicos";
            var popIdMatch = phenoFileName.match(/phenotype_data_(\d+)/);
            var popId = popIdMatch ? popIdMatch[1] : '';
            if (phenoFiles.length > 1) { phenoLinkName = phenoLinkName + "-" + popId; }
            if (cnt > 1) { phenoFileLink += ' | '; }

            phenoFileLink +=
                '<a href="' + phenoFile + '" download=' + phenoFileName + '">' + phenoLinkName + "</a>";

            cnt++;
        });

        var traitsAcronymLink = this.createTraitsAcronymLinks(res);

        var downloadLinks =
            " <strong>Baixar população de treinamento</strong>: " +
            genoFileLink +
            " | " +
            phenoFileLink + " | " + traitsAcronymLink;

        jQuery("#training_pop_download").prepend(
            '<p style="margin-top: 20px">' + downloadLinks + "</p>"
        );
    },

    createTraitsAcronymLinks: function (res) {
        var acronymFile = res.traits_acronym_file;

        var acronymFileName = acronymFile.split("/").pop();
        var acronymFileLink =
            '<a href="' + acronymFile + '" download=' + acronymFileName + '">' + "Siglas das características" + "</a>";

        return acronymFileLink;
    },

    createSelectionPopDownloadLinks: function (res) {
        var genoFile = res.selection_pop_filtered_geno_file;
        var reportFile = res.selection_prediction_report_file;

        var genoFileName = genoFile.split("/").pop();
        var genoFileLink =
            '<a href="' + genoFile + '" download=' + genoFileName + '">' + "Dados genotípicos" + "</a>";

        var reportFileName = reportFile.split("/").pop();
        var reportFileLink =
            '<a href="' + reportFile + '" download=' + reportFileName + '">' + "Registro da análise" + "</a>";

        var downloadLinks =
            " <strong>Baixar população de seleção</strong>: " +
            genoFileLink + ' | ' + reportFileLink;

        jQuery("#selection_pop_download").prepend(
            '<p style="margin-top: 20px">' + downloadLinks + "</p>"
        );
    },

    getModelInputDataFiles: function () {
        var args = solGS.getModelArgs();
        args = JSON.stringify(args);

        var modelInputReq = jQuery.ajax({
            type: "POST",
            dataType: "json",
            data: {
                arguments: args,
            },
            url: "/solgs/download/model/input/data",
        });

        return modelInputReq;
    },

    createModelInputDownloadLinks: function (res) {
        var genoFile = res.model_geno_data_file;
        var phenoFile = res.model_pheno_data_file;
        var logFile = res.model_analysis_report_file;

        console.log("geno file: " + genoFile);
        console.log("pheno file: " + phenoFile);
        console.log("log file: " + logFile);

        var genoFileName = genoFile.split("/").pop();
        var genoFileLink =
            '<a href="' + genoFile + '" download=' + genoFileName + '">' + "Dados genotípicos" + "</a>";

        var phenoFileName = phenoFile.split("/").pop();
        var phenoFileLink =
            '<a href="' + phenoFile + '" download=' + phenoFileName + '">' + "Dados fenotípicos" + "</a>";

        var logFileName = logFile.split("/").pop();
        var logFileLink =
            '<a href="' + logFile + '" download=' + logFileName + '">' + "Registro da análise" + "</a>";

        var downloadLinks =
            " <strong>Baixar modelo</strong>: " + genoFileLink + " | " + phenoFileLink + " | " + logFileLink;

        jQuery("#model_input_data_download").prepend(
            '<p style="margin-top: 20px">' + downloadLinks + "</p>"
        );
    },

    getValidationFile: function () {
        var args = solGS.getModelArgs();
        args = JSON.stringify(args);

        var valDataReq = jQuery.ajax({
            type: "POST",
            dataType: "json",
            data: {
                arguments: args,
            },
            url: "/solgs/download/model/validation",
        });

        return valDataReq;
    },

    createValidationDownloadLink: function (res) {
        var valFileName = res.validation_file.split("/").pop();
        var valFileLink =
            '<a href="' +
            res.validation_file +
            '" download=' +
            valFileName +
            '">' +
            "Baixar acurácia do modelo" +
            "</a>";

        jQuery("#validation_download").prepend('<p style="margin-top: 20px">' + valFileLink + "</p>");
    },

    getMarkerEffectsFile: function () {
        var args = solGS.getModelArgs();
        args = JSON.stringify(args);

        var markerEffectsReq = jQuery.ajax({
            type: "POST",
            dataType: "json",
            data: {
                arguments: args,
            },
            url: "/solgs/download/model/marker/effects",
        });

        return markerEffectsReq;
    },

    createMarkerEffectsDownloadLink: function (res) {
        var effectsFileName = res.marker_effects_file.split("/").pop();
        var effectsFileLink =
            '<a href="' +
            res.marker_effects_file +
            '" download=' +
            effectsFileName +
            '">' +
            "Baixar efeitos dos marcadores" +
            "</a>";

        jQuery("#marker_effects_download").prepend(
            '<p style="margin-top: 20px">' + effectsFileLink + "</p>"
        );
    },
};

jQuery(document).ready(function () {

    var downloadMsgDiv = "#download_message";
    solGS.checkPageType().done(function (res) {
        if (res.page_type.match(/training_population/)) {
            solGS.download.getTrainingPopRawDataFiles().done(function (res) {
                solGS.download.createTrainingPopDownloadLinks(res);
            });

            solGS.download.getTrainingPopRawDataFiles().fail(function (res) {
                var errorMsg = "Ocorreu um erro ao obter os arquivos de dados brutos da população de treinamento.";
                solGS.showMessage(downloadMsgDiv, errorMsg)
            });

            solGS.download.getTrainingPopRawDataFiles().fail(function (res) {
                var errorMsg = "Ocorreu um erro ao obter os arquivos de dados brutos da população de treinamento.";
                solGS.showMessage(downloadMsgDiv, errorMsg)
            });

        } else if (res.page_type.match(/training_model/)) {
            solGS.download.getModelInputDataFiles().done(function (res) {
                solGS.download.createModelInputDownloadLinks(res);
            });

            solGS.download.getModelInputDataFiles().fail(function (res) {
                var errorMsg = "Ocorreu um erro ao obter os arquivos de entrada do modelo.";
                solGS.showMessage(downloadMsgDiv, errorMsg)
            });

            solGS.download.getValidationFile().done(function (res) {
                solGS.download.createValidationDownloadLink(res);
            });

            solGS.download.getValidationFile().fail(function (res) {
                var errorMsg = "Ocorreu um erro ao obter o arquivo de validação do modelo.";
                solGS.showMessage("#validation_download_message", errorMsg);
            });

            solGS.download.getMarkerEffectsFile().done(function (res) {
                solGS.download.createMarkerEffectsDownloadLink(res);
            });

            solGS.download.getMarkerEffectsFile().fail(function (res) {
                var errorMsg = "Ocorreu um erro ao obter o arquivo de efeitos dos marcadores.";
                solGS.showMessage("#marker_effects_download_message", errorMsg);

            });
        } else if (res.page_type.match(/selection_prediction/)) {
            solGS.download.getSelectionPopRawDataFiles().done(function (res) {
                solGS.download.createSelectionPopDownloadLinks(res);
            });

            solGS.download.getSelectionPopRawDataFiles().fail(function (res) {
                var errorMsg = "Ocorreu um erro ao obter os arquivos de dados genotípicos da população de seleção.";
                solGS.showMessage(downloadMsgDiv, errorMsg);
            });
        }
    });

    solGS.checkPageType().fail(function (res) {
        var errorMsg = "Ocorreu um erro ao verificar o tipo de página.";
        solGS.showMessage(downloadMsgDiv, errorMsg)
    });
});

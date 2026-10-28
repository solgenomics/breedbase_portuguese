


var solGS = solGS || function solGS () {};

solGS.phenoHistogram =  {

    PhenoRawHistoCanvas: '#pheno_raw_histo_canvas',
    PhenoRawHistoPlotDiv: '#pheno_raw_histo_plot',
    PhenoMeansHistoCanvas: '#pheno_means_histo_canvas',
    PhenoMeansHistoPlotDiv: '#pheno_means_histo_plot',

    getTraitPhenoMeansData: function () {

	var params = this.getHistogramParams();
    params = JSON.stringify(params);
	var histoData = jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: {'arguments': params},
            url: '/trait/pheno/means/data/',
        });

       return histoData;
    },

    getTraitPhenoRawData: function () {

	var params = this.getHistogramParams();
    params = JSON.stringify(params);
	var histoData = jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: {'arguments': params},
            url: '/trait/pheno/raw/data/',
        });

       return histoData;
    },

    getHistogramParams: function () {

	var traitId      = jQuery("#trait_id").val();
	var population   = solGS.getPopulationDetails();
	var populationId = population.training_pop_id;
	var comboPopsId  = population.combo_pops_id;
    var protocolId = jQuery("#genotyping_protocol_id").val();

	var params = {
	    'trait_id'     : traitId,
	    'training_pop_id': populationId,
	    'combo_pops_id'  : comboPopsId,
        'genotyping_protocol_id': protocolId
	};

	return params;
    },

    createHistoDownloadLinks: function (phenoTypeHistoDivId) {

        var phenoTypeHistoDivId = phenoTypeHistoDivId.replace(/#/, '');
        var histoDownloadBtn = "download_" + phenoTypeHistoDivId;
        var histoPlotLink = "<a href='#'  onclick='event.preventDefault();' id='" + histoDownloadBtn + "'> Histograma</a>";
        var downloadLinks = `Baixar:  ${histoPlotLink}`;

        return downloadLinks;
    
      },

////////
}
////////

jQuery(document).ready(function() {
    jQuery(function() {
        jQuery("#tabs_phenotype").tabs({
        event: "mouseover"
        });
    });
});


jQuery(document).ready(function () {
    var PhenoRawHistoCanvas = solGS.phenoHistogram.PhenoRawHistoCanvas;
    var PhenoRawHistoPlotDiv = solGS.phenoHistogram.PhenoRawHistoPlotDiv;
    var PhenoMeansHistoCanvas = solGS.phenoHistogram.PhenoMeansHistoCanvas;
    var PhenoMeansHistoPlotDiv = solGS.phenoHistogram.PhenoMeansHistoPlotDiv;
  
    var histMsgId = `${PhenoRawHistoCanvas} #histogram_message`;
    solGS.phenoHistogram.getTraitPhenoMeansData().done(function(res) {

        if (res.status == 'success') {
           var traitData = res.data;
           var variation = solGS.histogram.checkDataVariation(traitData);

            if (variation.uniq_count == 1) {
                var msg = "<p> Todas as observações válidas "
                                  + '('+ variation.obs_count +') ' + "deste conjunto de dados possuem "
                                  + "o valor " + variation.uniqValue
                                  + ". Sem distribuição de frequência.</p>";

                solGS.showMessage(histMsgId, msg);

            } else {
                var phenoMeansPlotLinks= solGS.phenoHistogram.createHistoDownloadLinks(PhenoMeansHistoPlotDiv);
                var args = {
                    'named_values' : traitData,
                    'canvas' : PhenoMeansHistoCanvas,
                    'plot_id': PhenoMeansHistoPlotDiv,
                    'download_links': phenoMeansPlotLinks
                };

                solGS.histogram.plotHistogram(args);
                jQuery(histMsgId).empty();

            }
       } else {
            var msg = "<p>Esta característica não possui dados fenotípicos para gerar o gráfico.</p>";
            solGS.showMessage(histMsgId, msg);
       }

    });

    solGS.phenoHistogram.getTraitPhenoMeansData().fail(function(res) {
        var msg = "<p>Ocorreu um erro ao gerar o histograma deste conjunto de dados da característica.</p>";
        solGS.showMessage(histMsgId, msg);
    });



    var histMsgIdRaw = "#pheno_raw_histogram_canvas #histogram_message";
    solGS.phenoHistogram.getTraitPhenoRawData().done(function(res) {

         if (res.status == 'success') {
            var traitRawData = res.data;
            var variationRaw = solGS.histogram.checkDataVariation(traitRawData);

             if (variationRaw.uniq_count == 1) {
                 var msg = "<p> Todas as observações válidas "
                                   + '('+ variationRaw.obs_count +') ' + "deste conjunto de dados possuem "
                                   + "o valor " + variationRaw.uniqValue
                                   + ". Sem distribuição de frequência.</p>";

                 solGS.showMessage(histMsgIdRaw, msg);

             } else {
                var phenoRawPlotLinks= solGS.phenoHistogram.createHistoDownloadLinks(PhenoRawHistoPlotDiv);
                 var args = {
                     'named_values' : traitRawData,
                     'canvas' : PhenoRawHistoCanvas,
                     'plot_id': PhenoRawHistoPlotDiv,
                     'download_links': phenoRawPlotLinks
                 };

                 solGS.histogram.plotHistogram(args);
                 jQuery(histMsgIdRaw).empty();

             }
        } else {
             var msg = "<p>Esta característica não possui dados fenotípicos para gerar o gráfico.</p>";
             solGS.showMessage(histMsgIdRaw, msg);
        }

     });

     solGS.phenoHistogram.getTraitPhenoRawData().fail(function(res) {
         var msg = "<p>Ocorreu um erro ao gerar o histograma deste conjunto de dados da característica.</p>";
         solGS.showMessage(histMsgIdRaw, msg);
     });


     jQuery("#pheno_means_histo_canvas").on('click' , 'a', function(e) {
		var buttonId = e.target.id;
		var histoPlotId = buttonId.replace(/download_/, '');
		saveSvgAsPng(document.getElementById("#" + histoPlotId),  histoPlotId + ".png", {scale:1});	
	});

    jQuery("#pheno_raw_histo_canvas").on('click' , 'a', function(e) {
		var buttonId = e.target.id;
		var histoPlotId = buttonId.replace(/download_/, '');
		saveSvgAsPng(document.getElementById("#" + histoPlotId),  histoPlotId + ".png", {scale:1});	
	});

});

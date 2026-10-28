/** 
* heritability coefficients plotting using d3
* Chris Simoes <cs263@cornell.edu>
*
*/


jQuery(document).ready( function() {


     jQuery("#run_pheno_heritability").show();    
    // var page = document.URL;


    
    // if (page.match(/solgs\/traits\/all\//) != null || 
    //     page.match(/solgs\/models\/combined\/trials\//) != null) {
    
    // setTimeout(function() {listGenCorPopulations()}, 5000);
        
    // } else {

    // var url = window.location.pathname;

    // if (url.match(/[solgs\/population|breeders_toolbox\/trial|breeders\/trial]/)) {
    //     checkPhenoH2Result();  
    // } 
    // }
          
});


function checkPhenoH2Result () {
    
    var popDetails = getPopulationDetails();
    var popId      = popDetails.population_id;
   
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        url: '/phenotype/heritability/check/result/' + popId,
        success: function(response) {
            if (response.result) {
        phenotypicHeritability();                    
            } else { 
        jQuery("#run_pheno_heritability").show();    
            }
    }
    });
    
}


jQuery(document).ready( function() { 

    jQuery("#run_pheno_heritability").click(function() {
        phenotypicHeritability();
	jQuery("#run_pheno_heritability").hide();
    }); 
  
});



function listGenCorPopulations ()  {
    var modelData = solGS.sIndex.getTrainingPopulationData();
   
    var trainingPopIdName = JSON.stringify(modelData);
   
    var  popsList =  '<dl id="h2_selected_population" class="h2_dropdown">'
        + "<dt> <a href=\"#\"><span>Escolha uma população</span></a></dt>"
        + '<dd>'
        + '<ul>'
        + '<li>'
        + '<a href="#">' + modelData.name + '<span class=value>' + trainingPopIdName + '</span></a>'
        + '</li>';  
 
    popsList += '</ul></dd></dl>'; 
   
    jQuery("#h2_select_a_population_div").empty().append(popsList).show();
     
    var dbSelPopsList;
    if (modelData.id.match(/list/) == null) {
        dbSelPopsList = solGS.sIndex.addSelectionPopulations();
    }

    if (dbSelPopsList) {
            jQuery("#h2_select_a_population_div ul").append(dbSelPopsList); 
    }
      
    var listTypeSelPops = jQuery("#list_type_selection_pops_table").length;
   
    if (listTypeSelPops) {
        var selPopsList = solGS.listTypeSelectionPopulation.getListTypeSelPopulations();

        if (selPopsList) {
            jQuery("#h2_select_a_population_div ul").append(selPopsList);  
        }
    }

    jQuery(".h2_dropdown dt a").click(function() {
        jQuery(".h2_dropdown dd ul").toggle();
    });
                 
    jQuery(".h2_dropdown dd ul li a").click(function() {
      
        var text = jQuery(this).html();
           
        jQuery(".h2_dropdown dt a span").html(text);
        jQuery(".h2_dropdown dd ul").hide();
                
        var idPopName = jQuery("#h2_selected_population").find("dt a span.value").html();
        idPopName     = JSON.parse(idPopName);
        modelId       = jQuery("#model_id").val();
                   
        var selectedPopId   = idPopName.id;
        var selectedPopName = idPopName.name;
        var selectedPopType = idPopName.pop_type; 
       
        jQuery("#h2_selected_population_name").val(selectedPopName);
        jQuery("#h2_selected_population_id").val(selectedPopId);
        jQuery("#h2_selected_population_type").val(selectedPopType);
                                
    });
                       
    jQuery(".h2_dropdown").bind('click', function(e) {
        var clicked = jQuery(e.target);
               
        if (! clicked.parents().hasClass("h2_dropdown"))
            jQuery(".h2_dropdown dd ul").hide();

        e.preventDefault();

    });           
}


function formatGenCorInputData (popId, type, indexFile) {
    var modelDetail = getPopulationDetails();

    
    var traitsIds = jQuery('#training_traits_ids').val();
    if(traitsIds) {
    traitsIds = traitsIds.split(',');
    }

    var modelId  = modelDetail.population_id;
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'model_id': modelId,
           'h2_population_id': popId,
           'traits_ids': traitsIds,
           'type' : type,
           'index_file': indexFile},
        url: '/heritability/genetic/data/',
        success: function(response) {

            if (response.status) {
        
                gebvsFile = response.gebvs_file;
        indexFile = response.index_file;
        
                var divPlace;
                if (indexFile) {
                    divPlace = '#si_heritability_canvas';
                }

                var args = {
                    'model_id': modelDetail.population_id, 
                    'h2_population_id': popId, 
                    'type': type,
            'traits_ids': traitsIds,
                    'gebvs_file': gebvsFile,
            'index_file': indexFile,
                    'div_place' : divPlace,
                };
        
                runGenHeritabilityAnalysis(args);

            } else {
                jQuery(divPlace +" #heritability_message")
                    .css({"padding-left": '0px'})
                    .html("Este ensaio não possui características válidas para calcular a herdabilidade.");
        
            }
        },
        error: function(response) {
            jQuery(divPlace +"#heritability_message")
                .css({"padding-left": '0px'})
                .html("Erro 3 ao preparar os dados genéticos aditivos para a análise de herdabilidade.");
             
            jQuery.unblockUI();
        }         
    });
}


function getPopulationDetails () {

    var populationId = jQuery("#population_id").val();
    var populationName = jQuery("#population_name").val();
   
    if (populationId == 'undefined') {       
        populationId = jQuery("#model_id").val();
        populationName = jQuery("#model_name").val();
    }

    return {'population_id' : populationId, 
            'population_name' : populationName
           };        
}


function phenotypicHeritability () {
 
    var population = getPopulationDetails();
    
    jQuery("#heritability_message").html("Executando análise de herdabilidade...");
         
    jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: {'population_id': population.population_id },
            url: '/heritability/phenotype/data/',
            success: function(response) {
    
                if (response.result) {
		    console.log('phenotypicHeritability ' + response.result)
                    runPhenoHeritabilityAnalysis();
                } else {
                    jQuery("#heritability_message")
                        .css({"padding-left": '0px'})
                        .html("Esta população não possui dados fenotípicos.");

		    jQuery("#run_pheno_heritability").show();
                }
            },
            error: function(response) {
                jQuery("#heritability_message")
                    .css({"padding-left": '0px'})
                    .html("Verifique se os dados possuem repetições.");

		jQuery("#run_pheno_heritability").show();
            }
    });     
}


function runPhenoHeritabilityAnalysis () {
    var population = getPopulationDetails();
    var popId     = population.population_id;
   
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'population_id': popId },
        url: '/phenotypic/heritability/analysis/output',
        success: function(response) {
            if (response.status== 'success') {
                plotHeritability(response.data);
        
        var h2Download = "<a href=\"/download/phenotypic/heritability/population/" 
                            + popId + "\">Baixar coeficientes de herdabilidade</a>";

        jQuery("#heritability_canvas").append("<br />[ " + h2Download + " ]").show();
    
        // if(document.URL.match('/breeders/trial/')) {
        //     displayTraitAcronyms(response.acronyms);
        // }
        
                jQuery("#heritability_message").empty();
		jQuery("#run_pheno_heritability").hide();
            } else {
                jQuery("#heritability_message")
                    .css({"padding-left": '0px'})
                    .html("Verifique se há dados numéricos e repetições para este ensaio.");
        
		jQuery("#run_pheno_heritability").show();
            }
        },
        error: function(response) {                          
            jQuery("#heritability_message")
                .css({"padding-left": '0px'})
                .html("Erro 2 ao executar a análise de herdabilidade.");
            
        jQuery("#run_pheno_heritability").show();
        }                
    });
}


function createHeritabilityTable (tableId) {
    
    var table = '<table id="' + tableId + '" class="table" style="width:100%;text-align:left">';
    table    += '<thead><tr>';
    table    += "<th>Característica</th><th>VG</th><th>Vres</th><th>Herdabilidade</th>";
    table    += '</tr></thead>';
    table    += '</table>';

    return table;

}


function plotHeritability (data, divPlace) {
    console.log(data)
  
    if (data) {
    var h2tableId = 'heritability_table';    
    var h2table = createHeritabilityTable(h2tableId);

    jQuery('#heritability_canvas').append(h2table); 
       
    jQuery('#' + h2tableId).dataTable({
            'searching'    : true,
            'ordering'     : true,
            'processing'   : true,
            'lengthChange' : false,
                    "bInfo"        : false,
                    "paging"       : false,
                    'oLanguage'    : {
                             "sSearch": "Filtrar características: "
                            },
            'data'         : data,
        });
    }
   
}



  

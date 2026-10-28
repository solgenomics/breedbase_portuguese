
var CXGN;
if (!CXGN) CXGN = function () { };

CXGN.Dataset = function () {
    this.dataset = [];
};


CXGN.Dataset.prototype = {

    // return info on all available datasets
    getDatasets: function() {
	var datasets=[];
	jQuery.ajax( {
	    'url' : '/ajax/dataset/by_user',
	    'async': false,
	    'success': function(response) {
		if (response.error) {
		    //alert(response.error);
		}
		    datasets = response;

	    },
            'error': function(response) {
		alert("Ocorreu um erro. Tente novamente.");
	    }
	});
	return datasets;
    },

    // return info on public datasets
    getPublicDatasets: function() {
        var datasets=[];
        jQuery.ajax( {
            'url' : '/ajax/dataset/get_public',
            'async': false,
            'success': function(response) {
                if (response.error) {
                    //alert(response.error);
                }
                    datasets = response;

            },
            'error': function(response) {
                alert("Ocorreu um erro. Tente novamente.");
            }
        });
        return datasets;
    },

    getDataset: function(id) {
	var dataset;
	jQuery.ajax( {
	    "url" : "/ajax/dataset/get/"+id,
	    "async": false,
	    "success": function(response) {
		if (response.error) {
		    alert(response.error);
		}
		else {
		    dataset = response.dataset;
		}
	    },
	    "error": function(response) {
		alert("Ocorreu um erro. O conjunto de dados especificado pode não existir. Tente novamente."+JSON.stringify(response));
	    }
	});
	return dataset;

    },

    deleteDataset: function(id, callback) {
      	var dataset;
        jQuery.ajax( {
            'url' : '/ajax/dataset/delete/'+id,
            'async': false,
            'success': function(response) {
                if (response.error) {
                    alert("Ocorreu um erro ao excluir o conjunto de dados. "+response.error);
                }
                else {
                    if ( callback ) {
                        return callback();
                    }
                    else {
                        alert("O conjunto de dados foi excluído.");
                    }
                }
            },
            'error': function(response) {
                alert("Ocorreu um erro. O conjunto de dados especificado pode não existir. Tente novamente."+JSON.stringify(response));
            }
        });
    },

    makePublicDataset: function(id, callback) {
        var dataset;
        jQuery.ajax( {
            'url' : '/ajax/dataset/set_public/'+id,
            'async': false,
            'success': function(response) {
                if (response.error) {
                    alert("Ocorreu um erro durante a operação. "+response.error);
                } else {
                    if ( callback ) {
                        return callback();
                    }
                    else {
                        alert("O conjunto de dados agora é público.");
                    }
                }
            },
            'error': function(response) {
                alert("Ocorreu um erro. O conjunto de dados especificado pode não existir. Tente novamente."+JSON.stringify(response));

            }
        });
    },

   makePrivateDataset: function(id, callback) {
        var dataset;
        jQuery.ajax( {
            'url' : '/ajax/dataset/set_private/'+id,
            'async': false,
            'success': function(response) {
                if (response.error) {
                    alert("Ocorreu um erro durante a operação. "+response.error);
                } else {
                    if ( callback ) {
                        return callback();
                    }
                    else {
                        alert("O conjunto de dados agora é privado.");
                    }
                }
            },
            'error': function(response) {
                alert("Ocorreu um erro. O conjunto de dados especificado pode não existir. Tente novamente."+JSON.stringify(response));

            }
        });
    },

    updateDescription: function(id, callback) {
	var dataset;
	var description = document.getElementById('description').value
        jQuery.ajax( {
            'url' : '/ajax/dataset/update_description/'+id,
            'async': false,
	    'dataType': "json",
            'data': {
                'description': description
             },

            'success': function(response) {
                if (response.error) {
                    alert("Ocorreu um erro durante a operação. "+response.error);
                } else {
                    if ( callback ) {
                        callback(description)
                    }
                    else {
                        alert("A descrição do conjunto de dados foi atualizada.");
                    }
                }
            },
            'error': function(response) {
                alert("Ocorreu um erro. Não foi possível atualizar a descrição do conjunto de dados. Tente novamente."+JSON.stringify(response));

            }
        });
    },

    datasetSelect: function(div_name, empty_element, refresh) {

  var datasets = new Array();
  datasets = this.getDatasets();
  var html = '<select class="form-control input-sm" id="'+div_name+'_dataset_select" name="'+div_name+'_dataset_select" >';
  if (empty_element) {
      html += '<option value="">'+empty_element+'</option>\n';
        }
  for (var n=0; n<datasets.length; n++) {
      html += '<option value='+datasets[n][0]+'>'+datasets[n][1]+'</option>';
  }
  if (refresh) {
    html = '<div class="input-group">'+html+'</select><span class="input-group-btn"><button class="btn btn-default" type="button" id="'+div_name+"_dataset_refresh\" title=\"Atualizar conjuntos de dados\" onclick=\"refreshDatasetSelect('"+div_name+"_dataset_select, 'Opções atualizadas')\"&gt;<span class=\"glyphicon glyphicon-refresh\" aria-hidden=\"true\"></span></button></span></div>";
    return html;
  }
  else {
    html = html + '</select>';
    return html;
  }
},

    renderDatasets: function(div) {
	var datasets = this.getDatasets();
	var html = '';

	if (!datasets || datasets.length===0) {
	    html = html + "Nenhum";
	    jQuery('#'+div+'_div').html(html);
	    return;
	}

	html += '<table class="table table-hover table-condensed">';
	html += "<thead><tr><th>Nome do conjunto de dados</th><th>Descrição</th><th colspan=\"4\">Ações</th></tr></thead><tbody><tr>";
	for (var i = 0; i < datasets.length; i++) {
	    html += '<td><b>'+datasets[i][1]+'</b></td>';
	    html += '<td>'+datasets[i][2]+'</td>';
	    html += "<td><a title=\"Visualizar\" id=\"view_dataset_"+datasets[i][1]+'" href="javascript:showDatasetItems(\'dataset_item_dialog\','+datasets[i][0]+')"><span class="glyphicon glyphicon-th-list"></span></a></td>';
	    html += "<td><a title=\"Excluir\" id=\"delete_dataset_"+datasets[i][1]+'" href="javascript:deleteDataset('+datasets[i][0]+')"><span class="glyphicon glyphicon-remove"></span></a></td></tr>';
	}
	html = html + '</tbody></table>';
	html += '<div id="list_group_select_action"></div>';

	jQuery('#'+div+'_div').html(html);
    },

    renderItems: function(div, dataset_id) {
	var dataset = this.getDataset(dataset_id);

	var html = "Este conjunto de dados contém:<br />";

	var zero_count = 0;
	for(var key in dataset.categories) {
	    if (dataset.categories.hasOwnProperty(key)) {
		if (dataset.categories[key]===null || dataset.categories[key].length===0) {
		    zero_count++;
		}
		else {		   
		    html += dataset.categories[key].length+" elementos do tipo <b>"+key+"</b><br />";
		}
	    }
	}

	if (zero_count === Object.keys(dataset.categories).length) { 
	    jQuery('#'+div).html("Este conjunto de dados não contém seleções.");
	}
	else { 
	    jQuery('#'+div).html(html);
	}
    }
}

function refreshDatasetSelect(div_name, empty_element) {
  var l = new CXGN.Dataset();
  var datasets = l.getDatasets();
  var html;
  if (empty_element) {
      html += '<option value="">'+empty_element+'</option>\n';
        }
  for (var n=0; n<datasets.length; n++) {
      html += '<option value='+datasets[n][0]+'>'+datasets[n][1]+'</option>';
  }
  jQuery('#'+div_name).html(html);
}

function setUpDatasets() {
//    jQuery("button[name='datasets_link']").click(
//	function() { show_datasets(); }
//    );
}

function show_datasets() {
    jQuery('#dataset_dialog').modal("show");
    var l = new CXGN.Dataset();
    l.renderDatasets('dataset_dialog');
}

function deleteDataset(dataset_id) {
    var reply = confirm("Tem certeza de que deseja excluir o conjunto de dados com ID "+dataset_id+"? A exclusão não pode ser desfeita.");

    if (reply) {
	jQuery.ajax( {
	    'url' : '/ajax/dataset/delete/'+dataset_id,
	    'success': function(response) {
		if (response.error) {
		    alert(response.error);
		}
		else {
		    alert("Conjunto de dados excluído com sucesso. ID "+dataset_id);
		}
	    },
	    'error': function(response) {
		alert("Ocorreu um erro de processamento.");
	    }
	})
    }

}

function showDatasetItems(div, dataset_id) {

    working_modal_show();

    var d = new CXGN.Dataset();

    jQuery('#'+div).html("Olá!");
    
    d.renderItems(div, dataset_id);

    jQuery('#'+div).modal("show");

    working_modal_hide();
}

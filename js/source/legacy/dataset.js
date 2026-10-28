/*  used by dataset detail page */

var datasets = new CXGN.Dataset();

function datasetDelete(val) {
    if ( confirm(`Conjunto de dados. Tem certeza de que deseja excluí-lo? A exclusão não pode ser desfeita.`)) {
        datasets.deleteDataset(val, () => {
            window.location.reload();
        });
    }
}

function datasetPublic(val) {
    datasets.makePublicDataset(val, () => {
        jQuery("#dataset-edit-private").show();
        jQuery("#dataset-edit-public").hide();
        window.location.reload();
    });
}

function datasetPrivate(val) {
    datasets.makePrivateDataset(val, () => {
        jQuery("#dataset-edit-private").hide();
        jQuery("#dataset-edit-public").show();
        window.location.reload();
    });
}

function datasetEdit() {
    jQuery("#dataset-description-display").hide();
    jQuery("#dataset-description-update").show();
}

function datasetUpdate(val) {
    datasets.updateDescription(val, (updated) => {
        jQuery("#dataset-description-update-content").html(updated.replace(/\n/g, "<br />"))
        jQuery("#dataset-description-display").show();
        jQuery("#dataset-description-update").hide();
    });
}


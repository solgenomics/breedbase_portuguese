/**
* functions for displaying submitted job
* information on the user details page
*
* @author Ryan Preble <rsp98@cornell.edu>
*
*/

export function dismiss_job(job_id) {
    if(confirm("Dispensar esta tarefa remove o registro do envio, mas não exclui as análises resultantes nem outros dados. Tem certeza de que deseja continuar?")) {
        $.ajax({
            url: '/ajax/job/delete/'+job_id,
            success: function(response) {
                if (response.error) {
                    alert("Erro ao dispensar a tarefa.");
                    window.location.reload();
                } else {
                    alert("Registro da tarefa excluído.");
                    window.location.reload();
                }
            },
            error: function(response) {
                alert("Erro ao dispensar a tarefa.");
                window.location.reload();
            }
        });
    } 
}

export function dismiss_finished_jobs(user_id) {
    if (confirm("Dispensar todas as tarefas concluídas e canceladas?")){

        $.ajax({
            url: '/ajax/job/delete_finished/'+user_id,
            success: function(response) {
                if (response.error) {
                    alert("Erro ao dispensar as tarefas.");
                    window.location.reload();
                } else {
                    alert("Tarefas removidas.");
                    window.location.reload();
                }
            },
            error: function(response) {
                alert("Erro ao dispensar as tarefas.");
                window.location.reload();
            }
        });
    }
}

export function cancel_job(job_id) {
    if(confirm("Tem certeza de que deseja cancelar?")) {
        $.ajax({
            url: '/ajax/job/cancel/'+job_id,
            success: function(response) {
                if (response.error) {
                    alert("Erro ao cancelar a tarefa.");
                } else {
                    alert("Tarefa cancelada.");
                    window.location.reload();
                }
            },
            error: function(response) {
                alert("Erro ao cancelar a tarefa.");
            }
        });
    } 
}

export function keep_recent_jobs(user_id) {
    if (confirm("Dispensar tarefas antigas?")){
        var interval = jQuery('#keep_recent_jobs_select').val();

        $.ajax({
            url: '/ajax/job/delete_older_than/'+interval+'/'+user_id,
            success: function(response) {
                if (response.error) {
                    alert("Erro ao dispensar as tarefas.");
                    window.location.reload();
                } else {
                    alert("Tarefas removidas.");
                    window.location.reload();
                }
            },
            error: function(response) {
                alert("Erro ao dispensar as tarefas.");
                window.location.reload();
            }
        });
    }
}

export function dismiss_dead_jobs(user_id) {
    if (confirm("Dispensar as tarefas que falharam ou excederam o tempo limite?")) {
        $.ajax({
            url: '/ajax/job/delete_dead_jobs/'+user_id,
            success: function(response) {
                if (response.error) {
                    alert("Erro ao dispensar as tarefas.");
                    window.location.reload();
                } else {
                    alert("Tarefas removidas.");
                    window.location.reload();
                }
            },
            error: function(response) {
                alert("Erro ao dispensar as tarefas.");
                window.location.reload();
            }
        });
    }
}


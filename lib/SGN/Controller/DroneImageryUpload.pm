
=head1 NAME

=head1 DESCRIPTION

=head1 AUTHOR

=cut

package SGN::Controller::DroneImagery::DroneImageryUpload;
use utf8;

use Moose;
use Data::Dumper;
use JSON;
use SGN::Model::Cvterm;
use DateTime;
use Math::Round;
use Time::Piece;
use Time::Seconds;
use SGN::Image;
use CXGN::DroneImagery::ImagesSearch;
use File::Basename qw | basename dirname|;
use URI::Encode qw(uri_encode uri_decode);
use CXGN::Calendar;
use Image::Size;
use CXGN::DroneImagery::ImageTypes;
use LWP::UserAgent;
use CXGN::ZipFile;
use Text::CSV;
use SGN::Controller::AJAX::DroneImagery::DroneImagery;

BEGIN { extends 'Catalyst::Controller'; }

sub upload_drone_imagery : Path("/drone_imagery/upload_drone_imagery") :Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    print STDERR Dumper $c->req->params();

    my $selected_trial_id = $c->req->param('drone_run_field_trial_id');
    if (!$selected_trial_id) {
        $c->stash->{message} = "Selecione um ensaio de campo!";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }
    my $selected_drone_run_id = $c->req->param('drone_run_id');
    my $new_drone_run_name = $c->req->param('drone_run_name');
    my $new_drone_run_type = $c->req->param('drone_run_type');
    my $new_drone_run_date = $c->req->param('drone_run_date');
    my $new_drone_base_date = $c->req->param('drone_run_base_date');
    my $new_drone_run_desc = $c->req->param('drone_run_description');
    my $new_drone_rig_desc = $c->req->param('drone_run_camera_rig_description');
    my $new_drone_run_vehicle_id = $c->req->param('drone_run_imaging_vehicle_id');
    my $new_drone_run_battery_name = $c->req->param('drone_run_imaging_vehicle_battery_name');

    my $dir = $c->tempfiles_subdir('/upload_drone_imagery_bulk_previous');

    if (!$new_drone_run_vehicle_id) {
        $c->stash->{message} = "Informe o ID do veículo do evento de imageamento!";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    if (!$selected_drone_run_id && !$new_drone_run_name) {
        $c->stash->{message} = "Selecione um evento de imageamento ou crie um novo evento de imageamento!";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }
    if ($new_drone_run_name && !$new_drone_run_type){
        $c->stash->{message} = "Informe o tipo do novo evento de imageamento!";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }
    if ($new_drone_run_name && !$new_drone_run_date){
        $c->stash->{message} = "Informe a data do novo evento de imageamento!";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }
    if ($new_drone_run_name && $new_drone_run_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
        $c->stash->{message} = "Informe a data do novo evento de imageamento no formato YYYY/MM/DD HH:mm:ss!";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }
    if ($new_drone_run_name && $new_drone_base_date && $new_drone_base_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
        $c->stash->{message} = "Informe a data-base do novo evento de imageamento no formato YYYY/MM/DD HH:mm:ss!";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    if ($new_drone_run_name && !$new_drone_run_desc){
        $c->stash->{message} = "Informe a descrição do novo evento de imageamento!";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    my $new_drone_run_camera_info = $c->req->param('drone_image_upload_camera_info');
    my $new_drone_run_band_numbers = $c->req->param('drone_run_band_number');
    my $new_drone_run_band_stitching = $c->req->param('drone_image_upload_drone_run_band_stitching');
    my $new_drone_run_band_stitching_odm_more_images = 'No';
    my $new_drone_run_band_stitching_odm_current_image_count = 0;
    my $new_drone_run_band_stitching_odm_radiocalibration = $c->req->param('drone_image_upload_drone_run_band_stitching_odm_radiocalibration') eq "Yes" ? 1 : 0;

    if (!$new_drone_run_camera_info) {
        $c->stash->{message} = "Indique o tipo de câmera!";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    if ($new_drone_run_band_stitching eq 'no' && !$new_drone_run_band_numbers) {
        $c->stash->{message} = "Informe o número de bandas do novo evento de imageamento!";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }
    if (!$new_drone_run_band_stitching) {
        $c->stash->{message} = "Indique se as imagens já estão unidas em ortofotomosaico!";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    my $odm_process_running_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_opendronemap_process_running', 'project_property')->cvterm_id();
    if ($new_drone_run_band_stitching eq 'yes_open_data_map_stitch') {
        my $upload_file = $c->req->upload('upload_drone_images_zipfile');
        my $upload_panel_file = $c->req->upload('upload_drone_images_panel_zipfile');
        if (!$upload_file) {
            $c->stash->{message} = "Forneça um arquivo ZIP com as imagens brutas!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        if (!$upload_panel_file && $new_drone_run_camera_info eq 'micasense_5') {
            $c->stash->{message} = "Forneça um arquivo ZIP com as imagens dos painéis de calibração radiométrica Micasense!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }

        my $q = "SELECT count(*) FROM projectprop WHERE type_id=$odm_process_running_cvterm_id AND value='1';";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute();
        my ($odm_running_count) = $h->fetchrow_array();
        if ($odm_running_count >= $c->config->{opendronemap_max_processes}) {
            $c->stash->{message} = "Já existe o número máximo de processos do OpenDroneMap em execução nesta máquina! Volte mais tarde, quando esses processos tiverem terminado.";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
    }

    # if ($selected_drone_run_id && ($new_drone_run_band_stitching eq 'yes' || $new_drone_run_band_stitching eq 'yes_raw' || $new_drone_run_band_stitching eq 'yes_automated')) {
    #     $c->stash->{rest} = { error => "Please create a new drone run if you are uploading a zipfile of raw images!" };
    #     $c->detach();
    # }

    my $log_file_path = '';
    if ($c->config->{error_log}){
        $log_file_path = "--log_file_path '".$c->config->{error_log}."'";
    }

    my $drone_run_nd_experiment_id;
    if (!$selected_drone_run_id) {
        my $drone_run_field_trial_project_relationship_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
        my $drone_run_band_drone_run_project_relationship_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
        my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();

        my $calendar_funcs = CXGN::Calendar->new({});

        my %seen_field_trial_drone_run_dates;
        my $drone_run_date_q = "SELECT drone_run_date.value
            FROM project AS drone_run_band_project
            JOIN project_relationship AS drone_run_band_rel ON (drone_run_band_rel.subject_project_id = drone_run_band_project.project_id AND drone_run_band_rel.type_id = $drone_run_band_drone_run_project_relationship_type_id_cvterm_id)
            JOIN project AS drone_run_project ON (drone_run_band_rel.object_project_id = drone_run_project.project_id)
            JOIN projectprop AS drone_run_date ON(drone_run_project.project_id=drone_run_date.project_id AND drone_run_date.type_id=$project_start_date_type_id)
            JOIN project_relationship AS field_trial_rel ON (drone_run_project.project_id = field_trial_rel.subject_project_id AND field_trial_rel.type_id=$drone_run_field_trial_project_relationship_type_id_cvterm_id)
            JOIN project AS field_trial ON (field_trial_rel.object_project_id = field_trial.project_id)
            WHERE field_trial.project_id = ?;";
        my $drone_run_date_h = $schema->storage->dbh()->prepare($drone_run_date_q);
        $drone_run_date_h->execute($selected_trial_id);
        while( my ($drone_run_date) = $drone_run_date_h->fetchrow_array()) {
            my $drone_run_date_formatted = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
            if ($drone_run_date_formatted) {
                my $date_obj = Time::Piece->strptime($drone_run_date_formatted, "%Y-%B-%d %H:%M:%S");
                my $epoch_seconds = $date_obj->epoch;
                $seen_field_trial_drone_run_dates{$epoch_seconds}++;
            }
        }
        my $drone_run_date_obj = Time::Piece->strptime($new_drone_run_date, "%Y/%m/%d %H:%M:%S");
        if (exists($seen_field_trial_drone_run_dates{$drone_run_date_obj->epoch})) {
            $c->stash->{rest} = { error => "Já existe um evento de imageamento neste ensaio de campo na mesma data e hora! Informe uma data/hora única para cada evento de imageamento!" };
            $c->detach();
        }

        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $selected_trial_id });
        my $trial_location_id = $trial->get_location()->[0];
        my $planting_date = $trial->get_planting_date();
        my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
        my $drone_run_date_time_object = Time::Piece->strptime($new_drone_run_date, "%Y/%m/%d %H:%M:%S");
        my $time_diff;
        my $base_date_event;
        if ($new_drone_base_date) {
            my $imaging_event_base_date_time_object = Time::Piece->strptime($new_drone_base_date, "%Y/%m/%d %H:%M:%S");
            $time_diff = $drone_run_date_time_object - $imaging_event_base_date_time_object;
            $base_date_event = $calendar_funcs->check_value_format($new_drone_base_date);
        }
        else {
            $time_diff = $drone_run_date_time_object - $planting_date_time_object;
        }
        my $time_diff_weeks = $time_diff->weeks;
        my $time_diff_days = $time_diff->days;
        my $time_diff_hours = $time_diff->hours;
        my $rounded_time_diff_weeks = round($time_diff_weeks);
        if ($rounded_time_diff_weeks == 0) {
            $rounded_time_diff_weeks = 1;
        }

        my $week_term_string = "week $rounded_time_diff_weeks";
        my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($week_term_string, 'cxgn_time_ontology');
        my ($week_cvterm_id) = $h->fetchrow_array();

        if (!$week_cvterm_id) {
            my $new_week_term = $schema->resultset("Cv::Cvterm")->create_with({
               name => $week_term_string,
               cv => 'cxgn_time_ontology'
            });
            $week_cvterm_id = $new_week_term->cvterm_id();
        }

        my $day_term_string = "day $time_diff_days";
        $h->execute($day_term_string, 'cxgn_time_ontology');
        my ($day_cvterm_id) = $h->fetchrow_array();

        if (!$day_cvterm_id) {
            my $new_day_term = $schema->resultset("Cv::Cvterm")->create_with({
               name => $day_term_string,
               cv => 'cxgn_time_ontology'
            });
            $day_cvterm_id = $new_day_term->cvterm_id();
        }

        my $week_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $week_cvterm_id, 'extended');
        my $day_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $day_cvterm_id, 'extended');

        my %related_cvterms = (
            week => $week_term,
            day => $day_term
        );

        my $drone_run_event = $calendar_funcs->check_value_format($new_drone_run_date);
        my $drone_run_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_experiment', 'experiment_type')->cvterm_id();
        my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
        my $drone_run_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_project_type', 'project_property')->cvterm_id();
        my $drone_run_is_raw_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_is_raw_images', 'project_property')->cvterm_id();
        my $drone_run_camera_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
        my $drone_run_base_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_base_date', 'project_property')->cvterm_id();
        my $drone_run_rig_desc_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_rig_description', 'project_property')->cvterm_id();
        my $drone_run_related_cvterms_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_related_time_cvterms_json', 'project_property')->cvterm_id();
        my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
        my $imaging_vehicle_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle', 'stock_type')->cvterm_id();
        my $imaging_vehicle_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle_json', 'stock_property')->cvterm_id();

        my $drone_run_projectprops = [
            {type_id => $drone_run_type_cvterm_id, value => $new_drone_run_type},
            {type_id => $project_start_date_type_id, value => $drone_run_event},
            {type_id => $design_cvterm_id, value => 'drone_run'},
            {type_id => $drone_run_camera_type_cvterm_id, value => $new_drone_run_camera_info},
            {type_id => $drone_run_related_cvterms_cvterm_id, value => encode_json \%related_cvterms}
        ];

        if ($new_drone_run_band_stitching ne 'no') {
            push @$drone_run_projectprops, {type_id => $drone_run_is_raw_cvterm_id, value => 1};
        }
        if ($new_drone_base_date) {
            push @$drone_run_projectprops, {type_id => $drone_run_base_date_type_id, value => $base_date_event};
        }
        if ($new_drone_rig_desc) {
            push @$drone_run_projectprops, {type_id => $drone_run_rig_desc_type_id, value => $new_drone_rig_desc};
        }

        my $nd_experiment_rs = $schema->resultset("NaturalDiversity::NdExperiment")->create({
            nd_geolocation_id => $trial_location_id,
            type_id => $drone_run_experiment_type_id,
            nd_experiment_stocks => [{stock_id => $new_drone_run_vehicle_id, type_id => $drone_run_experiment_type_id}]
        });
        $drone_run_nd_experiment_id = $nd_experiment_rs->nd_experiment_id();

        my $project_rs = $schema->resultset("Project::Project")->create({
            name => $new_drone_run_name,
            description => $new_drone_run_desc,
            projectprops => $drone_run_projectprops,
            project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_trial_id}],
            nd_experiment_projects => [{nd_experiment_id => $drone_run_nd_experiment_id}]
        });
        $selected_drone_run_id = $project_rs->project_id();

        my $vehicle_prop = decode_json $schema->resultset("Stock::Stockprop")->search({stock_id => $new_drone_run_vehicle_id, type_id=>$imaging_vehicle_properties_cvterm_id})->first()->value();
        $vehicle_prop->{batteries}->{$new_drone_run_battery_name}->{usage}++;
        my $vehicle_prop_update = $schema->resultset('Stock::Stockprop')->update_or_create({
            type_id=>$imaging_vehicle_properties_cvterm_id,
            stock_id=>$new_drone_run_vehicle_id,
            rank=>0,
            value=>encode_json $vehicle_prop
        },
        {
            key=>'stockprop_c1'
        });
    }

    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $geoparam_coordinates_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_geoparam_coordinates_type', 'project_property')->cvterm_id();
    my $geoparam_coordinates_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_geoparam_coordinates', 'project_property')->cvterm_id();

    my @return_drone_run_band_project_ids;
    my @return_drone_run_band_image_ids;
    my @return_drone_run_band_image_urls;
    my @raw_image_boundaries_temp_images;
    my %saved_image_stacks;
    my $output_path;
    my $alignment_output_path;
    my $cmd;

    my $image_types_allowed = CXGN::DroneImagery::ImageTypes::get_all_drone_run_band_image_types()->{hash_ref};
    my %seen_image_types_upload;

    if ($new_drone_run_band_stitching eq 'no') {
        my @new_drone_run_bands;
        if ($new_drone_run_band_numbers eq 'one_bw' || $new_drone_run_band_numbers eq 'one_rgb') {
            my $new_drone_run_band_name = $c->req->param('drone_run_band_name_1');
            my $new_drone_run_band_desc = $c->req->param('drone_run_band_description_1');
            my $new_drone_run_band_type = $c->req->param('drone_run_band_type_1');
            my $new_drone_run_band_coordinate_system = $c->req->param('drone_run_band_coordinate_system_1') || 'Pixels';
            if (!$new_drone_run_band_name) {
                $c->stash->{message} = "Informe o nome da banda do novo evento de imageamento!";
                $c->stash->{template} = 'generic_message.mas';
                return;
            }
            if (!$new_drone_run_band_desc){
                $c->stash->{message} = "Informe a descrição da banda do novo evento de imageamento!";
                $c->stash->{template} = 'generic_message.mas';
                return;
            }
            if (!$new_drone_run_band_type){
                $c->stash->{message} = "Informe o tipo da banda do novo evento de imageamento!";
                $c->stash->{template} = 'generic_message.mas';
                return;
            }
            if (!exists($image_types_allowed->{$new_drone_run_band_type})) {
                $c->stash->{message} = "Tipo de banda do evento de imageamento não suportado: $new_drone_run_band_type!";
                $c->stash->{template} = 'generic_message.mas';
                return;
            }
            if (exists($seen_image_types_upload{$new_drone_run_band_type})) {
                $c->stash->{message} = "Tipo de banda do evento de imageamento repetido: $new_drone_run_band_type! Cada banda de um evento de imageamento deve ter um tipo único!";
                $c->stash->{template} = 'generic_message.mas';
                return;
            }
            $seen_image_types_upload{$new_drone_run_band_type}++;

            my $upload_file = $c->req->upload('drone_run_band_stitched_ortho_image_1');
            if (!$upload_file) {
                $c->stash->{message} = "Forneça um arquivo ZIP OU um ortofotomosaico já unido!";
                $c->stash->{template} = 'generic_message.mas';
                return;
            }

            push @new_drone_run_bands, {
                name => $new_drone_run_band_name,
                description => $new_drone_run_band_desc,
                type => $new_drone_run_band_type,
                upload_file => $upload_file,
                coordinate_system => $new_drone_run_band_coordinate_system
            };
        } else {
            foreach (1..$new_drone_run_band_numbers) {
                my $new_drone_run_band_name = $c->req->param('drone_run_band_name_'.$_);
                my $new_drone_run_band_desc = $c->req->param('drone_run_band_description_'.$_);
                my $new_drone_run_band_type = $c->req->param('drone_run_band_type_'.$_);
                my $new_drone_run_band_coordinate_system = $c->req->param('drone_run_band_coordinate_system_'.$_) || 'Pixels';
                if (!$new_drone_run_band_name) {
                    $c->stash->{message} = "Informe o nome da banda do novo evento de imageamento!".$_;
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
                if (!$new_drone_run_band_desc){
                    $c->stash->{message} = "Informe a descrição da banda do novo evento de imageamento!";
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
                if (!$new_drone_run_band_type){
                    $c->stash->{message} = "Informe o tipo da banda do novo evento de imageamento!";
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
                if (!exists($image_types_allowed->{$new_drone_run_band_type})) {
                    $c->stash->{message} = "Tipo de banda do evento de imageamento não suportado: $new_drone_run_band_type!";
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
                if (exists($seen_image_types_upload{$new_drone_run_band_type})) {
                    $c->stash->{message} = "Tipo de banda do evento de imageamento repetido: $new_drone_run_band_type! Cada banda de um evento de imageamento deve ter um tipo único!";
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
                $seen_image_types_upload{$new_drone_run_band_type}++;

                my $upload_file = $c->req->upload('drone_run_band_stitched_ortho_image_'.$_);
                if (!$upload_file) {
                    $c->stash->{message} = "Forneça um arquivo ZIP OU um ortofotomosaico já unido!";
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }

                push @new_drone_run_bands, {
                    name => $new_drone_run_band_name,
                    description => $new_drone_run_band_desc,
                    type => $new_drone_run_band_type,
                    upload_file => $upload_file,
                    coordinate_system => $new_drone_run_band_coordinate_system
                };
            }
        }
        foreach (@new_drone_run_bands) {
            my $coordinate_system = $_->{coordinate_system};
            my $drone_run_band_type = $_->{type};
            my $upload_file = $_->{upload_file};
            my $new_drone_run_input_image = $upload_file->tempname;

            my @drone_run_band_projectprops = (
                {type_id => $drone_run_band_type_cvterm_id, value => $drone_run_band_type},
                {type_id => $design_cvterm_id, value => 'drone_run_band'},
                {type_id => $geoparam_coordinates_type_cvterm_id, value => $coordinate_system}
            );

            my $time = DateTime->now();
            my $timestamp = $time->ymd()."_".$time->hms();
            my $upload_original_name = $selected_drone_run_id."_".$drone_run_band_type.".png";

            my $ortho_file;
            my @geoparams_coordinates;
            if ($coordinate_system eq 'Pixels') {
                $ortho_file = $new_drone_run_input_image;
            }
            else {
                my @geoparams_coordinates;
                if ($drone_run_band_type eq 'RGB Color Image') {
                    my $outfile_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_image_r = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_image_g = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_image_b = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_geoparams = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/fileXXXX').".csv";

                    my $geo_cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/GDALOpenImageRGBGeoTiff.py --image_path $new_drone_run_input_image --outfile_path_image $outfile_image --outfile_path_image_1 $outfile_image_r --outfile_path_image_2 $outfile_image_g --outfile_path_image_3 $outfile_image_b --outfile_path_geo_params $outfile_geoparams ";
                    print STDERR $geo_cmd."\n";
                    my $geo_cmd_status = system($geo_cmd);
                    $ortho_file = $outfile_image;

                    open(my $fh_geoparams, '<', $outfile_geoparams) or die "Could not open file '".$outfile_geoparams."' $!";
                        print STDERR "Opened ".$outfile_geoparams."\n";
                        my $geoparams = <$fh_geoparams>;
                        chomp $geoparams;
                        @geoparams_coordinates = split ',', $geoparams;
                        print STDERR Dumper [$geoparams, \@geoparams_coordinates];
                    close($fh_geoparams);
                }
                else {
                    my $outfile_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_geoparams = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/fileXXXX').".csv";

                    my $geo_cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/GDALOpenSingleChannelImageGeoTiff.py --image_path $new_drone_run_input_image --outfile_path_image $outfile_image --outfile_path_geo_params $outfile_geoparams ";
                    print STDERR $geo_cmd."\n";
                    my $geo_cmd_status = system($geo_cmd);
                    $ortho_file = $outfile_image;

                    open(my $fh_geoparams, '<', $outfile_geoparams) or die "Could not open file '".$outfile_geoparams."' $!";
                        print STDERR "Opened ".$outfile_geoparams."\n";
                        my $geoparams = <$fh_geoparams>;
                        chomp $geoparams;
                        @geoparams_coordinates = split ',', $geoparams;
                        print STDERR Dumper [$geoparams, \@geoparams_coordinates];
                    close($fh_geoparams);
                }

                push @drone_run_band_projectprops, {type_id => $geoparam_coordinates_cvterm_id, value => encode_json \@geoparams_coordinates};
            }

            my $project_rs = $schema->resultset("Project::Project")->create({
                name => $_->{name},
                description => $_->{description},
                projectprops => \@drone_run_band_projectprops,
                project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_drone_run_id}]
            });
            my $selected_drone_run_band_id = $project_rs->project_id();

            my $uploader = CXGN::UploadFile->new({
                tempfile => $ortho_file,
                subdirectory => "drone_imagery_upload",
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role
            });
            my $archived_filename_with_path = $uploader->archive();
            my $md5 = $uploader->get_md5($archived_filename_with_path);
            if (!$archived_filename_with_path) {
                $c->stash->{message} = "Não foi possível salvar o arquivo $upload_original_name no arquivo permanente.";
                $c->stash->{template} = 'generic_message.mas';
                return;
            }
            unlink $new_drone_run_input_image;
            print STDERR "Archived Drone Image File: $archived_filename_with_path\n";

            my ($check_image_width, $check_image_height) = imgsize($archived_filename_with_path);
            if ($check_image_width > 16384) {
                my $cmd_resize = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/Resize.py --image_path \''.$archived_filename_with_path.'\' --outfile_path \''.$archived_filename_with_path.'\' --width 16384';
                print STDERR Dumper $cmd_resize;
                my $status_resize = system($cmd_resize);
            }
            elsif ($check_image_height > 16384) {
                my $cmd_resize = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/Resize.py --image_path \''.$archived_filename_with_path.'\' --outfile_path \''.$archived_filename_with_path.'\' --height 16384';
                print STDERR Dumper $cmd_resize;
                my $status_resize = system($cmd_resize);
            }

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            $image->set_sp_person_id($user_id);
            my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
            my $ret = $image->process_image($archived_filename_with_path, 'project', $selected_drone_run_band_id, $linking_table_type_id);
            push @return_drone_run_band_image_urls, $image->get_image_url('original');
            push @return_drone_run_band_image_ids, $image->get_image_id();
            push @return_drone_run_band_project_ids, $selected_drone_run_band_id;
        }
    }
    elsif ($new_drone_run_band_stitching eq 'yes_open_data_map_stitch') {
        my $upload_file = $c->req->upload('upload_drone_images_zipfile');
        my $upload_panel_file = $c->req->upload('upload_drone_images_panel_zipfile');

        my $upload_original_name = $upload_file->filename();
        my $upload_tempfile = $upload_file->tempname;
        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();
        print STDERR Dumper [$upload_original_name, $upload_tempfile];

        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => "drone_imagery_upload_odm_zips",
            second_subdirectory => "$selected_drone_run_id",
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $archived_filename_with_path = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_filename_with_path);
        if (!$archived_filename_with_path) {
            $c->stash->{message} = "Não foi possível salvar o arquivo $upload_original_name no arquivo permanente.";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        unlink $upload_tempfile;
        print STDERR "Archived Drone Image ODM Zip File: $archived_filename_with_path\n";

        my $image = SGN::Image->new( $c->dbc->dbh, undef, $c );
        my $zipfile_return = $image->upload_drone_imagery_zipfile($archived_filename_with_path, $user_id, $selected_drone_run_id);
        # print STDERR Dumper $zipfile_return;
        if ($zipfile_return->{error}) {
            $c->stash->{message} = "Problema ao salvar as imagens!".$zipfile_return->{error};
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        my $image_paths = $zipfile_return->{image_files};

        my $example_archived_filename_with_path_odm_img;
        foreach my $i (@$image_paths) {
            my $uploader_odm_dir = CXGN::UploadFile->new({
                tempfile => $i,
                subdirectory => "drone_imagery_upload_odm_dir",
                second_subdirectory => "$selected_drone_run_id",
                third_subdirectory => 'images',
                archive_path => $c->config->{archive_path},
                archive_filename => basename($i),
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role,
                include_timestamp => 0
            });
            my $archived_filename_with_path_odm_img = $uploader_odm_dir->archive();
            my $md5 = $uploader_odm_dir->get_md5($archived_filename_with_path_odm_img);
            if (!$archived_filename_with_path_odm_img) {
                $c->stash->{message} = "Não foi possível salvar o arquivo $i no arquivo permanente.";
                $c->stash->{template} = 'generic_message.mas';
                return;
            }
            print STDERR "Archived Drone Image ODM IMG File: $archived_filename_with_path_odm_img\n";
            $example_archived_filename_with_path_odm_img = $archived_filename_with_path_odm_img;
        }

        my $current_odm_image_count = $new_drone_run_band_stitching_odm_current_image_count+scalar(@$image_paths);
        if ($current_odm_image_count < 25) {
            $c->stash->{message} = "Envie mais de $current_odm_image_count imagens! São necessárias pelo menos 25 para que o OpenDroneMap possa uni-las.";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }

        print STDERR $example_archived_filename_with_path_odm_img."\n";
        my @img_path_split = split '\/', $example_archived_filename_with_path_odm_img;
        my $image_path_img_name = pop(@img_path_split);
        my $image_path_project_name = pop(@img_path_split);
        my $image_path_remaining = join '/', @img_path_split;
        # my $image_path_remaining_host = $image_path_remaining =~ s/cxgn\/sgn\/static\/documents\/tempfiles/tmp\/breedbase\-site/gr;
        my $hostpath = $c->config->{hostpath_archive};
        my $image_path_remaining_host = $image_path_remaining =~ s/\/home\/production/$hostpath/gr;
        print STDERR Dumper [$image_path_img_name, $image_path_project_name, $image_path_remaining, $image_path_remaining_host];

        my $dir = $c->tempfiles_subdir('/upload_drone_imagery_raw_images');
        my $temp_file_docker_log = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_images/fileXXXX');

        my $odm_check_prop = $schema->resultset("Project::Projectprop")->find_or_create({
            project_id => $selected_drone_run_id,
            type_id => $odm_process_running_cvterm_id
        });
        $odm_check_prop->value('1');
        $odm_check_prop->update();

        my @stitched_bands;
        my %raw_image_bands;
        eval {
            if ($new_drone_run_camera_info eq 'micasense_5') {
                my $upload_panel_original_name = $upload_panel_file->filename();
                my $upload_panel_tempfile = $upload_panel_file->tempname;

                my $uploader_panel = CXGN::UploadFile->new({
                    tempfile => $upload_panel_tempfile,
                    subdirectory => "drone_imagery_upload_odm_panel_zips",
                    second_subdirectory => "$selected_drone_run_id",
                    archive_path => $c->config->{archive_path},
                    archive_filename => $upload_panel_original_name,
                    timestamp => $timestamp,
                    user_id => $user_id,
                    user_role => $user_role
                });
                my $archived_filename_panel_with_path = $uploader_panel->archive();
                my $md5_panel = $uploader_panel->get_md5($archived_filename_panel_with_path);
                if (!$archived_filename_panel_with_path) {
                    $c->stash->{message} = "Não foi possível salvar o arquivo $archived_filename_panel_with_path no arquivo permanente.";
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
                unlink $upload_panel_tempfile;
                print STDERR "Archived Drone Image ODM Zip File: $archived_filename_panel_with_path\n";

                # my $dtm_string = '';
                # my $ua       = LWP::UserAgent->new();
                # my $response = $ua->post( $c->config->{main_production_site_url}."/RunODMDocker.php", { 'file_path' => $image_path_remaining_host, 'dtm_string' => $dtm_string } );
                # my $content  = $response->decoded_content();
                # print STDERR Dumper $content;

                my $odm_radiometric_calibration = $new_drone_run_band_stitching_odm_radiocalibration ? '--radiometric-calibration camera' : '';

                my $odm_command = 'docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v '.$image_path_remaining_host.':/datasets/code opendronemap/odm --project-path /datasets --rerun-all --dsm --dtm '.$odm_radiometric_calibration.' > '.$temp_file_docker_log;
                print STDERR $odm_command."\n";
                my $odm_status = system($odm_command);

                my $odm_b1 = "$image_path_remaining/odm_orthophoto/b1.png";
                my $odm_b2 = "$image_path_remaining/odm_orthophoto/b2.png";
                my $odm_b3 = "$image_path_remaining/odm_orthophoto/b3.png";
                my $odm_b4 = "$image_path_remaining/odm_orthophoto/b4.png";
                my $odm_b5 = "$image_path_remaining/odm_orthophoto/b5.png";
                my $odm_cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/ODMOpenImage.py --image_path $image_path_remaining/odm_orthophoto/odm_orthophoto.tif --outfile_path_b1 $odm_b1 --outfile_path_b2 $odm_b2 --outfile_path_b3 $odm_b3 --outfile_path_b4 $odm_b4 --outfile_path_b5 $odm_b5 --odm_radiocalibrated True";
                my $odm_open_status = system($odm_cmd);

                my $odm_dsm_png = "$image_path_remaining/odm_dem/dsm.png";
                my $odm_dtm_png = "$image_path_remaining/odm_dem/dtm.png";
                my $odm_subtract_png = "$image_path_remaining/odm_dem/subtract.png";
                my $odm_dem_cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/ODMOpenImageDSM.py --image_path_dsm $image_path_remaining/odm_dem/dsm.tif --image_path_dtm $image_path_remaining/odm_dem/dtm.tif --outfile_path_dsm $odm_dsm_png --outfile_path_dtm $odm_dtm_png --outfile_path_subtract $odm_subtract_png --band_number 1";
                my $odm_dem_open_status = system($odm_dem_cmd);

                @stitched_bands = (
                    ["Band 1", "OpenDroneMap Blue", "Blue (450-520nm)", $odm_b1],
                    ["Band 2", "OpenDroneMap Green", "Green (515-600nm)", $odm_b2],
                    ["Band 3", "OpenDroneMap Red", "Red (600-690nm)", $odm_b3],
                    ["Band 4", "OpenDroneMap NIR", "NIR (780-3000nm)", $odm_b4],
                    ["Band 5", "OpenDroneMap RedEdge", "Red Edge (690-750nm)", $odm_b5],
                    ["Band 6", "OpenDroneMap DSM", "Black and White Image", $odm_dsm_png]
                );
            }
            elsif ($new_drone_run_camera_info eq 'ccd_color' || $new_drone_run_camera_info eq 'cmos_color') {
                my $odm_command = 'docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v '.$image_path_remaining_host.':/datasets/code opendronemap/odm --project-path /datasets --rerun-all --dsm --dtm > '.$temp_file_docker_log;
                print STDERR $odm_command."\n";
                my $odm_status = system($odm_command);

                my $odm_dsm_png = "$image_path_remaining/odm_dem/dsm.png";
                my $odm_dtm_png = "$image_path_remaining/odm_dem/dtm.png";
                my $odm_subtract_png = "$image_path_remaining/odm_dem/subtract.png";
                my $odm_dem_cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/ODMOpenImageDSM.py --image_path_dsm $image_path_remaining/odm_dem/dsm.tif --image_path_dtm $image_path_remaining/odm_dem/dtm.tif --outfile_path_dsm $odm_dsm_png --outfile_path_dtm $odm_dtm_png --outfile_path_subtract $odm_subtract_png --band_number 1";
                my $odm_dem_open_status = system($odm_dem_cmd);

                @stitched_bands = (
                    ["Color Image", "OpenDroneMap RGB Color Image", "RGB Color Image", "$image_path_remaining/odm_orthophoto/odm_orthophoto.tif"],
                    ["DSM", "OpenDroneMap DSM", "Black and White Image", $odm_dsm_png]
                );
            }
            else {
                die "Camera info not supported for raw image upload ODM stitch: $new_drone_run_camera_info\n";
            }

            my $calibration_info = '';
            if ($new_drone_run_band_stitching_odm_radiocalibration && $new_drone_run_camera_info eq 'micasense_5') {
                $calibration_info = ' with radiocalibration';
            }
            elsif (!$new_drone_run_band_stitching_odm_radiocalibration && $new_drone_run_camera_info eq 'micasense_5') {
                $calibration_info = ' without radiocalibration';
            }

            print STDERR Dumper \@stitched_bands;

            foreach my $m (@stitched_bands) {
                my $project_rs = $schema->resultset("Project::Project")->create({
                    name => $new_drone_run_name."_".$m->[1],
                    description => $new_drone_run_desc.". ".$m->[0]." ".$m->[1].". Orthomosaic stitched by OpenDroneMap in ImageBreed".$calibration_info.".",
                    projectprops => [{type_id => $drone_run_band_type_cvterm_id, value => $m->[2]}, {type_id => $design_cvterm_id, value => 'drone_run_band'}],
                    project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_drone_run_id}]
                });
                my $selected_drone_run_band_id = $project_rs->project_id();

                my $time = DateTime->now();
                my $timestamp = $time->ymd()."_".$time->hms();
                my $upload_original_name = $new_drone_run_name."_ImageBreed_stitched_".$m->[1].".png";

                my $uploader = CXGN::UploadFile->new({
                    tempfile => $m->[3],
                    subdirectory => "drone_imagery_upload",
                    archive_path => $c->config->{archive_path},
                    archive_filename => $upload_original_name,
                    timestamp => $timestamp,
                    user_id => $user_id,
                    user_role => $user_role
                });
                my $archived_filename_with_path = $uploader->archive();
                my $md5 = $uploader->get_md5($archived_filename_with_path);
                if (!$archived_filename_with_path) {
                    $c->stash->{message} = "Não foi possível salvar o arquivo $upload_original_name no arquivo permanente.";
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
                unlink $upload_tempfile;
                print STDERR "Archived Drone Image File: $archived_filename_with_path\n";

                my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
                $image->set_sp_person_id($user_id);
                my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
                my $ret = $image->process_image($archived_filename_with_path, 'project', $selected_drone_run_band_id, $linking_table_type_id);
                push @return_drone_run_band_image_urls, $image->get_image_url('original');
                push @return_drone_run_band_image_ids, $image->get_image_id();
                push @return_drone_run_band_project_ids, $selected_drone_run_band_id;
            }
        };

        $odm_check_prop->value('0');
        $odm_check_prop->update();
    }

    $c->stash->{message} = "Enviado com sucesso! Acesse <a href='/breeders/drone_imagery'>Imagens de drone</a>";
    $c->stash->{template} = 'generic_message.mas';
    return;
}

sub upload_drone_imagery_bulk : Path("/drone_imagery/upload_drone_imagery_bulk") :Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    print STDERR Dumper $c->req->params();

    my $imaging_vehicle_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle', 'stock_type')->cvterm_id();
    my $imaging_vehicle_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle_json', 'stock_property')->cvterm_id();
    my $drone_run_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_experiment', 'experiment_type')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $drone_run_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_is_raw_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_is_raw_images', 'project_property')->cvterm_id();
    my $drone_run_camera_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();
    my $drone_run_base_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_base_date', 'project_property')->cvterm_id();
    my $drone_run_rig_desc_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_rig_description', 'project_property')->cvterm_id();
    my $drone_run_related_cvterms_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_related_time_cvterms_json', 'project_property')->cvterm_id();
    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $geoparam_coordinates_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_geoparam_coordinates_type', 'project_property')->cvterm_id();
    my $geoparam_coordinates_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_geoparam_coordinates', 'project_property')->cvterm_id();
    my $calendar_funcs = CXGN::Calendar->new({});

    my $upload_file = $c->req->upload('upload_drone_imagery_bulk_images_zipfile');
    my $imaging_events_file = $c->req->upload('upload_drone_imagery_bulk_imaging_events');

    my $upload_original_name = $upload_file->filename();
    my $upload_tempfile = $upload_file->tempname;
    my $upload_imaging_events_file = $imaging_events_file->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => "drone_imagery_upload_bulk_orthophoto_zips",
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{message} = "Não foi possível salvar o arquivo $upload_original_name no arquivo permanente.";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }
    unlink $upload_tempfile;
    print STDERR "Archived Drone Image Bulk Orthophoto Zip File: $archived_filename_with_path\n";

    my $archived_zip = CXGN::ZipFile->new(archived_zipfile_path=>$archived_filename_with_path);
    my $file_members = $archived_zip->file_members();
    if (!$file_members){
        $c->stash->{message} = 'Não foi possível ler o arquivo ZIP de ortofotos em lote. Ele está no formato .zip?';
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    my %spectral_lookup = (
        blue => "Blue (450-520nm)",
        green => "Green (515-600nm)",
        red => "Red (600-690nm)",
        rededge => "Red Edge (690-750nm)",
        nir => "NIR (780-3000nm)",
        mir => "MIR (3000-50000nm)",
        fir => "FIR (50000-1000000nm)",
        thir => "Thermal IR (9000-14000nm)",
        rgb => "RGB Color Image",
        bw => "Black and White Image"
    );

    my %sensor_map = (
        "MicaSense 5 Channel Camera" => "micasense_5",
        "CCD Color Camera" => "ccd_color",
        "CMOS Color Camera" => "cmos_color"
    );

    my %filename_imaging_event_lookup;
    my %filename_imaging_event_band_check;
    foreach (@$file_members) {
        my $image = SGN::Image->new( $dbh, undef, $c );
        my $filename = $_->fileName();
        my @zipfile_comp = split '\/', $filename;
        my $filename_wext;
        if (scalar(@zipfile_comp)==1) {
            $filename_wext = $zipfile_comp[0];
        }
        else {
            $filename_wext = $zipfile_comp[1];
        }
        my @filename_comps = split '\.', $filename_wext;
        my $filename_only = $filename_comps[0];
        my @image_spectra = split '\_\_', $filename_only;
        my $temp_file = $image->upload_zipfile_images($_);
        my $imaging_event_name = $image_spectra[0];
        my $band = $image_spectra[1];

        if (!exists($spectral_lookup{$band})) {
            $c->stash->{message} = "A banda espectral $band não é permitida na ortofoto informada $filename_only. Certifique-se de que as ortofotos sejam salvas como a concatenação do nome do evento de imageamento e da banda espectral, com dois sublinhados (__) como separador (ex.: Ortho1_01012020__blue.tiff); as bandas espectrais permitidas são blue,green,red,rededge,nir,mir,fir,thir,rgb,bw.";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        my $spectral_band = $spectral_lookup{$band};
        print STDERR Dumper [$filename_wext, $filename, $temp_file, $imaging_event_name, $spectral_band];
        $filename_imaging_event_lookup{$filename_wext} = {
            file => $temp_file,
            band => $spectral_band,
            band_short => $band
        };
        if (exists($filename_imaging_event_band_check{$imaging_event_name}->{$spectral_band})) {
            $c->stash->{message} = "Não envie tipos espectrais duplicados para o mesmo evento de imageamento. Já existe uma imagem $band para $imaging_event_name no arquivo ZIP! Certifique-se de que as ortofotos sejam salvas como a concatenação do nome do evento de imageamento e da banda espectral, com dois sublinhados (__) como separador (ex.: Ortho1_01012020__blue.tiff)";
            $c->stash->{template} = 'generic_message.mas';
            return;
        } else {
            $filename_imaging_event_band_check{$imaging_event_name} = $spectral_band;
        }
    }

    my @parse_csv_errors;
    my %field_trial_name_lookup;
    my %field_trial_ids_seen;
    my %vehicle_name_lookup;
    my %seen_field_trial_drone_run_dates;

    my $parser = Spreadsheet::ParseExcel->new();
    my $excel_obj = $parser->parse($upload_imaging_events_file);
    if (!$excel_obj) {
        $c->stash->{message} = 'Não foi possível abrir o arquivo Excel (.xls):'.$parser->error();
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    if (!$worksheet) {
        $c->stash->{message} = 'A planilha deve estar na 1ª aba do arquivo Excel (.xls).';
        $c->stash->{template} = 'generic_message.mas';
        return;
    }
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
        $c->stash->{message} = 'A planilha (.xls) não tem cabeçalho ou não contém nenhuma linha.';
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    if ($worksheet->get_cell(0,0)->value() ne 'Imaging Event Name' ||
        $worksheet->get_cell(0,1)->value() ne 'Type' ||
        $worksheet->get_cell(0,2)->value() ne 'Description' ||
        $worksheet->get_cell(0,3)->value() ne 'Date' ||
        $worksheet->get_cell(0,4)->value() ne 'Vehicle Name' ||
        $worksheet->get_cell(0,5)->value() ne 'Vehicle Battery Set' ||
        $worksheet->get_cell(0,6)->value() ne 'Sensor' ||
        $worksheet->get_cell(0,7)->value() ne 'Field Trial Name' ||
        $worksheet->get_cell(0,8)->value() ne 'Image Filenames' ||
        $worksheet->get_cell(0,9)->value() ne 'Coordinate System' ||
        $worksheet->get_cell(0,10)->value() ne 'Base Date' ||
        $worksheet->get_cell(0,11)->value() ne 'Camera Rig') {
            $c->stash->{message} = "A linha de cabeçalho da planilha CSV deve ser 'Imaging Event Name,Type,Description,Date,Vehicle Name,Vehicle Battery Set,Sensor,Field Trial Name,GeoJSON Filename,Image Filenames,Coordinate System,Base Date,Camera Rig'.";
            $c->stash->{template} = 'generic_message.mas';
            return;
    }

    my %seen_upload_dates;
    for my $row ( 1 .. $row_max ) {
        my $imaging_event_name;
        if ($worksheet->get_cell($row,0)) {
            $imaging_event_name = $worksheet->get_cell($row,0)->value();
        }
        my $imaging_event_type;
        if ($worksheet->get_cell($row,1)) {
            $imaging_event_type = $worksheet->get_cell($row,1)->value();
        }
        my $imaging_event_desc;
        if ($worksheet->get_cell($row,2)) {
            $imaging_event_desc = $worksheet->get_cell($row,2)->value();
        }
        my $imaging_event_date;
        if ($worksheet->get_cell($row,3)) {
            $imaging_event_date = $worksheet->get_cell($row,3)->value();
        }
        my $vehicle_name;
        if ($worksheet->get_cell($row,4)) {
            $vehicle_name = $worksheet->get_cell($row,4)->value();
        }
        my $vehicle_battery = 'default_battery';
        if ($worksheet->get_cell($row,5)) {
            $vehicle_battery = $worksheet->get_cell($row,5)->value();
        }
        my $sensor;
        if ($worksheet->get_cell($row,6)) {
            $sensor = $worksheet->get_cell($row,6)->value();
        }
        my $field_trial_name;
        if ($worksheet->get_cell($row,7)) {
            $field_trial_name = $worksheet->get_cell($row,7)->value();
        }
        my $image_filenames;
        if ($worksheet->get_cell($row,8)) {
            $image_filenames = $worksheet->get_cell($row,8)->value();
        }
        my $coordinate_system;
        if ($worksheet->get_cell($row,9)) {
            $coordinate_system = $worksheet->get_cell($row,9)->value();
        }
        my $base_date;
        if ($worksheet->get_cell($row,10)) {
            $base_date = $worksheet->get_cell($row,10)->value();
        }
        my $rig_desc;
        if ($worksheet->get_cell($row,11)) {
            $rig_desc = $worksheet->get_cell($row,11)->value();
        }

        if (!$imaging_event_name){
            push @parse_csv_errors, "Informe o nome do novo evento de imageamento!";
        }
        if (!$imaging_event_type){
            push @parse_csv_errors, "Informe o tipo do evento de imageamento!";
        }
        if (!$imaging_event_desc){
            push @parse_csv_errors, "Informe a descrição do evento de imageamento!";
        }
        if (!$imaging_event_date){
            push @parse_csv_errors, "Informe a data do evento de imageamento!";
        }
        if (!$vehicle_name){
            push @parse_csv_errors, "Informe o nome do veículo!";
        }
        if (!$sensor){
            push @parse_csv_errors, "Informe o nome do sensor!";
        }
        if (!$field_trial_name){
            push @parse_csv_errors, "Informe o nome do ensaio de campo!";
        }

        if ($coordinate_system ne 'UTM' && $coordinate_system ne 'WGS84' && $coordinate_system ne 'Pixels') {
            push @parse_csv_errors, "O sistema de coordenadas informado $coordinate_system não é um destes: UTM, WGS84 ou Pixels!";
        }
        if ($coordinate_system ne 'Pixels') {
            $c->stash->{message} = "No momento, apenas o sistema de coordenadas Pixels é suportado neste envio. No futuro, GeoTIFFs serão suportados, mas por enquanto envie apenas imagens raster simples (.png, .tiff, .jpg).";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }

        my $field_trial_rs = $schema->resultset("Project::Project")->search({name=>$field_trial_name});
        if ($field_trial_rs->count != 1) {
            $c->stash->{message} = "O ensaio de campo $field_trial_name ainda não existe no banco de dados! Adicione-o primeiro.";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        my $field_trial_id = $field_trial_rs->first->project_id();
        $field_trial_ids_seen{$field_trial_id}++;
        $field_trial_name_lookup{$field_trial_name} = $field_trial_id;

        if ($imaging_event_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
            $c->stash->{message} = "Informe a data do novo evento de imageamento no formato YYYY/MM/DD HH:mm:ss! A data informada $imaging_event_date não está correta!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        if ($imaging_event_type ne 'Aerial Medium to High Res' && $imaging_event_type ne 'Aerial Low Res'){
            $c->stash->{message} = "O tipo de evento de imageamento $imaging_event_type não é 'Aerial Low Res' nem 'Aerial Medium to High Res'!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        if (!exists($sensor_map{$sensor})){
            $c->stash->{message} = "O sensor $sensor não é 'MicaSense 5 Channel Camera', 'CCD Color Camera' nem 'CMOS Color Camera'!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }

        my $project_rs = $schema->resultset("Project::Project")->search({name=>$imaging_event_name});
        if ($project_rs->count > 0) {
            push @parse_csv_errors, "Use um nome de evento de imageamento único em todo o sistema! O nome informado $imaging_event_name já foi usado.";
        }
        my $vehicle_prop = $schema->resultset("Stock::Stock")->search({uniquename => $vehicle_name, type_id=>$imaging_vehicle_cvterm_id});
        if ($vehicle_prop->count != 1) {
            push @parse_csv_errors, "O veículo de imageamento $vehicle_name ainda não está no banco de dados! Adicione-o primeiro!";
        }
        else {
            $vehicle_name_lookup{$vehicle_name} = $vehicle_prop->first->stock_id;
        }

        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $field_trial_id });
        my $planting_date = $trial->get_planting_date();
        if (!$planting_date) {
            $c->stash->{message} = "O ensaio de campo $field_trial_name não tem data de plantio definida! Defina-a primeiro!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
        my $imaging_event_date_time_object = Time::Piece->strptime($imaging_event_date, "%Y/%m/%d %H:%M:%S");

        $seen_upload_dates{$imaging_event_name} = {
            date => $imaging_event_date,
            time => $imaging_event_date_time_object->epoch,
            field_trial_name => $field_trial_name,
            field_trial_id => $field_trial_id
        };
        $seen_field_trial_drone_run_dates{$imaging_event_date_time_object->epoch}++;

        if ($imaging_event_date_time_object->epoch - $planting_date_time_object->epoch <= 0) {
            push @parse_csv_errors, "A data do evento de imageamento $imaging_event_date não é posterior à data de plantio do ensaio de campo $planting_date!";
        }
        if ($base_date) {
            if ($base_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
                $c->stash->{message} = "Informe a data-base do novo evento de imageamento no formato YYYY/MM/DD HH:mm:ss! A data informada $base_date não está correta! Deixe em branco se não for relevante!";
                $c->stash->{template} = 'generic_message.mas';
                return;
            }
            my $imaging_event_base_time_object = Time::Piece->strptime($base_date, "%Y/%m/%d %H:%M:%S");

            if ($imaging_event_date_time_object->epoch - $imaging_event_base_time_object->epoch < 0) {
                push @parse_csv_errors, "A data do evento de imageamento $imaging_event_date não é posterior à data-base $base_date!";
            }
        }

        my @orthoimage_names = split ',', $image_filenames;
        foreach (@orthoimage_names) {
            if (!exists($filename_imaging_event_lookup{$_})) {
                push @parse_csv_errors, "O nome de arquivo de ortofoto $_ não existe no arquivo ZIP de ortofotos enviado. Certifique-se de que as ortofotos sejam salvas como a concatenação do nome de arquivo de ortofoto definido na planilha e da banda espectral, com dois sublinhados (__) como separador (ex.: Ortho1_01012020__blue.tiff)";
            }
        }
    }

    # my $seen_field_trial_ids_check = join ',', keys %field_trial_ids_seen;
    # my $drone_run_date_q = "SELECT drone_run_date.value
    #     FROM project AS drone_run_band_project
    #     JOIN project_relationship AS drone_run_band_rel ON (drone_run_band_rel.subject_project_id = drone_run_band_project.project_id AND drone_run_band_rel.type_id = $drone_run_drone_run_band_type_id)
    #     JOIN project AS drone_run_project ON (drone_run_band_rel.object_project_id = drone_run_project.project_id)
    #     JOIN projectprop AS drone_run_date ON(drone_run_project.project_id=drone_run_date.project_id AND drone_run_date.type_id=$project_start_date_type_id)
    #     WHERE drone_run_project.project_id IN ($seen_field_trial_ids_check);";
    # my $drone_run_date_h = $schema->storage->dbh()->prepare($drone_run_date_q);
    # $drone_run_date_h->execute();
    # while( my ($drone_run_date) = $drone_run_date_h->fetchrow_array()) {
    #     my $drone_run_date_formatted = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
    #     if ($drone_run_date_formatted) {
    #         my $date_obj = Time::Piece->strptime($drone_run_date_formatted, "%Y-%B-%d %H:%M:%S");
    #         $seen_field_trial_drone_run_dates{$date_obj->epoch}++;
    #     }
    # }
    #
    # while (my($imaging_event_name,$v) = each %seen_upload_dates) {
    #     my $time = $v->{time};
    #     my $date = $v->{date};
    #     my $field_trial_name = $v->{field_trial_name};
    #     my $field_trial_id = $v->{field_trial_id};
    #     if (exists($seen_field_trial_drone_run_dates{$time})) {
    #         $c->stash->{message} = "An imaging event has already occured on this field trial ($field_trial_name) at the same date and time ($date)! Please give a unique date/time for each imaging event!";
    #         $c->stash->{template} = 'generic_message.mas';
    #         return;
    #     }
    # }

    if (scalar(@parse_csv_errors) > 0) {
        my $error_string = join "<br/>", @parse_csv_errors;
        $c->stash->{message} = $error_string;
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    my @drone_run_project_ids;
    my %drone_run_band_hash;
    for my $row ( 1 .. $row_max ) {
        my $imaging_event_name = $worksheet->get_cell($row,0)->value();
        my $imaging_event_type = $worksheet->get_cell($row,1)->value();
        my $imaging_event_desc = $worksheet->get_cell($row,2)->value();
        my $imaging_event_date = $worksheet->get_cell($row,3)->value();
        my $vehicle_name = $worksheet->get_cell($row,4)->value();
        my $vehicle_battery = $worksheet->get_cell($row,5) ? $worksheet->get_cell($row,5)->value() : 'default_battery';
        my $sensor = $worksheet->get_cell($row,6)->value();
        my $field_trial_name = $worksheet->get_cell($row,7)->value();
        my $image_filenames = $worksheet->get_cell($row,8)->value();
        my $coordinate_system = $worksheet->get_cell($row,9)->value();
        my $base_date = $worksheet->get_cell($row,10) ? $worksheet->get_cell($row,10)->value() : '';
        my $rig_desc = $worksheet->get_cell($row,11) ? $worksheet->get_cell($row,11)->value() : '';

        my $new_drone_run_vehicle_id = $vehicle_name_lookup{$vehicle_name};
        my $selected_trial_id = $field_trial_name_lookup{$field_trial_name};
        my $new_drone_run_camera_info = $sensor_map{$sensor};
        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $selected_trial_id });
        my $trial_location_id = $trial->get_location()->[0];
        my $planting_date = $trial->get_planting_date();
        my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
        my $imaging_event_date_time_object = Time::Piece->strptime($imaging_event_date, "%Y/%m/%d %H:%M:%S");
        my $drone_run_event = $calendar_funcs->check_value_format($imaging_event_date);
        my $time_diff;
        my $base_date_event;
        if ($base_date) {
            my $imaging_event_base_date_time_object = Time::Piece->strptime($base_date, "%Y/%m/%d %H:%M:%S");
            $time_diff = $imaging_event_date_time_object - $imaging_event_base_date_time_object;
            $base_date_event = $calendar_funcs->check_value_format($base_date);
        }
        else {
            $time_diff = $imaging_event_date_time_object - $planting_date_time_object;
        }
        my $time_diff_weeks = $time_diff->weeks;
        my $time_diff_days = $time_diff->days;
        my $time_diff_hours = $time_diff->hours;
        my $rounded_time_diff_weeks = round($time_diff_weeks);
        if ($rounded_time_diff_weeks == 0) {
            $rounded_time_diff_weeks = 1;
        }

        my $week_term_string = "week $rounded_time_diff_weeks";
        my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($week_term_string, 'cxgn_time_ontology');
        my ($week_cvterm_id) = $h->fetchrow_array();

        if (!$week_cvterm_id) {
            my $new_week_term = $schema->resultset("Cv::Cvterm")->create_with({
               name => $week_term_string,
               cv => 'cxgn_time_ontology'
            });
            $week_cvterm_id = $new_week_term->cvterm_id();
        }

        my $day_term_string = "day $time_diff_days";
        $h->execute($day_term_string, 'cxgn_time_ontology');
        my ($day_cvterm_id) = $h->fetchrow_array();

        if (!$day_cvterm_id) {
            my $new_day_term = $schema->resultset("Cv::Cvterm")->create_with({
               name => $day_term_string,
               cv => 'cxgn_time_ontology'
            });
            $day_cvterm_id = $new_day_term->cvterm_id();
        }

        my $week_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $week_cvterm_id, 'extended');
        my $day_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $day_cvterm_id, 'extended');

        my %related_cvterms = (
            week => $week_term,
            day => $day_term
        );

        my $drone_run_projectprops = [
            {type_id => $drone_run_type_cvterm_id, value => $imaging_event_type},
            {type_id => $project_start_date_type_id, value => $drone_run_event},
            {type_id => $design_cvterm_id, value => 'drone_run'},
            {type_id => $drone_run_camera_type_cvterm_id, value => $new_drone_run_camera_info},
            {type_id => $drone_run_related_cvterms_cvterm_id, value => encode_json \%related_cvterms}
        ];
        if ($base_date) {
            push @$drone_run_projectprops, {type_id => $drone_run_base_date_type_id, value => $base_date_event};
        }
        if ($rig_desc) {
            push @$drone_run_projectprops, {type_id => $drone_run_rig_desc_type_id, value => $rig_desc};
        }

        my $nd_experiment_rs = $schema->resultset("NaturalDiversity::NdExperiment")->create({
            nd_geolocation_id => $trial_location_id,
            type_id => $drone_run_experiment_type_id,
            nd_experiment_stocks => [{stock_id => $new_drone_run_vehicle_id, type_id => $drone_run_experiment_type_id}]
        });
        my $drone_run_nd_experiment_id = $nd_experiment_rs->nd_experiment_id();

        my $project_rs = $schema->resultset("Project::Project")->create({
            name => $imaging_event_name,
            description => $imaging_event_desc,
            projectprops => $drone_run_projectprops,
            project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_trial_id}],
            nd_experiment_projects => [{nd_experiment_id => $drone_run_nd_experiment_id}]
        });
        my $selected_drone_run_id = $project_rs->project_id();
        push @drone_run_project_ids, $selected_drone_run_id;

        my $vehicle_prop = decode_json $schema->resultset("Stock::Stockprop")->search({stock_id => $new_drone_run_vehicle_id, type_id=>$imaging_vehicle_properties_cvterm_id})->first()->value();
        $vehicle_prop->{batteries}->{$vehicle_battery}->{usage}++;
        my $vehicle_prop_update = $schema->resultset('Stock::Stockprop')->update_or_create({
            type_id=>$imaging_vehicle_properties_cvterm_id,
            stock_id=>$new_drone_run_vehicle_id,
            rank=>0,
            value=>encode_json $vehicle_prop
        },
        {
            key=>'stockprop_c1'
        });

        my @orthoimage_names = split ',', $image_filenames;
        my @ortho_images;
        foreach (@orthoimage_names) {
            push @ortho_images, $filename_imaging_event_lookup{$_};
        }
        foreach my $m (@ortho_images) {
            my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
            my $band = $m->{band};
            my $band_short = $m->{band_short};
            my $file = $m->{file};
            my $project_rs = $schema->resultset("Project::Project")->create({
                name => $imaging_event_name."_".$band_short,
                description => $imaging_event_desc.". ".$band,
                projectprops => [
                    {type_id => $drone_run_band_type_cvterm_id, value => $band},
                    {type_id => $design_cvterm_id, value => 'drone_run_band'},
                    {type_id => $geoparam_coordinates_type_cvterm_id, value => $coordinate_system}
                ],
                project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_drone_run_id}]
            });
            my $selected_drone_run_band_id = $project_rs->project_id();

            my $time = DateTime->now();
            my $timestamp = $time->ymd()."_".$time->hms();
            my $upload_original_name = $imaging_event_name."_".$band_short.".png";

            my $uploader = CXGN::UploadFile->new({
                tempfile => $file,
                subdirectory => "drone_imagery_upload",
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role
            });
            my $archived_filename_with_path = $uploader->archive();
            my $md5 = $uploader->get_md5($archived_filename_with_path);
            if (!$archived_filename_with_path) {
                $c->stash->{rest} = { error => "Não foi possível salvar o arquivo $upload_original_name no arquivo permanente." };
                $c->detach();
            }
            unlink $upload_tempfile;
            print STDERR "Archived Bulk Orthophoto File: $archived_filename_with_path\n";

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            $image->set_sp_person_id($user_id);
            my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
            my $ret = $image->process_image($archived_filename_with_path, 'project', $selected_drone_run_band_id, $linking_table_type_id);

            push @{$drone_run_band_hash{$selected_drone_run_id}}, {
                drone_run_band_project_id => $selected_drone_run_band_id,
                band => $band
            };
        }
    }

    $c->stash->{message} = "Enviado com sucesso! Acesse <a href='/breeders/drone_imagery'>Imagens de drone</a>";
    $c->stash->{template} = 'generic_message.mas';
    return;
}

sub upload_drone_imagery_bulk_previous : Path("/drone_imagery/upload_drone_imagery_bulk_previous") :Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    print STDERR Dumper $c->req->params();

    my $imaging_vehicle_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle', 'stock_type')->cvterm_id();
    my $imaging_vehicle_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle_json', 'stock_property')->cvterm_id();
    my $drone_run_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_experiment', 'experiment_type')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $geoparam_coordinates_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_geoparam_coordinates_type', 'project_property')->cvterm_id();
    my $geoparam_coordinates_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_geoparam_coordinates', 'project_property')->cvterm_id();
    my $drone_run_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_is_raw_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_is_raw_images', 'project_property')->cvterm_id();
    my $drone_run_camera_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();
    my $drone_run_base_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_base_date', 'project_property')->cvterm_id();
    my $drone_run_rig_desc_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_rig_description', 'project_property')->cvterm_id();
    my $drone_run_related_cvterms_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_related_time_cvterms_json', 'project_property')->cvterm_id();
    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
    my $processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_completed', 'project_property')->cvterm_id();
    my $processed_minimal_vi_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_vi_completed', 'project_property')->cvterm_id();
    my $drone_run_band_type_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $rotate_angle_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_rotate_angle', 'project_property')->cvterm_id();
    my $cropping_polygon_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
    my $plot_polygon_template_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $calendar_funcs = CXGN::Calendar->new({});

    my %seen_field_trial_drone_run_dates;
    my $drone_run_date_q = "SELECT drone_run_date.value
        FROM project AS drone_run_band_project
        JOIN project_relationship AS drone_run_band_rel ON (drone_run_band_rel.subject_project_id = drone_run_band_project.project_id AND drone_run_band_rel.type_id = $drone_run_drone_run_band_type_id)
        JOIN project AS drone_run_project ON (drone_run_band_rel.object_project_id = drone_run_project.project_id)
        JOIN projectprop AS drone_run_date ON(drone_run_project.project_id=drone_run_date.project_id AND drone_run_date.type_id=$project_start_date_type_id);";
    my $drone_run_date_h = $schema->storage->dbh()->prepare($drone_run_date_q);
    $drone_run_date_h->execute();
    while( my ($drone_run_date) = $drone_run_date_h->fetchrow_array()) {
        my $drone_run_date_formatted = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
        if ($drone_run_date_formatted) {
            my $date_obj = Time::Piece->strptime($drone_run_date_formatted, "%Y-%B-%d %H:%M:%S");
            $seen_field_trial_drone_run_dates{$date_obj->epoch}++;
        }
    }

    my %spectral_lookup = (
        blue => "Blue (450-520nm)",
        green => "Green (515-600nm)",
        red => "Red (600-690nm)",
        rededge => "Red Edge (690-750nm)",
        nir => "NIR (780-3000nm)",
        mir => "MIR (3000-50000nm)",
        fir => "FIR (50000-1000000nm)",
        thir => "Thermal IR (9000-14000nm)",
        rgb => "RGB Color Image",
        bw => "Black and White Image"
    );

    my %sensor_map = (
        "MicaSense 5 Channel Camera" => "micasense_5",
        "CCD Color Camera" => "ccd_color",
        "CMOS Color Camera" => "cmos_color"
    );

    my $upload_file = $c->req->upload('upload_drone_imagery_bulk_images_zipfile_previous');
    my $upload_geojson_file = $c->req->upload('upload_drone_imagery_bulk_geojson_zipfile_previous');
    my $imaging_events_file = $c->req->upload('upload_drone_imagery_bulk_imaging_events_previous');

    my $upload_original_name = $upload_file->filename();
    my $upload_tempfile = $upload_file->tempname;
    my $upload_geojson_original_name = $upload_geojson_file->filename();
    my $upload_geojson_tempfile = $upload_geojson_file->tempname;
    my $upload_imaging_events_file = $imaging_events_file->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => "drone_imagery_upload_bulk_previous_orthophoto_zips",
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = { error => "Não foi possível salvar o arquivo $upload_original_name no arquivo permanente." };
        $c->detach();
    }
    unlink $upload_tempfile;
    print STDERR "Archived Drone Image Bulk Previous Orthophoto Zip File: $archived_filename_with_path\n";

    my $archived_zip = CXGN::ZipFile->new(archived_zipfile_path=>$archived_filename_with_path);
    my $file_members = $archived_zip->file_members();
    if (!$file_members){
        $c->stash->{message} = 'Não foi possível ler o arquivo ZIP de ortofotos em lote. Ele está no formato .zip';
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    my %filename_imaging_event_lookup;
    my %filename_imaging_event_band_check;
    foreach (@$file_members) {
        my $image = SGN::Image->new( $dbh, undef, $c );
        my $filename = $_->fileName();
        my @zipfile_comp = split '\/', $filename;
        my $filename_wext;
        if (scalar(@zipfile_comp)==1) {
            $filename_wext = $zipfile_comp[0];
        }
        else {
            $filename_wext = $zipfile_comp[1];
        }
        my @filename_comps = split '\.', $filename_wext;
        my $filename_only = $filename_comps[0];
        my @image_spectra = split '\_\_', $filename_only;
        my $temp_file = $image->upload_zipfile_images($_);
        my $imaging_event_name = $image_spectra[0];
        my $band = $image_spectra[1];

        if (!exists($spectral_lookup{$band})) {
            $c->stash->{message} = "A banda espectral $band não é permitida na ortofoto informada $filename. Certifique-se de que as ortofotos sejam salvas como uma concatenação com a banda espectral, com dois sublinhados (__) como separador (ex.: Ortho1_01012020__blue.tiff); as bandas espectrais permitidas são blue,green,red,rededge,nir,mir,fir,thir,rgb,bw.";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        my $spectral_band = $spectral_lookup{$band};
        print STDERR Dumper [$filename_wext, $filename, $temp_file, $imaging_event_name, $spectral_band];
        $filename_imaging_event_lookup{$filename_wext} = {
            file => $temp_file,
            band => $spectral_band,
            band_short => $band
        };
        if (exists($filename_imaging_event_band_check{$imaging_event_name}->{$spectral_band})) {
            $c->stash->{message} = "Não envie tipos espectrais duplicados para o mesmo evento de imageamento. Já existe uma imagem $band para $imaging_event_name no arquivo ZIP! Certifique-se de que as ortofotos sejam salvas como a concatenação do nome do evento de imageamento e da banda espectral, com dois sublinhados (__) como separador (ex.: Ortho1_01012020__blue.tiff)";
            $c->stash->{template} = 'generic_message.mas';
            return;
        } else {
            $filename_imaging_event_band_check{$imaging_event_name}->{$spectral_band}++;
        }
    }

    my $uploader_geojson = CXGN::UploadFile->new({
        tempfile => $upload_geojson_tempfile,
        subdirectory => "drone_imagery_upload_bulk_previous_geojson_zips",
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_geojson_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $geojson_archived_filename_with_path = $uploader_geojson->archive();
    my $md5_geojson = $uploader_geojson->get_md5($geojson_archived_filename_with_path);
    if (!$geojson_archived_filename_with_path) {
        $c->stash->{message} = "Não foi possível salvar o arquivo $upload_geojson_original_name no arquivo permanente.";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }
    unlink $upload_geojson_tempfile;
    print STDERR "Archived Drone Image Bulk Previous GeoJSON Zip File: $geojson_archived_filename_with_path\n";

    my $archived_zip_geojson = CXGN::ZipFile->new(archived_zipfile_path=>$geojson_archived_filename_with_path);
    my $file_members_geojson = $archived_zip_geojson->file_members();
    if (!$file_members_geojson){
        $c->stash->{message} = 'Não foi possível ler o arquivo ZIP de GeoJSON em lote. Ele está no formato .zip?';
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    my %filename_imaging_event_geojson_lookup;
    foreach (@$file_members_geojson) {
        my $image = SGN::Image->new( $dbh, undef, $c );
        my $filename = $_->fileName();
        my $temp_file = $image->upload_zipfile_images($_);

        my @zipfile_comp = split '\/', $filename;
        my $filename_wext;
        if (scalar(@zipfile_comp) == 1) {
            $filename_wext = $zipfile_comp[0];
        }
        else {
            $filename_wext = $zipfile_comp[1];
        }

        print STDERR Dumper [$filename, $temp_file, $filename_wext];
        $filename_imaging_event_geojson_lookup{$filename_wext} = $temp_file;

        open(my $fh_geojson_check, '<', $temp_file) or die "Could not open file '$temp_file' $!";
            print STDERR "Opened $temp_file\n";
            my $geojson_value_check = decode_json <$fh_geojson_check>;
            # print STDERR Dumper $geojson_value_check;
            if (!$geojson_value_check->{features}) {
                $c->stash->{message} = 'O arquivo GeoJSON '.$filename.' não tem a chave \'features\'. Verifique se o GeoJSON está formatado corretamente.';
                $c->stash->{template} = 'generic_message.mas';
                return;
            }
            foreach (@{$geojson_value_check->{features}}) {
                if (!$_->{properties}) {
                    $c->stash->{message} = 'O arquivo GeoJSON '.$filename.' não tem a chave \'properties\'. Verifique se o GeoJSON está formatado corretamente.';
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
                if (!$_->{properties}->{ID}) {
                    $c->stash->{message} = 'O arquivo GeoJSON '.$filename.' não tem a chave \'ID\' no objeto \'properties\'. Verifique se o GeoJSON está formatado corretamente.';
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
                if (!$_->{geometry}) {
                    $c->stash->{message} = 'O arquivo GeoJSON '.$filename.' não tem a chave \'geometry\'. Verifique se o GeoJSON está formatado corretamente.';
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
                if (!$_->{geometry}->{coordinates}) {
                    $c->stash->{message} = 'O arquivo GeoJSON '.$filename.' não tem a chave \'coordinates\' no objeto \'geometry\'. Verifique se o GeoJSON está formatado corretamente.';
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
                if (scalar(@{$_->{geometry}->{coordinates}->[0]}) != 5) {
                    $c->stash->{message} = 'O arquivo GeoJSON '.$filename.': o primeiro objeto de \'coordinates\' não tem 5 objetos. Os polígonos devem ser retangulares. Verifique se o GeoJSON está formatado corretamente.';
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
            }
        close($fh_geojson_check);
    }

    my @parse_csv_errors;
    my %field_trial_name_lookup;
    my %field_trial_layout_lookup;
    my %vehicle_name_lookup;

    my $parser = Spreadsheet::ParseExcel->new();
    my $excel_obj = $parser->parse($upload_imaging_events_file);
    if (!$excel_obj) {
        $c->stash->{message} = 'Não foi possível abrir o arquivo Excel (.xls):'.$parser->error();
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    if (!$worksheet) {
        $c->stash->{message} = 'A planilha deve estar na 1ª aba do arquivo Excel (.xls).';
        $c->stash->{template} = 'generic_message.mas';
        return;
    }
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
        $c->stash->{message} = 'A planilha (.xls) não tem cabeçalho ou não contém nenhuma linha.';
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    if ($worksheet->get_cell(0,0)->value() ne 'Imaging Event Name' ||
        $worksheet->get_cell(0,1)->value() ne 'Type' ||
        $worksheet->get_cell(0,2)->value() ne 'Description' ||
        $worksheet->get_cell(0,3)->value() ne 'Date' ||
        $worksheet->get_cell(0,4)->value() ne 'Vehicle Name' ||
        $worksheet->get_cell(0,5)->value() ne 'Vehicle Battery Set' ||
        $worksheet->get_cell(0,6)->value() ne 'Sensor' ||
        $worksheet->get_cell(0,7)->value() ne 'Field Trial Name' ||
        $worksheet->get_cell(0,8)->value() ne 'GeoJSON Filename' ||
        $worksheet->get_cell(0,9)->value() ne 'Image Filenames' ||
        $worksheet->get_cell(0,10)->value() ne 'Coordinate System' ||
        $worksheet->get_cell(0,11)->value() ne 'Rotation Angle' ||
        $worksheet->get_cell(0,12)->value() ne 'Base Date' ||
        $worksheet->get_cell(0,13)->value() ne 'Camera Rig') {
            $c->stash->{message} = "A linha de cabeçalho da planilha CSV deve ser 'Imaging Event Name,Type,Description,Date,Vehicle Name,Vehicle Battery Set,Sensor,Field Trial Name,GeoJSON Filename,Image Filenames,Coordinate System,Rotation Angle,Base Date,Camera Rig'.";
            $c->stash->{template} = 'generic_message.mas';
            return;
    }

    my %seen_upload_dates;
    for my $row ( 1 .. $row_max ) {
        my $imaging_event_name;
        if ($worksheet->get_cell($row,0)) {
            $imaging_event_name = $worksheet->get_cell($row,0)->value();
        }
        my $imaging_event_type;
        if ($worksheet->get_cell($row,1)) {
            $imaging_event_type = $worksheet->get_cell($row,1)->value();
        }
        my $imaging_event_desc;
        if ($worksheet->get_cell($row,2)) {
            $imaging_event_desc = $worksheet->get_cell($row,2)->value();
        }
        my $imaging_event_date;
        if ($worksheet->get_cell($row,3)) {
            $imaging_event_date = $worksheet->get_cell($row,3)->value();
        }
        my $vehicle_name;
        if ($worksheet->get_cell($row,4)) {
            $vehicle_name = $worksheet->get_cell($row,4)->value();
        }
        my $vehicle_battery = 'default_battery';
        if ($worksheet->get_cell($row,5)) {
            $vehicle_battery = $worksheet->get_cell($row,5)->value();
        }
        my $sensor;
        if ($worksheet->get_cell($row,6)) {
            $sensor = $worksheet->get_cell($row,6)->value();
        }
        my $field_trial_name;
        if ($worksheet->get_cell($row,7)) {
            $field_trial_name = $worksheet->get_cell($row,7)->value();
        }
        my $geojson_filename;
        if ($worksheet->get_cell($row,8)) {
            $geojson_filename = $worksheet->get_cell($row,8)->value();
        }
        my $image_filenames;
        if ($worksheet->get_cell($row,9)) {
            $image_filenames = $worksheet->get_cell($row,9)->value();
        }
        my $coordinate_system;
        if ($worksheet->get_cell($row,10)) {
            $coordinate_system = $worksheet->get_cell($row,10)->value();
        }
        my $rotation_angle;
        if ($worksheet->get_cell($row,11)) {
            $rotation_angle = $worksheet->get_cell($row,11)->value();
        }
        my $base_date;
        if ($worksheet->get_cell($row,12)) {
            $base_date = $worksheet->get_cell($row,12)->value();
        }
        my $rig_desc;
        if ($worksheet->get_cell($row,13)) {
            $rig_desc = $worksheet->get_cell($row,13)->value();
        }

        if (!$imaging_event_name){
            push @parse_csv_errors, "Informe o nome do novo evento de imageamento!";
        }
        if (!$imaging_event_type){
            push @parse_csv_errors, "Informe o tipo do evento de imageamento!";
        }
        if (!$imaging_event_desc){
            push @parse_csv_errors, "Informe a descrição do evento de imageamento!";
        }
        if (!$imaging_event_date){
            push @parse_csv_errors, "Informe a data do evento de imageamento!";
        }
        if (!$vehicle_name){
            push @parse_csv_errors, "Informe o nome do veículo!";
        }
        if (!$sensor){
            push @parse_csv_errors, "Informe o nome do sensor!";
        }
        if (!$field_trial_name){
            push @parse_csv_errors, "Informe o nome do ensaio de campo!";
        }
        if (defined($rotation_angle) && ($rotation_angle < 0 || $rotation_angle > 360) ) {
            push @parse_csv_errors, "Ângulo de rotação $rotation_angle inválido! Deve estar entre 0 e 360, no sentido horário!";
        }

        if ($coordinate_system ne 'UTM' && $coordinate_system ne 'WGS84' && $coordinate_system ne 'Pixels') {
            push @parse_csv_errors, "O sistema de coordenadas informado $coordinate_system não é um destes: UTM, WGS84 ou Pixels!";
        }
        # if ($coordinate_system ne 'Pixels') {
        #     $c->stash->{rest} = {error => "Only the Pixels coordinate system is currently supported. In the future GeoTIFFs will be supported, but for now please only upload simple raster images (.png, .tiff, .jpg)." };
        #     $c->detach;
        # }

        my $field_trial_rs = $schema->resultset("Project::Project")->search({name=>$field_trial_name});
        if ($field_trial_rs->count != 1) {
            $c->stash->{message} = "O ensaio de campo $field_trial_name ainda não existe no banco de dados! Adicione-o primeiro.";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        my $field_trial_id = $field_trial_rs->first->project_id();
        $field_trial_name_lookup{$field_trial_name} = $field_trial_id;

        if ($imaging_event_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
            $c->stash->{message} = "Informe a data do novo evento de imageamento no formato YYYY/MM/DD HH:mm:ss! A data informada $imaging_event_date não está correta!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        if ($imaging_event_type ne 'Aerial Medium to High Res' && $imaging_event_type ne 'Aerial Low Res'){
            $c->stash->{message} = "O tipo de evento de imageamento $imaging_event_type não é 'Aerial Low Res' nem 'Aerial Medium to High Res'!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        if (!exists($sensor_map{$sensor})){
            $c->stash->{message} = "O sensor $sensor não é 'MicaSense 5 Channel Camera', 'CCD Color Camera' nem 'CMOS Color Camera'!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }

        my $project_rs = $schema->resultset("Project::Project")->search({name=>$imaging_event_name});
        if ($project_rs->count > 0) {
            push @parse_csv_errors, "Use um nome de evento de imageamento único em todo o sistema! O nome informado $imaging_event_name já foi usado.";
        }
        my $vehicle_prop = $schema->resultset("Stock::Stock")->search({uniquename => $vehicle_name, type_id=>$imaging_vehicle_cvterm_id});
        if ($vehicle_prop->count != 1) {
            push @parse_csv_errors, "O veículo de imageamento $vehicle_name ainda não está no banco de dados! Adicione-o primeiro!";
        }
        else {
            $vehicle_name_lookup{$vehicle_name} = $vehicle_prop->first->stock_id;
        }

        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $field_trial_id });
        my $trial_layout = $trial->get_layout()->get_design();
        $field_trial_layout_lookup{$field_trial_id} = $trial_layout;

        my $planting_date = $trial->get_planting_date();
        if (!$planting_date) {
            $c->stash->{message} = "O ensaio de campo $field_trial_name não tem data de plantio definida! Defina-a primeiro!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
        my $imaging_event_date_time_object = Time::Piece->strptime($imaging_event_date, "%Y/%m/%d %H:%M:%S");

        if (exists($seen_field_trial_drone_run_dates{$imaging_event_date_time_object->epoch})) {
            $c->stash->{message} = "Já existe um evento de imageamento neste ensaio de campo na mesma data e hora ($imaging_event_date)! Informe uma data/hora única para cada evento de imageamento!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        $seen_field_trial_drone_run_dates{$imaging_event_date_time_object->epoch}++;

        if ($imaging_event_date_time_object->epoch - $planting_date_time_object->epoch <= 0) {
            push @parse_csv_errors, "A data do evento de imageamento $imaging_event_date não é posterior à data de plantio do ensaio de campo $planting_date!";
        }
        if ($base_date) {
            if ($base_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
                $c->stash->{message} = "Informe a data-base do novo evento de imageamento no formato YYYY/MM/DD HH:mm:ss! A data informada $base_date não está correta! Deixe em branco se não for relevante!";
                $c->stash->{template} = 'generic_message.mas';
                return;
            }
            my $imaging_event_base_time_object = Time::Piece->strptime($base_date, "%Y/%m/%d %H:%M:%S");

            if ($imaging_event_date_time_object->epoch - $imaging_event_base_time_object->epoch < 0) {
                push @parse_csv_errors, "A data do evento de imageamento $imaging_event_date não é posterior à data-base $base_date!";
            }
        }

        my @orthoimage_names = split ',', $image_filenames;
        foreach (@orthoimage_names) {
            if (!exists($filename_imaging_event_lookup{$_})) {
                push @parse_csv_errors, "O nome de arquivo de ortofoto $_ não existe no arquivo ZIP de ortofotos enviado. Certifique-se de que as ortofotos sejam salvas como a concatenação do nome de arquivo de ortofoto definido na planilha e da banda espectral, com dois sublinhados (__) como separador (ex.: Ortho1_01012020__blue.tiff)";
            }
        }
        if (!exists($filename_imaging_event_geojson_lookup{$geojson_filename})) {
            push @parse_csv_errors, "O arquivo GeoJSON $geojson_filename não existe no arquivo ZIP de GeoJSON enviado!";
        }
        open(my $fh_geojson_check, '<', $filename_imaging_event_geojson_lookup{$geojson_filename}) or die "Could not open file '".$filename_imaging_event_geojson_lookup{$geojson_filename}."' $!";
            print STDERR "Opened ".$filename_imaging_event_geojson_lookup{$geojson_filename}."\n";
            my $geojson_value_check = decode_json <$fh_geojson_check>;
            foreach (@{$geojson_value_check->{features}}) {
                my $plot_number = $_->{properties}->{ID};
                if (!exists($trial_layout->{$plot_number})) {
                    push @parse_csv_errors, "O ID $plot_number no arquivo GeoJSON $geojson_filename não existe no ensaio de campo $field_trial_name!";
                }
            }
        close($fh_geojson_check);
    }

    if (scalar(@parse_csv_errors) > 0) {
        my $error_string = join "<br/>", @parse_csv_errors;
        $c->stash->{message} = $error_string;
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    my $dir = $c->tempfiles_subdir('/upload_drone_imagery_bulk_previous');

    my @drone_run_project_ids;
    my @drone_run_projects;
    my %drone_run_project_info;
    for my $row ( 1 .. $row_max ) {
        my $imaging_event_name = $worksheet->get_cell($row,0)->value();
        my $imaging_event_type = $worksheet->get_cell($row,1)->value();
        my $imaging_event_desc = $worksheet->get_cell($row,2)->value();
        my $imaging_event_date = $worksheet->get_cell($row,3)->value();
        my $vehicle_name = $worksheet->get_cell($row,4)->value();
        my $vehicle_battery = $worksheet->get_cell($row,5) ? $worksheet->get_cell($row,5)->value() : 'default_battery';
        my $sensor = $worksheet->get_cell($row,6)->value();
        my $field_trial_name = $worksheet->get_cell($row,7)->value();
        my $geojson_filename = $worksheet->get_cell($row,8)->value();
        my $image_filenames = $worksheet->get_cell($row,9)->value();
        my $coordinate_system = $worksheet->get_cell($row,10)->value();
        my $rotation_angle = $worksheet->get_cell($row,11) ? $worksheet->get_cell($row,11)->value() : 0;
        my $base_date = $worksheet->get_cell($row,12) ? $worksheet->get_cell($row,12)->value() : '';
        my $rig_desc = $worksheet->get_cell($row,13) ? $worksheet->get_cell($row,13)->value() : '';

        my $new_drone_run_vehicle_id = $vehicle_name_lookup{$vehicle_name};
        my $selected_trial_id = $field_trial_name_lookup{$field_trial_name};
        my $new_drone_run_camera_info = $sensor_map{$sensor};
        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $selected_trial_id });
        my $trial_location_id = $trial->get_location()->[0];
        my $planting_date = $trial->get_planting_date();
        my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
        my $imaging_event_date_time_object = Time::Piece->strptime($imaging_event_date, "%Y/%m/%d %H:%M:%S");
        my $drone_run_event = $calendar_funcs->check_value_format($imaging_event_date);
        my $time_diff;
        my $base_date_event;
        if ($base_date) {
            my $imaging_event_base_date_time_object = Time::Piece->strptime($base_date, "%Y/%m/%d %H:%M:%S");
            $time_diff = $imaging_event_date_time_object - $imaging_event_base_date_time_object;
            $base_date_event = $calendar_funcs->check_value_format($base_date);
        }
        else {
            $time_diff = $imaging_event_date_time_object - $planting_date_time_object;
        }
        my $time_diff_weeks = $time_diff->weeks;
        my $time_diff_days = $time_diff->days;
        my $time_diff_hours = $time_diff->hours;
        my $rounded_time_diff_weeks = round($time_diff_weeks);
        if ($rounded_time_diff_weeks == 0) {
            $rounded_time_diff_weeks = 1;
        }

        my $week_term_string = "week $rounded_time_diff_weeks";
        my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($week_term_string, 'cxgn_time_ontology');
        my ($week_cvterm_id) = $h->fetchrow_array();

        if (!$week_cvterm_id) {
            my $new_week_term = $schema->resultset("Cv::Cvterm")->create_with({
               name => $week_term_string,
               cv => 'cxgn_time_ontology'
            });
            $week_cvterm_id = $new_week_term->cvterm_id();
        }

        my $day_term_string = "day $time_diff_days";
        $h->execute($day_term_string, 'cxgn_time_ontology');
        my ($day_cvterm_id) = $h->fetchrow_array();

        if (!$day_cvterm_id) {
            my $new_day_term = $schema->resultset("Cv::Cvterm")->create_with({
               name => $day_term_string,
               cv => 'cxgn_time_ontology'
            });
            $day_cvterm_id = $new_day_term->cvterm_id();
        }

        my $week_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $week_cvterm_id, 'extended');
        my $day_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $day_cvterm_id, 'extended');

        my %related_cvterms = (
            week => $week_term,
            day => $day_term
        );

        my $drone_run_projectprops = [
            {type_id => $drone_run_type_cvterm_id, value => $imaging_event_type},
            {type_id => $project_start_date_type_id, value => $drone_run_event},
            {type_id => $design_cvterm_id, value => 'drone_run'},
            {type_id => $drone_run_camera_type_cvterm_id, value => $new_drone_run_camera_info},
            {type_id => $drone_run_related_cvterms_cvterm_id, value => encode_json \%related_cvterms}
        ];
        if ($base_date) {
            push @$drone_run_projectprops, {type_id => $drone_run_base_date_type_id, value => $base_date_event};
        }
        if ($rig_desc) {
            push @$drone_run_projectprops, {type_id => $drone_run_rig_desc_type_id, value => $rig_desc};
        }

        my $nd_experiment_rs = $schema->resultset("NaturalDiversity::NdExperiment")->create({
            nd_geolocation_id => $trial_location_id,
            type_id => $drone_run_experiment_type_id,
            nd_experiment_stocks => [{stock_id => $new_drone_run_vehicle_id, type_id => $drone_run_experiment_type_id}]
        });
        my $drone_run_nd_experiment_id = $nd_experiment_rs->nd_experiment_id();

        my $project_rs = $schema->resultset("Project::Project")->create({
            name => $imaging_event_name,
            description => $imaging_event_desc,
            projectprops => $drone_run_projectprops,
            project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_trial_id}],
            nd_experiment_projects => [{nd_experiment_id => $drone_run_nd_experiment_id}]
        });
        my $selected_drone_run_id = $project_rs->project_id();
        push @drone_run_project_ids, $selected_drone_run_id;

        my $vehicle_prop = decode_json $schema->resultset("Stock::Stockprop")->search({stock_id => $new_drone_run_vehicle_id, type_id=>$imaging_vehicle_properties_cvterm_id})->first()->value();
        $vehicle_prop->{batteries}->{$vehicle_battery}->{usage}++;
        my $vehicle_prop_update = $schema->resultset('Stock::Stockprop')->update_or_create({
            type_id=>$imaging_vehicle_properties_cvterm_id,
            stock_id=>$new_drone_run_vehicle_id,
            rank=>0,
            value=>encode_json $vehicle_prop
        },
        {
            key=>'stockprop_c1'
        });

        my @orthoimage_names = split ',', $image_filenames;
        my @ortho_images;
        foreach (@orthoimage_names) {
            push @ortho_images, $filename_imaging_event_lookup{$_};
        }
        my @drone_run_band_projects;
        my @drone_run_band_project_ids;
        my @drone_run_band_geoparams_coordinates;
        foreach my $m (@ortho_images) {
            my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
            my $band = $m->{band};
            my $band_short = $m->{band_short};
            my $file = $m->{file};

            my $time = DateTime->now();
            my $timestamp = $time->ymd()."_".$time->hms();
            my $upload_original_name = $imaging_event_name."_".$band_short.".png";

            my $ortho_file;
            my @geoparams_coordinates;
            if ($coordinate_system eq 'Pixels') {
                $ortho_file = $file;
            }
            else {
                if ($band_short eq 'rgb') {
                    my $outfile_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_image_r = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_image_g = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_image_b = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_geoparams = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/fileXXXX').".csv";

                    my $geo_cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/GDALOpenImageRGBGeoTiff.py --image_path $file --outfile_path_image $outfile_image --outfile_path_image_1 $outfile_image_r --outfile_path_image_2 $outfile_image_g --outfile_path_image_3 $outfile_image_b --outfile_path_geo_params $outfile_geoparams ";
                    print STDERR $geo_cmd."\n";
                    my $geo_cmd_status = system($geo_cmd);
                    $ortho_file = $outfile_image;

                    open(my $fh_geoparams, '<', $outfile_geoparams) or die "Could not open file '".$outfile_geoparams."' $!";
                        print STDERR "Opened ".$outfile_geoparams."\n";
                        my $geoparams = <$fh_geoparams>;
                        chomp $geoparams;
                        @geoparams_coordinates = split ',', $geoparams;
                        print STDERR Dumper [$geoparams, \@geoparams_coordinates];
                    close($fh_geoparams);
                }
                else {
                    my $outfile_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_geoparams = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/fileXXXX').".csv";

                    my $geo_cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/GDALOpenSingleChannelImageGeoTiff.py --image_path $file --outfile_path_image $outfile_image --outfile_path_geo_params $outfile_geoparams ";
                    print STDERR $geo_cmd."\n";
                    my $geo_cmd_status = system($geo_cmd);
                    $ortho_file = $outfile_image;

                    open(my $fh_geoparams, '<', $outfile_geoparams) or die "Could not open file '".$outfile_geoparams."' $!";
                        print STDERR "Opened ".$outfile_geoparams."\n";
                        my $geoparams = <$fh_geoparams>;
                        chomp $geoparams;
                        @geoparams_coordinates = split ',', $geoparams;
                        print STDERR Dumper [$geoparams, \@geoparams_coordinates];
                    close($fh_geoparams);
                }
            }
            push @drone_run_band_geoparams_coordinates, \@geoparams_coordinates;

            my $project_rs = $schema->resultset("Project::Project")->create({
                name => $imaging_event_name."_".$band_short,
                description => $imaging_event_desc.". ".$band,
                projectprops => [
                    {type_id => $drone_run_band_type_cvterm_id, value => $band},
                    {type_id => $design_cvterm_id, value => 'drone_run_band'},
                    {type_id => $geoparam_coordinates_type_cvterm_id, value => $coordinate_system},
                    {type_id => $geoparam_coordinates_cvterm_id, value => encode_json \@geoparams_coordinates}
                ],
                project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_drone_run_id}]
            });
            my $selected_drone_run_band_id = $project_rs->project_id();

            my $uploader = CXGN::UploadFile->new({
                tempfile => $ortho_file,
                subdirectory => "drone_imagery_upload",
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role
            });
            my $archived_filename_with_path = $uploader->archive();
            my $md5 = $uploader->get_md5($archived_filename_with_path);
            if (!$archived_filename_with_path) {
                $c->stash->{rest} = { error => "Não foi possível salvar o arquivo $upload_original_name no arquivo permanente." };
                $c->detach();
            }
            unlink $upload_tempfile;
            print STDERR "Archived Bulk Orthophoto File: $archived_filename_with_path\n";

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            $image->set_sp_person_id($user_id);
            my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
            my $ret = $image->process_image($archived_filename_with_path, 'project', $selected_drone_run_band_id, $linking_table_type_id);

            push @drone_run_band_projects, {
                drone_run_band_project_id => $selected_drone_run_band_id,
                band => $band
            };
            push @drone_run_band_project_ids, $selected_drone_run_band_id;
        }

        my $geojson_temp_filename = $filename_imaging_event_geojson_lookup{$geojson_filename};
        push @drone_run_projects, {
            drone_run_project_id => $selected_drone_run_id,
            drone_run_band_projects => \@drone_run_band_projects,
            drone_run_band_project_ids => \@drone_run_band_project_ids,
            geojson_temp_filename => $geojson_temp_filename,
            time_cvterm_id => $day_cvterm_id,
            field_trial_id => $selected_trial_id,
            coordinate_system => $coordinate_system,
            drone_run_band_geoparams_coordinates => \@drone_run_band_geoparams_coordinates,
            rotation_angle => $rotation_angle
        };

        $drone_run_project_info{$selected_drone_run_id} = {
            name => $project_rs->name()
        };
    }

    my $vegetative_indices = ['VARI', 'TGI', 'NDRE', 'NDVI'];
    my $phenotype_methods = ['zonal'];
    my $standard_process_type = 'minimal';

    my $rad_conversion = 0.0174533;
    foreach (@drone_run_projects) {
        my $drone_run_project_id_in = $_->{drone_run_project_id};
        my $time_cvterm_id = $_->{time_cvterm_id};
        my $apply_drone_run_band_project_ids = $_->{drone_run_band_project_ids};
        my $geojson_filename = $_->{geojson_temp_filename};
        my $field_trial_id = $_->{field_trial_id};
        my $coordinate_system = $_->{coordinate_system};
        my $drone_run_band_geoparams_coordinates = $_->{drone_run_band_geoparams_coordinates};
        my $rotate_value = $_->{rotation_angle}*-1;
        # my $rotate_value = 0;

        my $drone_run_process_in_progress = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$process_indicator_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>1
        },
        {
            key=>'projectprop_c1'
        });

        my $drone_run_process_completed = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$processed_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>0
        },
        {
            key=>'projectprop_c1'
        });

        my $drone_run_process_minimal_vi_completed = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$processed_minimal_vi_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>0
        },
        {
            key=>'projectprop_c1'
        });

        my %vegetative_indices_hash;
        foreach (@$vegetative_indices) {
            $vegetative_indices_hash{$_}++;
        }

        my $geojson_value;

        open(my $fh_geojson, '<', $geojson_filename) or die "Could not open file '$geojson_filename' $!";
            print STDERR "Opened $geojson_filename\n";
            $geojson_value = decode_json <$fh_geojson>;
        close($fh_geojson);

        my $trial_lookup = $field_trial_layout_lookup{$field_trial_id};

        my %selected_drone_run_band_types;
        my $q2 = "SELECT project_md_image.image_id, drone_run_band_type.value, drone_run_band.project_id
            FROM project AS drone_run_band
            JOIN projectprop AS drone_run_band_type ON(drone_run_band_type.project_id = drone_run_band.project_id AND drone_run_band_type.type_id = $drone_run_band_type_type_id)
            JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id = drone_run_band.project_id)
            JOIN metadata.md_image ON(project_md_image.image_id = metadata.md_image.image_id)
            WHERE project_md_image.type_id = $project_image_type_id
            AND drone_run_band.project_id = ?
            AND metadata.md_image.obsolete = 'f';";

        my $h2 = $schema->storage->dbh()->prepare($q2);

        my $term_map = CXGN::DroneImagery::ImageTypes::get_base_imagery_observation_unit_plot_polygon_term_map();

        my %drone_run_band_info;
        my $drone_run_band_counter = 0;
        foreach my $apply_drone_run_band_project_id (@$apply_drone_run_band_project_ids) {

            my $h2 = $schema->storage->dbh()->prepare($q2);
            $h2->execute($apply_drone_run_band_project_id);
            my ($image_id, $drone_run_band_type, $drone_run_band_project_id) = $h2->fetchrow_array();
            $selected_drone_run_band_types{$drone_run_band_type} = $drone_run_band_project_id;

            my $apply_image_width_ratio = 1;
            my $apply_image_height_ratio = 1;

            my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
            my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
            $archive_rotate_temp_image .= '.png';

            my $rotate_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_image_rotate($c, $schema, $metadata_schema, $drone_run_band_project_id, $image_id, $rotate_value, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image, 0, 0, 1, 1);
            my $rotated_image_id = $rotate_return->{rotated_image_id};

            my $image = SGN::Image->new( $schema->storage->dbh, $rotated_image_id, $c );
            my $image_fullpath = $image->get_filename('original_converted', 'full');

            my @size = imgsize($image_fullpath);
            my $width = $size[0];
            my $length = $size[1];
            my $x_center = $width/2;
            my $y_center = $length/2;

            my $cropping_value = encode_json [[{x=>0, y=>0}, {x=>$width, y=>0}, {x=>$width, y=>$length}, {x=>0, y=>$length}]];

            my $plot_polygons_value;
            foreach (@{$geojson_value->{features}}) {
                my $plot_number = $_->{properties}->{ID};
                my $coordinates = $_->{geometry}->{coordinates};
                my $stock_name = $trial_lookup->{$plot_number}->{plot_name};
                my @coords;
                foreach my $crd (@{$coordinates->[0]}) {
                    if ($coordinate_system eq 'Pixels') {
                        push @coords, {
                            x => $crd->[0],
                            y => $crd->[1],
                        };
                    }
                    else {
                        my $geocoords = $drone_run_band_geoparams_coordinates->[$drone_run_band_counter];

                        my $xOrigin = $geocoords->[0];
                        my $yOrigin = $geocoords->[3];
                        my $pixelWidth = $geocoords->[1];
                        my $pixelHeight = -1*$geocoords->[5];
                        my $x_pos = ($crd->[0] - $xOrigin) / $pixelWidth;
                        my $y_pos = ($yOrigin - $crd->[1] ) / $pixelHeight;

                        my $x_pos_rotated = ($x_pos - $x_center)*cos($rad_conversion*$rotate_value*-1) - ($y_pos - $y_center)*sin($rad_conversion*$rotate_value*-1) + $x_center;
                        my $y_pos_rotated = ($y_pos - $y_center)*cos($rad_conversion*$rotate_value*-1) + ($x_pos - $x_center)*sin($rad_conversion*$rotate_value*-1) + $y_center;

                        push @coords, {
                            x => round($x_pos_rotated),
                            y => round($y_pos_rotated),
                        };
                    }
                }
                my $last_point = pop @coords;
                $plot_polygons_value->{$stock_name} = \@coords;
            }
            $plot_polygons_value = encode_json $plot_polygons_value;

            $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
            my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
            $archive_temp_image .= '.png';

            my $cropping_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_image_cropping($c, $schema, $drone_run_band_project_id, $rotated_image_id, $cropping_value, $user_id, $user_name, $user_role, $archive_temp_image, $apply_image_width_ratio, $apply_image_height_ratio);
            my $cropped_image_id = $cropping_return->{cropped_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
            my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
            $archive_denoise_temp_image .= '.png';

            my $denoise_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_image_denoise($c, $schema, $metadata_schema, $cropped_image_id, $drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);
            my $denoised_image_id = $denoise_return->{denoised_image_id};

            $drone_run_band_info{$drone_run_band_project_id} = {
                denoised_image_id => $denoised_image_id,
                rotate_value => $rotate_value,
                cropping_value => $cropping_value,
                drone_run_band_type => $drone_run_band_type,
                drone_run_project_id => $drone_run_project_id_in,
                drone_run_project_name => $drone_run_project_info{$drone_run_project_id_in}->{name},
                plot_polygons_value => $plot_polygons_value,
                check_resize => 1,
                keep_original_size_rotate => 1
            };

            my @denoised_plot_polygon_type = @{$term_map->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{base}};
            my @denoised_background_threshold_removed_imagery_types = @{$term_map->{$drone_run_band_type}->{imagery_types}->{threshold_background}};
            my @denoised_background_threshold_removed_plot_polygon_types = @{$term_map->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{threshold_background}};

            my $polygon_type = '';
            if ($rotate_value != 0) {
                $polygon_type = 'rectangular_square';
            } else {
                $polygon_type = 'rectangular_polygon';
            }

            foreach (@denoised_plot_polygon_type) {
                my $plot_polygon_original_denoised_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_plot_polygon_assign($c, $schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $plot_polygons_value, $_, $user_id, $user_name, $user_role, 0, 0, $apply_image_width_ratio, $apply_image_height_ratio, $polygon_type);
            }

            for my $iterator (0..(scalar(@denoised_background_threshold_removed_imagery_types)-1)) {
                $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
                my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
                $archive_remove_background_temp_image .= '.png';

                my $background_removed_threshold_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_image_background_remove_threshold_percentage($c, $schema, $denoised_image_id, $drone_run_band_project_id, $denoised_background_threshold_removed_imagery_types[$iterator], '25', '25', $user_id, $user_name, $user_role, $archive_remove_background_temp_image);

                my $plot_polygon_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_plot_polygon_assign($c, $schema, $metadata_schema, $background_removed_threshold_return->{removed_background_image_id}, $drone_run_band_project_id, $plot_polygons_value, $denoised_background_threshold_removed_plot_polygon_types[$iterator], $user_id, $user_name, $user_role, 0, 0, $apply_image_width_ratio, $apply_image_height_ratio, $polygon_type);
            }

            $drone_run_band_counter++;
        }

        print STDERR Dumper \%selected_drone_run_band_types;
        print STDERR Dumper \%vegetative_indices_hash;

        SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_minimal_vi_standard_process($c, $schema, $metadata_schema, \%vegetative_indices_hash, \%selected_drone_run_band_types, \%drone_run_band_info, $user_id, $user_name, $user_role, 'rectangular_polygon');

        $drone_run_process_in_progress = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$process_indicator_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>0
        },
        {
            key=>'projectprop_c1'
        });

        $drone_run_process_completed = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$processed_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>1
        },
        {
            key=>'projectprop_c1'
        });

        $drone_run_process_minimal_vi_completed = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$processed_minimal_vi_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>1
        },
        {
            key=>'projectprop_c1'
        });

        my $return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_phenotype_automated($c, $schema, $metadata_schema, $phenome_schema, $drone_run_project_id_in, $time_cvterm_id, $phenotype_methods, $standard_process_type, 1, undef, $user_id, $user_name, $user_role);
    }

    $c->stash->{message} = "Enviado com sucesso! Acesse <a href='/breeders/drone_imagery'>Imagens de drone</a>";
    $c->stash->{template} = 'generic_message.mas';
    return;
}

sub _check_user_login {
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{message} = 'Você precisa estar conectado para fazer isso!';
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{message} = 'Você precisa estar conectado para fazer isso!';
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    return ($user_id, $user_name, $user_role);
}

1;

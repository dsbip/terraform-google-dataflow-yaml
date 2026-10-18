# -----------------------------------------------------------------------------
# One Data Pipeline (google_data_pipeline_pipeline): a Dataflow classic or
# Flex Template that is launched on a schedule (batch) or kept running
# (streaming). Usable on its own; the YAML root module calls it once per
# pipeline.
# -----------------------------------------------------------------------------

locals {
  flex     = var.container_spec_gcs_path != null
  type     = startswith(var.type, "PIPELINE_TYPE_") ? var.type : "PIPELINE_TYPE_${var.type}"
  state    = startswith(var.state, "STATE_") ? var.state : "STATE_${var.state}"
  job_name = coalesce(var.job_name, replace(lower(var.name), "_", "-"))

  environment = {
    temp_location           = var.temp_location
    service_account_email   = var.service_account_email
    network                 = var.network
    subnetwork              = var.subnetwork
    machine_type            = var.machine_type
    max_workers             = var.max_workers
    num_workers             = var.num_workers
    ip_configuration        = var.ip_configuration
    kms_key_name            = var.kms_key_name
    additional_experiments  = var.additional_experiments
    additional_user_labels  = length(var.labels) == 0 ? null : var.labels
    enable_streaming_engine = var.enable_streaming_engine
    zone                    = var.zone
    worker_region           = var.worker_region
    worker_zone             = var.worker_zone
  }
}

resource "google_data_pipeline_pipeline" "this" {
  name                            = "projects/${var.project_id}/locations/${var.region}/pipelines/${var.name}"
  project                         = var.project_id
  region                          = var.region
  display_name                    = coalesce(var.display_name, var.name)
  type                            = local.type
  state                           = local.state
  scheduler_service_account_email = var.scheduler_service_account_email
  pipeline_sources                = var.pipeline_sources
  deletion_policy                 = var.deletion_policy

  dynamic "schedule_info" {
    for_each = var.schedule == null ? [] : [var.schedule]
    content {
      schedule  = schedule_info.value
      time_zone = var.time_zone
    }
  }

  workload {
    dynamic "dataflow_flex_template_request" {
      for_each = local.flex ? [1] : []
      content {
        project_id    = var.project_id
        location      = var.region
        validate_only = var.validate_only

        launch_parameter {
          job_name                = local.job_name
          container_spec_gcs_path = var.container_spec_gcs_path
          parameters              = var.parameters
          launch_options          = var.launch_options
          transform_name_mappings = var.transform_name_mapping
          update                  = var.update

          environment {
            temp_location           = local.environment.temp_location
            service_account_email   = local.environment.service_account_email
            network                 = local.environment.network
            subnetwork              = local.environment.subnetwork
            machine_type            = local.environment.machine_type
            max_workers             = local.environment.max_workers
            num_workers             = local.environment.num_workers
            ip_configuration        = local.environment.ip_configuration
            kms_key_name            = local.environment.kms_key_name
            additional_experiments  = local.environment.additional_experiments
            additional_user_labels  = local.environment.additional_user_labels
            enable_streaming_engine = local.environment.enable_streaming_engine
            zone                    = local.environment.zone
            worker_region           = local.environment.worker_region
            worker_zone             = local.environment.worker_zone
            flexrs_goal             = var.flexrs_goal
          }
        }
      }
    }

    dynamic "dataflow_launch_template_request" {
      for_each = local.flex ? [] : [1]
      content {
        project_id    = var.project_id
        location      = var.region
        gcs_path      = var.template_gcs_path
        validate_only = var.validate_only

        launch_parameters {
          job_name               = local.job_name
          parameters             = var.parameters
          transform_name_mapping = var.transform_name_mapping
          update                 = var.update

          environment {
            temp_location              = local.environment.temp_location
            service_account_email      = local.environment.service_account_email
            network                    = local.environment.network
            subnetwork                 = local.environment.subnetwork
            machine_type               = local.environment.machine_type
            max_workers                = local.environment.max_workers
            num_workers                = local.environment.num_workers
            ip_configuration           = local.environment.ip_configuration
            kms_key_name               = local.environment.kms_key_name
            additional_experiments     = local.environment.additional_experiments
            additional_user_labels     = local.environment.additional_user_labels
            enable_streaming_engine    = local.environment.enable_streaming_engine
            zone                       = local.environment.zone
            worker_region              = local.environment.worker_region
            worker_zone                = local.environment.worker_zone
            bypass_temp_dir_validation = var.bypass_temp_dir_validation
          }
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = (var.template_gcs_path == null) != (var.container_spec_gcs_path == null)
      error_message = "Set exactly one of template_gcs_path and container_spec_gcs_path."
    }
    precondition {
      condition     = !(local.type == "PIPELINE_TYPE_STREAMING" && var.schedule != null)
      error_message = "A schedule is only for batch pipelines."
    }
  }
}

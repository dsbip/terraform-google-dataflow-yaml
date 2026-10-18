# Data Pipelines: type and state forms, schedules, job names, and the
# workload for Flex and classic templates.

mock_provider "google" {}
mock_provider "google-beta" {}

variables {
  project_id = "test-project"
  region     = "europe-west1"
}

run "flex_pipeline_with_every_setting" {
  command = plan

  variables {
    config_yaml = <<-EOT
      pipelines:
        daily:
          name: daily_load
          display_name: daily_orders
          schedule: "30 2 * * *"
          time_zone: Europe/Berlin
          scheduler_service_account_email: sched@test-project.iam.gserviceaccount.com
          pipeline_sources: { origin: terraform }
          job_name: orders-load
          google_template: { name: GCS_Text_to_BigQuery_Flex }
          parameters: { inputFilePattern: "gs://in/*.json", shards: 4 }
          labels: { app: load }
          launch_options: { opt: "1" }
          transform_name_mapping: { Old: New }
          update: false
          validate_only: true
          temp_location: gs://t/tmp
          service_account_email: df@test-project.iam.gserviceaccount.com
          network: vpc
          subnetwork: regions/europe-west1/subnetworks/df
          machine_type: n2-standard-4
          max_workers: 20
          num_workers: 2
          ip_configuration: WORKER_IP_PRIVATE
          kms_key_name: k
          additional_experiments: [use_runner_v2]
          enable_streaming_engine: false
          zone: europe-west1-b
          worker_region: europe-west4
          worker_zone: europe-west4-a
          flexrs_goal: FLEXRS_COST_OPTIMIZED
          deletion_policy: DELETE
    EOT
  }

  assert {
    condition = (
      module.pipeline["daily"].pipeline.name == "projects/test-project/locations/europe-west1/pipelines/daily_load" &&
      module.pipeline["daily"].pipeline.display_name == "daily_orders" &&
      module.pipeline["daily"].pipeline.type == "PIPELINE_TYPE_BATCH" &&
      module.pipeline["daily"].pipeline.state == "STATE_ACTIVE" &&
      module.pipeline["daily"].pipeline.scheduler_service_account_email == "sched@test-project.iam.gserviceaccount.com" &&
      module.pipeline["daily"].pipeline.pipeline_sources == tomap({ origin = "terraform" }) &&
      module.pipeline["daily"].pipeline.deletion_policy == "DELETE"
    )
    error_message = "Wrong pipeline attributes."
  }
  assert {
    condition = (
      module.pipeline["daily"].pipeline.schedule_info[0].schedule == "30 2 * * *" &&
      module.pipeline["daily"].pipeline.schedule_info[0].time_zone == "Europe/Berlin"
    )
    error_message = "Wrong schedule."
  }
  assert {
    condition = (
      length(module.pipeline["daily"].pipeline.workload[0].dataflow_launch_template_request) == 0 &&
      module.pipeline["daily"].pipeline.workload[0].dataflow_flex_template_request[0].project_id == "test-project" &&
      module.pipeline["daily"].pipeline.workload[0].dataflow_flex_template_request[0].location == "europe-west1" &&
      module.pipeline["daily"].pipeline.workload[0].dataflow_flex_template_request[0].validate_only == true
    )
    error_message = "A Flex Template pipeline needs a flex template request."
  }
  assert {
    condition = (
      module.pipeline["daily"].pipeline.workload[0].dataflow_flex_template_request[0].launch_parameter[0].job_name == "orders-load" &&
      module.pipeline["daily"].pipeline.workload[0].dataflow_flex_template_request[0].launch_parameter[0].container_spec_gcs_path == "gs://dataflow-templates-europe-west1/latest/flex/GCS_Text_to_BigQuery_Flex" &&
      module.pipeline["daily"].pipeline.workload[0].dataflow_flex_template_request[0].launch_parameter[0].parameters == tomap({ inputFilePattern = "gs://in/*.json", shards = "4" }) &&
      module.pipeline["daily"].pipeline.workload[0].dataflow_flex_template_request[0].launch_parameter[0].launch_options == tomap({ opt = "1" }) &&
      module.pipeline["daily"].pipeline.workload[0].dataflow_flex_template_request[0].launch_parameter[0].transform_name_mappings == tomap({ Old = "New" }) &&
      module.pipeline["daily"].pipeline.workload[0].dataflow_flex_template_request[0].launch_parameter[0].update == false
    )
    error_message = "Wrong launch parameter."
  }
  assert {
    condition = jsonencode(module.pipeline["daily"].pipeline.workload[0].dataflow_flex_template_request[0].launch_parameter[0].environment[0]) == jsonencode({
      additional_experiments  = ["use_runner_v2"]
      additional_user_labels  = { app = "load" }
      enable_streaming_engine = false
      flexrs_goal             = "FLEXRS_COST_OPTIMIZED"
      ip_configuration        = "WORKER_IP_PRIVATE"
      kms_key_name            = "k"
      machine_type            = "n2-standard-4"
      max_workers             = 20
      network                 = "vpc"
      num_workers             = 2
      service_account_email   = "df@test-project.iam.gserviceaccount.com"
      subnetwork              = "regions/europe-west1/subnetworks/df"
      temp_location           = "gs://t/tmp"
      worker_region           = "europe-west4"
      worker_zone             = "europe-west4-a"
      zone                    = "europe-west1-b"
    })
    error_message = "Unexpected environment: ${jsonencode(module.pipeline["daily"].pipeline.workload[0].dataflow_flex_template_request[0].launch_parameter[0].environment[0])}"
  }
}

run "classic_pipeline" {
  command = plan

  variables {
    config_yaml = <<-EOT
      pipelines:
        monthly:
          schedule: "0 5 1 * *"
          state: PAUSED
          google_template: { name: Bulk_Compress_GCS_Files, type: classic }
          parameters: { compression: GZIP }
          temp_location: gs://t/tmp
          bypass_temp_dir_validation: true
          update: true
    EOT
  }

  assert {
    condition = (
      length(module.pipeline["monthly"].pipeline.workload[0].dataflow_flex_template_request) == 0 &&
      module.pipeline["monthly"].pipeline.workload[0].dataflow_launch_template_request[0].gcs_path == "gs://dataflow-templates-europe-west1/latest/Bulk_Compress_GCS_Files" &&
      module.pipeline["monthly"].pipeline.workload[0].dataflow_launch_template_request[0].launch_parameters[0].job_name == "monthly" &&
      module.pipeline["monthly"].pipeline.workload[0].dataflow_launch_template_request[0].launch_parameters[0].parameters == tomap({ compression = "GZIP" }) &&
      module.pipeline["monthly"].pipeline.workload[0].dataflow_launch_template_request[0].launch_parameters[0].update == true &&
      module.pipeline["monthly"].pipeline.workload[0].dataflow_launch_template_request[0].launch_parameters[0].environment[0].bypass_temp_dir_validation == true &&
      module.pipeline["monthly"].pipeline.workload[0].dataflow_launch_template_request[0].launch_parameters[0].environment[0].temp_location == "gs://t/tmp"
    )
    error_message = "A classic template pipeline needs a launch template request."
  }
  assert {
    condition     = module.pipeline["monthly"].pipeline.state == "STATE_PAUSED" && module.pipeline["monthly"].pipeline.display_name == "monthly"
    error_message = "PAUSED should expand; the display name defaults to the ID."
  }
}

run "type_is_inferred_and_long_forms_are_accepted" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        pipelines: { container_spec_gcs_path: gs://t/spec.json }
      pipelines:
        scheduled: { schedule: "0 1 * * *" }
        unscheduled: {}
        batch-on-demand: { type: BATCH }
        long-forms: { type: PIPELINE_TYPE_STREAMING, state: STATE_PAUSED }
    EOT
  }

  assert {
    condition = (
      module.pipeline["scheduled"].type == "PIPELINE_TYPE_BATCH" &&
      module.pipeline["unscheduled"].type == "PIPELINE_TYPE_STREAMING" &&
      module.pipeline["batch-on-demand"].type == "PIPELINE_TYPE_BATCH" &&
      module.pipeline["long-forms"].type == "PIPELINE_TYPE_STREAMING" &&
      module.pipeline["long-forms"].state == "STATE_PAUSED"
    )
    error_message = "Wrong types or states."
  }
  assert {
    condition     = length(module.pipeline["unscheduled"].pipeline.schedule_info) == 0 && length(module.pipeline["batch-on-demand"].pipeline.schedule_info) == 0
    error_message = "Without a schedule there is no schedule_info."
  }
  assert {
    condition     = module.pipeline["scheduled"].pipeline.workload[0].dataflow_flex_template_request[0].launch_parameter[0].environment[0].additional_user_labels == null
    error_message = "Without labels no additional_user_labels."
  }
}

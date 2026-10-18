# The submodules on their own, without the YAML layer: typed inputs, their
# defaults and their input validation.

mock_provider "google" {}
mock_provider "google-beta" {}

variables {
  name       = "standalone"
  project_id = "test-project"
  region     = "europe-west1"
}

run "classic_job_module" {
  command = plan

  module {
    source = "./modules/classic-job"
  }

  variables {
    template_gcs_path = "gs://dataflow-templates-europe-west1/latest/Word_Count"
    temp_location     = "gs://t/tmp"
    parameters        = { inputFile = "gs://in", output = "gs://out" }
  }

  assert {
    condition     = google_dataflow_job.this.temp_gcs_location == "gs://t/tmp" && google_dataflow_job.this.parameters["output"] == "gs://out"
    error_message = "Wrong classic job."
  }
}

run "classic_job_inputs_are_validated" {
  command = plan

  module {
    source = "./modules/classic-job"
  }

  variables {
    name              = "Not_Valid"
    template_gcs_path = "/local/path"
    temp_location     = "gs://t/tmp"
    ip_configuration  = "PRIVATE"
    on_delete         = "DRAIN"
  }

  expect_failures = [var.name, var.template_gcs_path, var.ip_configuration, var.on_delete]
}

run "flex_job_module_uses_google_beta" {
  command = plan

  module {
    source = "./modules/flex-job"
  }

  variables {
    container_spec_gcs_path = "gs://t/spec.json"
    num_workers             = 3
  }

  assert {
    condition     = google_dataflow_flex_template_job.this.container_spec_gcs_path == "gs://t/spec.json" && google_dataflow_flex_template_job.this.num_workers == 3
    error_message = "Wrong Flex Template job."
  }
}

run "flex_job_inputs_are_validated" {
  command = plan

  module {
    source = "./modules/flex-job"
  }

  variables {
    container_spec_gcs_path = "spec.json"
    autoscaling_algorithm   = "SMART"
    deletion_policy         = "KEEP"
    temp_location           = "/tmp"
  }

  expect_failures = [var.container_spec_gcs_path, var.autoscaling_algorithm, var.deletion_policy, var.temp_location]
}

run "pipeline_module_short_forms_and_defaults" {
  command = plan

  module {
    source = "./modules/pipeline"
  }

  variables {
    name                    = "Nightly_Export"
    type                    = "BATCH"
    schedule                = "0 3 * * *"
    container_spec_gcs_path = "gs://t/spec.json"
  }

  assert {
    condition = (
      google_data_pipeline_pipeline.this.type == "PIPELINE_TYPE_BATCH" &&
      google_data_pipeline_pipeline.this.state == "STATE_ACTIVE" &&
      google_data_pipeline_pipeline.this.display_name == "Nightly_Export" &&
      output.job_name == "nightly-export"
    )
    error_message = "Wrong pipeline defaults."
  }
}

run "pipeline_module_needs_exactly_one_template" {
  command = plan

  module {
    source = "./modules/pipeline"
  }

  variables {
    type = "BATCH"
  }

  expect_failures = [google_data_pipeline_pipeline.this]
}

run "pipeline_module_rejects_a_schedule_for_streaming" {
  command = plan

  module {
    source = "./modules/pipeline"
  }

  variables {
    type                    = "STREAMING"
    schedule                = "0 * * * *"
    container_spec_gcs_path = "gs://t/spec.json"
  }

  expect_failures = [google_data_pipeline_pipeline.this]
}

run "pipeline_module_inputs_are_validated" {
  command = plan

  module {
    source = "./modules/pipeline"
  }

  variables {
    name                    = "bad name"
    type                    = "CRON"
    state                   = "STOPPED"
    container_spec_gcs_path = "gs://t/spec.json"
  }

  expect_failures = [var.name, var.type, var.state]
}

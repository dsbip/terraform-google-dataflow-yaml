# Outputs after an apply with the mocked providers (computed values filled in).

mock_provider "google" {
  mock_resource "google_dataflow_job" {
    defaults = { job_id = "2026-10-18_01_00_00-111", state = "JOB_STATE_DONE", type = "JOB_TYPE_BATCH" }
  }
}

mock_provider "google-beta" {
  mock_resource "google_dataflow_flex_template_job" {
    defaults = { job_id = "2026-10-18_01_00_00-222", state = "JOB_STATE_RUNNING", type = "JOB_TYPE_STREAMING" }
  }
}

variables {
  project_id  = "test-project"
  region      = "europe-west1"
  config_yaml = <<-EOT
    jobs:
      count: { google_template: { name: Word_Count, type: classic }, temp_location: gs://t/tmp }
      stream: { google_template: { name: PubSub_to_BigQuery_Flex } }
      retired: { enabled: false, container_spec_gcs_path: gs://t/spec.json }
    pipelines:
      nightly: { schedule: "0 2 * * *", container_spec_gcs_path: gs://t/spec.json }
  EOT
}

run "outputs_cover_every_enabled_entry" {
  command = apply

  assert {
    condition     = toset(keys(output.jobs)) == toset(["count", "stream"]) && toset(keys(output.pipelines)) == toset(["nightly"])
    error_message = "Outputs should list enabled entries only."
  }
  assert {
    condition = (
      output.jobs["count"].template_type == "classic" &&
      output.jobs["count"].template == "gs://dataflow-templates-europe-west1/latest/Word_Count" &&
      output.jobs["count"].job_id == "2026-10-18_01_00_00-111" &&
      output.jobs["count"].type == "JOB_TYPE_BATCH" &&
      output.jobs["stream"].template_type == "flex" &&
      output.jobs["stream"].state == "JOB_STATE_RUNNING"
    )
    error_message = "Unexpected jobs output: ${jsonencode(output.jobs)}"
  }
  assert {
    condition     = output.job_ids == { count = "2026-10-18_01_00_00-111", stream = "2026-10-18_01_00_00-222" }
    error_message = "Unexpected job_ids."
  }
  assert {
    condition = (
      output.pipelines["nightly"].id == "projects/test-project/locations/europe-west1/pipelines/nightly" &&
      output.pipelines["nightly"].type == "PIPELINE_TYPE_BATCH" &&
      output.pipelines["nightly"].state == "STATE_ACTIVE" &&
      output.pipelines["nightly"].job_name == "nightly" &&
      output.pipelines["nightly"].template_type == "flex"
    )
    error_message = "Unexpected pipelines output: ${jsonencode(output.pipelines)}"
  }
  assert {
    condition     = output.config.jobs["retired"].enabled == false && output.config.jobs["retired"].kind == "flex"
    error_message = "config should include disabled entries."
  }
}

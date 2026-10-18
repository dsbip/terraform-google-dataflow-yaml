# -----------------------------------------------------------------------------
# One Dataflow job launched from a Flex Template (google-beta provider).
# Usable on its own; the YAML root module calls it once per Flex Template job.
#
# Batch jobs end: once a job has finished, the provider removes it from the
# state and the next apply launches it again. Schedule recurring batch work
# with modules/pipeline instead.
# -----------------------------------------------------------------------------

resource "google_dataflow_flex_template_job" "this" {
  provider = google-beta

  name                         = var.name
  project                      = var.project_id
  region                       = var.region
  container_spec_gcs_path      = var.container_spec_gcs_path
  parameters                   = var.parameters
  labels                       = var.labels
  temp_location                = var.temp_location
  staging_location             = var.staging_location
  service_account_email        = var.service_account_email
  network                      = var.network
  subnetwork                   = var.subnetwork
  machine_type                 = var.machine_type
  max_workers                  = var.max_workers
  num_workers                  = var.num_workers
  ip_configuration             = var.ip_configuration
  kms_key_name                 = var.kms_key_name
  additional_experiments       = var.additional_experiments
  additional_pipeline_options  = var.additional_pipeline_options
  enable_streaming_engine      = var.enable_streaming_engine
  launcher_machine_type        = var.launcher_machine_type
  sdk_container_image          = var.sdk_container_image
  autoscaling_algorithm        = var.autoscaling_algorithm
  transform_name_mapping       = var.transform_name_mapping
  on_delete                    = var.on_delete
  skip_wait_on_job_termination = var.skip_wait_on_job_termination
  create_ignore_already_exists = var.create_ignore_already_exists
  deletion_policy              = var.deletion_policy
}

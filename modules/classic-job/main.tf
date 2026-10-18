# -----------------------------------------------------------------------------
# One Dataflow job launched from a classic template. Usable on its own; the
# YAML root module calls it once per classic job.
#
# Batch jobs end: once a job has finished, the provider removes it from the
# state and the next apply launches it again. Schedule recurring batch work
# with modules/pipeline instead.
# -----------------------------------------------------------------------------

resource "google_dataflow_job" "this" {
  name                         = var.name
  project                      = var.project_id
  region                       = var.region
  zone                         = var.zone
  template_gcs_path            = var.template_gcs_path
  temp_gcs_location            = var.temp_location
  parameters                   = var.parameters
  labels                       = var.labels
  service_account_email        = var.service_account_email
  network                      = var.network
  subnetwork                   = var.subnetwork
  machine_type                 = var.machine_type
  max_workers                  = var.max_workers
  ip_configuration             = var.ip_configuration
  kms_key_name                 = var.kms_key_name
  additional_experiments       = var.additional_experiments
  enable_streaming_engine      = var.enable_streaming_engine
  transform_name_mapping       = var.transform_name_mapping
  on_delete                    = var.on_delete
  skip_wait_on_job_termination = var.skip_wait_on_job_termination
  deletion_policy              = var.deletion_policy
}

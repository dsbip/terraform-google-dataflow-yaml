# One modules/classic-job or modules/flex-job instance per enabled job,
# depending on the template type. The maps are empty while the configuration
# has problems, so the plan fails with validation.tf's messages instead of
# type or provider errors.

module "classic_job" {
  source   = "./modules/classic-job"
  for_each = { for k, j in local.jobs : k => j if j.enabled && j.kind == "classic" && local.config_valid }

  name                         = each.value.name
  project_id                   = each.value.project_id
  region                       = each.value.region
  zone                         = each.value.zone
  template_gcs_path            = each.value.template_path
  temp_location                = each.value.temp_location
  parameters                   = each.value.parameters
  labels                       = each.value.labels
  service_account_email        = each.value.service_account_email
  network                      = each.value.network
  subnetwork                   = each.value.subnetwork
  machine_type                 = each.value.machine_type
  max_workers                  = each.value.max_workers
  ip_configuration             = each.value.ip_configuration
  kms_key_name                 = each.value.kms_key_name
  additional_experiments       = each.value.additional_experiments
  enable_streaming_engine      = each.value.enable_streaming_engine
  transform_name_mapping       = each.value.transform_name_mapping
  on_delete                    = each.value.on_delete
  skip_wait_on_job_termination = each.value.skip_wait_on_job_termination
  deletion_policy              = each.value.deletion_policy
}

module "flex_job" {
  source   = "./modules/flex-job"
  for_each = { for k, j in local.jobs : k => j if j.enabled && j.kind == "flex" && local.config_valid }

  name                         = each.value.name
  project_id                   = each.value.project_id
  region                       = each.value.region
  container_spec_gcs_path      = each.value.template_path
  parameters                   = each.value.parameters
  labels                       = each.value.labels
  temp_location                = each.value.temp_location
  staging_location             = each.value.staging_location
  service_account_email        = each.value.service_account_email
  network                      = each.value.network
  subnetwork                   = each.value.subnetwork
  machine_type                 = each.value.machine_type
  max_workers                  = each.value.max_workers
  num_workers                  = each.value.num_workers
  ip_configuration             = each.value.ip_configuration
  kms_key_name                 = each.value.kms_key_name
  additional_experiments       = each.value.additional_experiments
  additional_pipeline_options  = each.value.additional_pipeline_options
  enable_streaming_engine      = each.value.enable_streaming_engine
  launcher_machine_type        = each.value.launcher_machine_type
  sdk_container_image          = each.value.sdk_container_image
  autoscaling_algorithm        = each.value.autoscaling_algorithm
  transform_name_mapping       = each.value.transform_name_mapping
  on_delete                    = each.value.on_delete
  skip_wait_on_job_termination = each.value.skip_wait_on_job_termination
  create_ignore_already_exists = each.value.create_ignore_already_exists
  deletion_policy              = each.value.deletion_policy
}

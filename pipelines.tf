# One modules/pipeline instance per enabled pipeline (empty while the
# configuration has problems, see jobs.tf).
module "pipeline" {
  source   = "./modules/pipeline"
  for_each = { for k, p in local.pipelines : k => p if p.enabled && local.config_valid }

  name                            = each.value.name
  project_id                      = each.value.project_id
  region                          = each.value.region
  display_name                    = each.value.display_name
  type                            = each.value.type
  state                           = each.value.state
  schedule                        = each.value.schedule
  time_zone                       = each.value.time_zone
  scheduler_service_account_email = each.value.scheduler_service_account_email
  pipeline_sources                = each.value.pipeline_sources
  job_name                        = each.value.job_name
  template_gcs_path               = each.value.kind == "classic" ? each.value.template_path : null
  container_spec_gcs_path         = each.value.kind == "flex" ? each.value.template_path : null
  parameters                      = each.value.parameters
  labels                          = each.value.labels
  launch_options                  = each.value.launch_options
  transform_name_mapping          = each.value.transform_name_mapping
  update                          = each.value.update
  validate_only                   = each.value.validate_only
  temp_location                   = each.value.temp_location
  service_account_email           = each.value.service_account_email
  network                         = each.value.network
  subnetwork                      = each.value.subnetwork
  machine_type                    = each.value.machine_type
  max_workers                     = each.value.max_workers
  num_workers                     = each.value.num_workers
  ip_configuration                = each.value.ip_configuration
  kms_key_name                    = each.value.kms_key_name
  additional_experiments          = each.value.additional_experiments
  enable_streaming_engine         = each.value.enable_streaming_engine
  zone                            = each.value.zone
  worker_region                   = each.value.worker_region
  worker_zone                     = each.value.worker_zone
  flexrs_goal                     = each.value.flexrs_goal
  bypass_temp_dir_validation      = each.value.bypass_temp_dir_validation
  deletion_policy                 = each.value.deletion_policy
}

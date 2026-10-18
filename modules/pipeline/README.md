# modules/pipeline

One Data Pipeline (`google_data_pipeline_pipeline`): a classic or Flex Template launched on a schedule (batch) or run as a streaming pipeline. The module builds the provider's nested launch request from flat inputs.

```hcl
module "nightly_export" {
  source = "github.com/dsbip/terraform-google-dataflow-yaml//modules/pipeline?ref=v1.0.0"

  name                    = "nightly_export"
  project_id              = "my-project"
  region                  = "europe-west1"
  type                    = "BATCH"
  schedule                = "0 3 * * *"
  time_zone               = "Europe/Berlin"
  container_spec_gcs_path = "gs://dataflow-templates-europe-west1/latest/flex/BigQuery_to_Parquet"
  temp_location           = "gs://my-bucket/tmp"
  parameters = {
    tableRef = "my-project:sales.orders"
    bucket   = "gs://my-bucket/exports/"
  }
}
```

Inputs: `name` (pipeline ID), `project_id`, `region` and `type` (`BATCH`/`STREAMING` or the long forms) are required, plus exactly one of `template_gcs_path` and `container_spec_gcs_path`. Optional: `display_name` (default: the ID), `state` (default `ACTIVE`), `schedule`, `time_zone`, `scheduler_service_account_email`, `pipeline_sources`, `job_name` (default: the ID in lowercase with hyphens), `parameters`, `labels` (→ `additional_user_labels`), `launch_options` (Flex), `transform_name_mapping`, `update`, `validate_only`, `temp_location`, `service_account_email`, `network`, `subnetwork`, `machine_type`, `max_workers`, `num_workers`, `ip_configuration`, `kms_key_name`, `additional_experiments`, `enable_streaming_engine`, `zone`, `worker_region`, `worker_zone`, `flexrs_goal` (Flex), `bypass_temp_dir_validation` (classic), `deletion_policy`. See [docs/pipelines.md](../../docs/pipelines.md).

Outputs: `id` (resource name), `name`, `project_id`, `region`, `job_name`, `type`, `state`, `next_job_time`, `pipeline` (the resource).

# modules/flex-job

Launches one Dataflow job from a Flex Template (`google_dataflow_flex_template_job`, **google-beta provider**). The YAML root module calls it for every job with `container_spec_gcs_path` or a Flex `google_template`.

```hcl
module "orders_stream" {
  source = "github.com/dsbip/terraform-google-dataflow-yaml//modules/flex-job?ref=v1.0.0"

  name                    = "orders-to-bq"
  project_id              = "my-project"
  region                  = "europe-west1"
  container_spec_gcs_path = "gs://dataflow-templates-europe-west1/latest/flex/PubSub_to_BigQuery_Flex"
  temp_location           = "gs://my-bucket/tmp"
  enable_streaming_engine = true
  on_delete               = "drain"
  parameters = {
    inputSubscription = "projects/my-project/subscriptions/orders"
    outputTableSpec   = "my-project:sales.orders"
  }
}
```

The calling module must configure `provider "google-beta"`.

Inputs: `name`, `project_id`, `region`, `container_spec_gcs_path` are required; optional are `parameters`, `labels`, `temp_location`, `staging_location`, `service_account_email`, `network`, `subnetwork`, `machine_type`, `max_workers`, `num_workers`, `ip_configuration`, `kms_key_name`, `additional_experiments`, `additional_pipeline_options`, `enable_streaming_engine`, `launcher_machine_type`, `sdk_container_image`, `autoscaling_algorithm`, `transform_name_mapping`, `on_delete`, `skip_wait_on_job_termination`, `create_ignore_already_exists`, `deletion_policy`. See [docs/jobs.md](../../docs/jobs.md).

Outputs: `id`, `job_id`, `name`, `project_id`, `region`, `state`, `type`, `job` (the resource).

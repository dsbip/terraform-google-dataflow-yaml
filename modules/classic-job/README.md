# modules/classic-job

Launches one Dataflow job from a classic template (`google_dataflow_job`). The YAML root module calls it for every job with `template_gcs_path` or a classic `google_template`.

```hcl
module "word_count" {
  source = "github.com/dsbip/terraform-google-dataflow-yaml//modules/classic-job?ref=v1.0.0"

  name              = "word-count"
  project_id        = "my-project"
  region            = "europe-west1"
  template_gcs_path = "gs://dataflow-templates-europe-west1/latest/Word_Count"
  temp_location     = "gs://my-bucket/tmp"
  parameters = {
    inputFile = "gs://dataflow-samples/shakespeare/kinglear.txt"
    output    = "gs://my-bucket/wordcount/out"
  }
}
```

Inputs: `name`, `project_id`, `region`, `template_gcs_path`, `temp_location` (the resource's `temp_gcs_location`) are required; optional are `zone`, `parameters`, `labels`, `service_account_email`, `network`, `subnetwork`, `machine_type`, `max_workers`, `ip_configuration`, `kms_key_name`, `additional_experiments`, `enable_streaming_engine`, `transform_name_mapping`, `on_delete`, `skip_wait_on_job_termination`, `deletion_policy`. See [docs/jobs.md](../../docs/jobs.md).

Outputs: `id`, `job_id`, `name`, `project_id`, `region`, `state`, `type`, `job` (the resource).

A finished batch job is removed from the state by the provider and launched again by the next apply; use [modules/pipeline](../pipeline) for recurring batch work.

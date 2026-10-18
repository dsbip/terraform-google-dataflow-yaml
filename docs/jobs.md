# Jobs

Each entry under `jobs` launches one Dataflow job, from a classic template (`google_dataflow_job`) or a Flex Template (`google_dataflow_flex_template_job`, google-beta provider). The template type follows from the template key; key names follow the providers, except `temp_location`, which is the classic resource's `temp_gcs_location`, and `region` for every job.

```yaml
jobs:
  orders-to-bigquery:
    google_template: { name: PubSub_to_BigQuery_Flex }
    parameters:
      inputSubscription: projects/my-project/subscriptions/orders
      outputTableSpec: my-project:sales.orders
    service_account_email: dataflow@my-project.iam.gserviceaccount.com
    temp_location: gs://my-project-dataflow/tmp
    enable_streaming_engine: true
    max_workers: 10
    on_delete: drain
```

**Batch jobs end.** Once a batch job has finished, the provider removes it from the Terraform state, and the next `terraform apply` launches it again. For recurring batch work use [pipelines](pipelines.md); for a one-off run, launch the job and remove it from the file (or set `enabled: false`) afterwards.

## Templates

Set exactly one of:

| Key | Template type | Description |
|---|---|---|
| `template_gcs_path` | classic | Your classic template: `gs://bucket/path/template`. |
| `container_spec_gcs_path` | Flex | Your Flex Template spec file: `gs://bucket/path/spec.json` (from `gcloud dataflow flex-template build`). |
| `google_template` | Flex (default) or classic | A Google-provided template by name, see below. |

`google_template`:

| Key | Description |
|---|---|
| `name` | Template name, e.g. `PubSub_to_BigQuery_Flex`, `Cloud_PubSub_to_GCS_Text_Flex`, `GCS_Text_to_BigQuery_Flex`, `BigQuery_to_Parquet` (Flex) or `Word_Count`, `Bulk_Compress_GCS_Files` (classic). Required. |
| `type` | `flex` (default) or `classic`. |
| `version` | `latest` (default) or a dated release such as `2026-09-15-00_RC00`; pin a release for reproducible deployments. |

It expands to `gs://dataflow-templates-REGION/VERSION/flex/NAME` (Flex) or `gs://dataflow-templates-REGION/VERSION/NAME` (classic), with the job's region. The [template reference](https://cloud.google.com/dataflow/docs/guides/templates/provided-templates) lists names and parameters.

## Job

| Key | Templates | Description |
|---|---|---|
| `enabled` | both | `false` skips the job (default `true`); it is still validated. |
| `name` | both | Job name, default: the YAML key. Lowercase letters, digits and hyphens, starting with a letter. |
| `project_id` | both | Project of the job. |
| `region` | both | Region of the job, e.g. `europe-west1`. |
| `parameters` | both | Template parameters. Numbers and booleans become strings. |
| `labels` | both | Job labels, merged over the module, `defaults.labels` and `defaults.jobs.labels` labels. |
| `temp_location` | both | `gs://` path for temporary files. **Required for classic templates.** |
| `staging_location` | Flex | `gs://` path for staging files. |
| `service_account_email` | both | Worker service account; needs `roles/dataflow.worker` plus access to the job's sources and sinks. |
| `network` | both | VPC network of the workers. |
| `subnetwork` | both | `regions/REGION/subnetworks/NAME`, or a full `https://www.googleapis.com/compute/v1/projects/HOST/regions/REGION/subnetworks/NAME` URL for Shared VPC. |
| `ip_configuration` | both | `WORKER_IP_PUBLIC` or `WORKER_IP_PRIVATE` (needs Private Google Access on the subnetwork). |
| `zone` | classic | Worker zone. |
| `machine_type` | both | Worker machine type, e.g. `n2-standard-4`. |
| `max_workers` | both | Upper bound of autoscaling. |
| `num_workers` | Flex | Initial number of workers. |
| `autoscaling_algorithm` | Flex | `AUTOSCALING_ALGORITHM_BASIC` or `AUTOSCALING_ALGORITHM_NONE` (fixed `num_workers`). |
| `launcher_machine_type` | Flex | Machine type of the launcher VM that starts the job (default `n1-standard-1`). |
| `sdk_container_image` | Flex | Custom worker image (custom containers). |
| `kms_key_name` | both | Cloud KMS key for job state and data (CMEK). |
| `enable_streaming_engine` | both | Use Streaming Engine (streaming jobs). |
| `additional_experiments` | both | Dataflow experiments, e.g. `[enable_prime]`. |
| `additional_pipeline_options` | Flex | Extra pipeline options, e.g. `[numberOfWorkerHarnessThreads=16]`. |
| `transform_name_mapping` | both | Old to new transform name prefixes, for in-place updates of streaming jobs whose transforms were renamed. |
| `on_delete` | both | `drain` (finish in-flight data) or `cancel` when the job is destroyed or replaced. |
| `skip_wait_on_job_termination` | both | Don't wait for draining or cancelling to finish. The next job must then use another name. |
| `create_ignore_already_exists` | Flex | Adopt a running job with the same name instead of failing. |
| `deletion_policy` | both | `DELETE`, `PREVENT` (`terraform destroy` fails) or `ABANDON` (removed from state, left running). |

Keys marked "classic" or "Flex" are reported when a job of the other type sets them; defaults of the other type are ignored.

# Pipelines

Each entry under `pipelines` creates one Data Pipeline (`google_data_pipeline_pipeline`): a Dataflow template that Data Pipelines launches on a schedule (batch) or runs as a streaming pipeline. Templates are chosen as for [jobs](jobs.md#templates), and the worker settings are the same keys; the module puts them into the pipeline's launch request.

```yaml
pipelines:
  nightly-export:
    schedule: "0 2 * * *"
    time_zone: Europe/Berlin
    google_template: { name: BigQuery_to_Parquet }
    parameters:
      tableRef: my-project:sales.orders
      bucket: gs://my-project-exports/orders/
    service_account_email: dataflow@my-project.iam.gserviceaccount.com
    scheduler_service_account_email: dataflow-scheduler@my-project.iam.gserviceaccount.com
    temp_location: gs://my-project-dataflow/tmp
```

Data Pipelines depends on Cloud Scheduler and is only available in App Engine regions.

## Pipeline

| Key | Templates | Description |
|---|---|---|
| `enabled` | both | `false` skips the pipeline (default `true`); it is still validated. |
| `name` | both | Pipeline ID, default: the YAML key. Letters, digits, hyphens and underscores (at most 63). The resource name is `projects/P/locations/R/pipelines/ID`. |
| `project_id` | both | Project of the pipeline and of the jobs it launches. |
| `region` | both | Region of the pipeline and of its jobs. |
| `display_name` | both | Display name (letters, digits, hyphens and underscores; default: the ID). |
| `type` | both | `BATCH` or `STREAMING` (or `PIPELINE_TYPE_BATCH` / `PIPELINE_TYPE_STREAMING`). Default: `BATCH` with a `schedule`, `STREAMING` without. |
| `state` | both | `ACTIVE` (default) or `PAUSED` (or `STATE_ACTIVE` / `STATE_PAUSED`). A paused pipeline launches nothing. |
| `schedule` | both | Cron schedule of a batch pipeline, e.g. `"30 2 * * *"`. Without it, a batch pipeline only runs on demand. |
| `time_zone` | both | Time zone of the schedule, e.g. `Europe/Berlin` (default UTC). |
| `scheduler_service_account_email` | both | Service account Cloud Scheduler uses to launch the jobs (default: the Compute Engine default service account). |
| `pipeline_sources` | both | Source metadata (for example set by Dataplex). |
| `job_name` | both | Name of the launched jobs. Default: the pipeline ID in lowercase with underscores as hyphens (`Daily_Load` → `daily-load`). Cannot be a default. |
| `template_gcs_path`, `container_spec_gcs_path`, `google_template` | | The template, exactly one, as for [jobs](jobs.md#templates). |
| `parameters` | both | Template parameters. |
| `labels` | both | Labels of the launched jobs (`additional_user_labels`). |
| `launch_options` | Flex | Launch options common to Flex Templates (not template parameters). |
| `transform_name_mapping` | both | Old to new transform name prefixes, with `update`. |
| `update` | both | Update a running streaming job with the same name instead of starting a new one. |
| `validate_only` | both | Only validate the launch request; no jobs are started. |
| `temp_location` | both | `gs://` path for temporary files. |
| `service_account_email` | both | Worker service account. |
| `network`, `subnetwork`, `ip_configuration` | both | Worker networking, as for [jobs](jobs.md#job). |
| `machine_type`, `max_workers`, `num_workers` | both | Worker size and count. |
| `kms_key_name` | both | Cloud KMS key (CMEK). |
| `additional_experiments` | both | Dataflow experiments. |
| `enable_streaming_engine` | both | Use Streaming Engine. |
| `zone` | both | Worker zone. |
| `worker_region` | both | Region of the workers, if different from the pipeline's region (e.g. close to the data). |
| `worker_zone` | both | Zone of the workers. |
| `flexrs_goal` | Flex | Flexible Resource Scheduling for batch pipelines: `FLEXRS_COST_OPTIMIZED` (cheaper, delayed start) or `FLEXRS_SPEED_OPTIMIZED`. |
| `bypass_temp_dir_validation` | classic | Skip validating `temp_location`. |
| `deletion_policy` | both | `DELETE`, `PREVENT` or `ABANDON`. |

Rules: `schedule` and `flexrs_goal` are only for batch pipelines; `time_zone` needs a `schedule` (a default `time_zone` is ignored for pipelines without one); keys marked "classic" or "Flex" are reported for the other template type.

# Batch pipelines example

Data Pipelines run Dataflow templates on a schedule, so recurring batch work doesn't depend on `terraform apply`:

| Pipeline | Schedule | Template | Shows |
|---|---|---|---|
| `daily-orders-load` | 02:30 daily | `GCS_Text_to_BigQuery_Flex` | FlexRS cost optimisation, display name |
| `weekly-parquet-export` | Sundays 04:00 | `BigQuery_to_Parquet` | bigger workers |
| `monthly-compress` | 1st of the month | `Bulk_Compress_GCS_Files` (classic) | created `PAUSED` |
| `events-stream` | – | `PubSub_to_BigQuery_Flex` | no schedule: a streaming pipeline |

The pipeline type is `BATCH` when there is a `schedule` and `STREAMING` otherwise, unless `type` says differently.

Worker settings are written once as a YAML anchor in `defaults.jobs` and merged into `defaults.pipelines` with `<<: *workers`.

Data Pipelines depends on Cloud Scheduler and needs an App Engine region. The scheduler service account needs permission to launch Dataflow jobs and to act as the worker service account; see the [Data Pipelines documentation](https://cloud.google.com/dataflow/docs/guides/data-pipelines).

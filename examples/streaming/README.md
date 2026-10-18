# Streaming example

Three streaming jobs from Google-provided Flex Templates, sharing defaults (worker service account, temp and staging locations, Streaming Engine, drain on delete, machine type):

| Job | Template | Shows |
|---|---|---|
| `orders-to-bigquery` | `PubSub_to_BigQuery_Flex` | subscription input, dead-letter table, 2–20 workers |
| `clicks-to-gcs` | `Cloud_PubSub_to_GCS_Text_Flex` | windowed files, bigger workers, an extra label |
| `audit-to-bigquery` | `PubSub_to_BigQuery_Flex`, pinned version | other region, `transform_name_mapping` for in-place updates, experiments |

`google_template` expands to `gs://dataflow-templates-REGION/VERSION/flex/NAME`, using each job's own region.

The worker service account needs `roles/dataflow.worker`, read access to the subscriptions and topics, write access to the tables and buckets, and access to the temp and staging buckets.

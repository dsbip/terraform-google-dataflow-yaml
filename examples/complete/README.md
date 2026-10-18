# Complete example

Every configuration key the module supports, across five jobs and five pipelines (one of each disabled). `tests/python/test_schema.py` fails if a key is ever missing here.

| Entry | Highlights |
|---|---|
| `orders-stream` (job `orders-to-bq`) | Google Flex Template pinned to a version, every Flex-only and common setting, private IPs, CMEK, `PREVENT` deletion |
| `scoring` | own Flex Template in another project and region |
| `dedupe` | own classic template with a zone; the Flex-only `num_workers` default is not applied |
| `word-count` | Google classic template |
| `daily-load` (pipeline `daily_load`) | every pipeline key for Flex Templates: display name, explicit type and state, job name, launch options, FlexRS, worker region, pipeline sources |
| `monthly-compress` | classic template pipeline with a zone and `bypass_temp_dir_validation` |
| `events` | streaming pipeline with in-place `update` and a transform mapping |
| `weekly-report` | classic pipeline in another project, paused, worker zone |
| `retired-job`, `retired-pipeline` | `enabled: false` |

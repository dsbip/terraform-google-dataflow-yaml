# Custom Flex Templates example

Runs your own templates:

| Job | Template | Shows |
|---|---|---|
| `enrich-customers` | Python Flex Template | custom SDK container image, launcher machine type, fixed 8 workers (`AUTOSCALING_ALGORITHM_NONE`), pipeline options, staging location, numeric and boolean parameters |
| `fraud-scoring` | Java streaming Flex Template | Streaming Engine, `create_ignore_already_exists`, `cancel` with `skip_wait_on_job_termination` |
| `nightly-dedupe` | classic template | worker zone (classic only) |

The release is a template variable used in spec paths, the worker image and a label, so a rollout is `terraform apply -var release=3.3.0`. Which changes update a running streaming job in place and which start a new job is decided by the provider (see its documentation for `google_dataflow_flex_template_job` and `google_dataflow_job`); a replaced streaming job is drained or cancelled according to `on_delete`.

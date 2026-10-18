# Troubleshooting

## The plan fails with "The Dataflow YAML configuration has N problem(s)"

That is the module's validation: each line starts with the YAML path of the problem. Nothing is planned until all of them are fixed. See [configuration.md](configuration.md#validation).

## A batch job is launched again on every apply

That is how the provider treats finished batch jobs: a job in a terminal state is removed from the state, so the next apply creates it again. Use a [pipeline](pipelines.md) for recurring batch work, or remove the job from the file (or set `enabled: false`) after it has run.

## `Error: ... google-beta` or "provider configuration not present"

Flex Template jobs use the google-beta provider. Configure it in the calling module (`provider "google-beta" { project = ... }`), next to `provider "google"`.

## The job fails with a template parameter error

Parameters are passed as strings to the template. Check names and values against the template's documentation (Google-provided templates: the [template reference](https://cloud.google.com/dataflow/docs/guides/templates/provided-templates)); `google_template.version` pins a release whose parameters you have checked.

## Workers with private IPs cannot start

`ip_configuration: WORKER_IP_PRIVATE` needs Private Google Access on the subnetwork. With Shared VPC, use the full subnetwork URL and grant `roles/compute.networkUser` to the Dataflow service agent and the worker service account.

## A key turned into `true` or `false`

Terraform's YAML parser reads unquoted `yes`, `no`, `on`, `off`, `true` and `false` as booleans, also as keys. Quote the key (`"on":`) or pick another name.

## `Invalid template interpolation value` or `vars map does not contain key`

`config_file` is rendered with `templatefile()`. Every `${name}` needs a value in `template_vars`. Templates for Dataflow sometimes use `${...}` themselves (e.g. in a parameter value): write `$${...}` for a literal `${`.

## Destroy waits a long time

Streaming jobs are drained by default when `on_delete: drain`. Use `on_delete: cancel` (and optionally `skip_wait_on_job_termination: true`) for jobs whose in-flight data may be dropped.

## Pipelines fail to create in a region

Data Pipelines depends on Cloud Scheduler and is only available in App Engine regions. Choose such a region for the pipeline; `worker_region` can still place the workers elsewhere.

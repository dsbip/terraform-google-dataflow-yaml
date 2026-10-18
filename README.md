# terraform-google-dataflow-yaml

[![CI](https://github.com/dsbip/terraform-google-dataflow-yaml/actions/workflows/ci.yml/badge.svg)](https://github.com/dsbip/terraform-google-dataflow-yaml/actions/workflows/ci.yml)

A Terraform module that launches any number of **Dataflow jobs** and **Data Pipelines** from one YAML file:

- **Jobs** from classic templates and Flex Templates: your own (`template_gcs_path`, `container_spec_gcs_path`) or Google-provided ones by name (`google_template: { name: PubSub_to_BigQuery_Flex }`)
- **Data Pipelines**: templates launched on a cron schedule (batch) or kept as streaming pipelines, with time zones, pause/resume and FlexRS
- **Workers**: machine types, autoscaling bounds, fixed worker pools, Streaming Engine, experiments and pipeline options, custom SDK images, launcher machine types
- **Networking and security**: private worker IPs, Shared VPC subnetworks, CMEK, dedicated worker and scheduler service accounts, worker regions and zones
- **Lifecycle**: drain or cancel on delete, in-place streaming updates with transform name mappings, adopting running jobs, deletion protection
- **Defaults** for jobs and pipelines, merged three levels deep and applied only where they fit the template type, plus `${...}` templating, `%{ if }` blocks and YAML anchors for one file across environments

The module catches mistakes before anything reaches Google Cloud: a misspelled key fails the plan with its YAML path and a suggestion, for example `jobs.orders: unknown key "machine" (did you mean machine_type?)`, and a setting that doesn't exist for the template type is reported too (`jobs.dedupe.num_workers: only available for Flex Templates`).

```yaml
# dataflow.yaml
defaults:
  region: europe-west1
  jobs:
    service_account_email: dataflow@my-project.iam.gserviceaccount.com
    temp_location: gs://my-project-dataflow/tmp

jobs:
  orders-to-bigquery:                       # streaming, keeps running
    google_template: { name: PubSub_to_BigQuery_Flex }
    parameters:
      inputSubscription: projects/my-project/subscriptions/orders
      outputTableSpec: my-project:sales.orders
    enable_streaming_engine: true
    max_workers: 10

pipelines:
  nightly-export:                           # batch, every night at 02:00
    schedule: "0 2 * * *"
    google_template: { name: BigQuery_to_Parquet }
    parameters:
      tableRef: my-project:sales.orders
      bucket: gs://my-project-exports/orders/
```

```hcl
module "dataflow" {
  source = "github.com/dsbip/terraform-google-dataflow-yaml?ref=v1.0.0"

  project_id  = "my-project"
  config_file = "${path.module}/dataflow.yaml"
}
```

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Usage](#usage)
- [Jobs or pipelines?](#jobs-or-pipelines)
- [Module structure](#module-structure)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Examples](#examples)
- [Documentation](#documentation)
- [Testing](#testing)

## Features

| Area | What the YAML covers | Docs |
|---|---|---|
| File | `project_id`, `defaults` (region, labels, jobs, pipelines), templating, YAML anchors, `enabled` | [configuration.md](docs/configuration.md) |
| Templates | own classic and Flex Templates, Google-provided templates by name and version | [jobs.md](docs/jobs.md#templates) |
| Jobs | parameters, labels, temp and staging locations, workers, networking, CMEK, Streaming Engine, experiments, Flex launcher and SDK image, autoscaling, update and deletion behaviour | [jobs.md](docs/jobs.md) |
| Pipelines | batch and streaming, schedules with time zones, state, scheduler service account, job names, launch options, FlexRS, worker regions, in-place updates | [pipelines.md](docs/pipelines.md) |
| Validation | unknown keys, types, enumerations, ranges, `gs://` paths, names, exactly one template, keys that don't apply to the template type, schedules only for batch, duplicates: all at once with YAML paths | [configuration.md](docs/configuration.md#validation) |

## Requirements

| | Version |
|---|---|
| Terraform | >= 1.5 (the unit tests need >= 1.7) |
| `hashicorp/google` provider | >= 7.42, < 9.0 |
| `hashicorp/google-beta` provider | >= 7.42, < 9.0 (Flex Template jobs exist only in google-beta) |

Configure both providers in the calling module (`provider "google" {}` and `provider "google-beta" {}`). APIs: Dataflow; Data Pipelines and Cloud Scheduler for pipelines. Buckets, topics, tables, networks, keys and service accounts referenced in the YAML must already exist.

## Usage

1. Write a YAML file (start from an [example](examples/README.md)). For autocompletion and validation in editors with the YAML language server:

   ```yaml
   # yaml-language-server: $schema=<path to>/schemas/dataflow-config.schema.json
   ```

2. Call the module with `config_file` (rendered with `templatefile()`) or `config_yaml` (used as-is):

   ```hcl
   module "dataflow" {
     source = "github.com/dsbip/terraform-google-dataflow-yaml?ref=v1.0.0"

     project_id    = var.project_id
     region        = "europe-west1"
     config_file   = "${path.module}/dataflow.yaml"
     template_vars = { env = "prod" }
     labels        = { managed-by = "terraform" }
   }
   ```

3. `terraform plan`. If the file has problems, the plan fails with all of them:

   ```text
   The Dataflow YAML configuration has 3 problem(s):
     - jobs.orders: unknown key "machine" (did you mean machine_type?)
     - jobs.dedupe: temp_location is required for classic templates
     - pipelines.events: schedule is only for batch pipelines (type is STREAMING)
   ```

## Jobs or pipelines?

| | `jobs` | `pipelines` |
|---|---|---|
| Streaming | the job runs until it is destroyed; changes update or replace it | a streaming Data Pipeline |
| Batch | launched by `terraform apply`. **A finished batch job is removed from the state by the provider, so the next apply launches it again** | launched by Cloud Scheduler on `schedule`, independent of Terraform runs |
| Use for | streaming jobs; one-off batch runs | recurring batch work |

## Module structure

```text
root module (this directory)          YAML → validated, merged, normalised inputs
  │  main.tf        load + template + defaults merge, template type, Google template paths
  │  validation.tf  schema-driven checks + rules, gate for_each
  │  jobs.tf        module "classic_job" / "flex_job" { for_each = jobs of that type }
  │  pipelines.tf   module "pipeline"    { for_each = pipelines }
  ▼
modules/classic-job   google_dataflow_job
modules/flex-job      google_dataflow_flex_template_job (google-beta)
modules/pipeline      google_data_pipeline_pipeline
```

Each submodule deploys one resource from typed HCL inputs and works without YAML, as in [examples/standalone-modules](examples/standalone-modules). [`schemas/dataflow-config.schema.json`](schemas/dataflow-config.schema.json) is the YAML format, used by editors and by `validation.tf`. See [docs/design.md](docs/design.md).

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `config_file` | Path to the YAML file, rendered with `templatefile()`. Exactly one of `config_file` and `config_yaml`. | `string` | `null` |
| `config_yaml` | YAML as a string, used as-is. | `string` | `null` |
| `template_vars` | Values for placeholders in `config_file`. `project_id` and `region` are always available. | `any` | `{}` |
| `project_id` | Default project. The YAML's top-level `project_id` and an entry's own `project_id` take precedence. | `string` | `null` |
| `region` | Default region. `defaults.region` and an entry's own `region` take precedence. | `string` | `null` |
| `labels` | Labels added to every job and to the jobs of every pipeline; YAML labels win on conflicts. | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `jobs` | Per YAML key: `id`, `job_id`, `name`, `project_id`, `region`, `state`, `type`, `template_type` (`classic` or `flex`), `template` |
| `pipelines` | Per YAML key: `id`, `name`, `project_id`, `region`, `job_name`, `type`, `state`, `template_type`, `template`, `next_job_time` |
| `job_ids` | YAML key → Dataflow job ID |
| `config` | The normalised configuration (after defaults) of every job and pipeline, including disabled ones. |

## Examples

| Example | Shows |
|---|---|
| [basic](examples/basic) | Google's Word Count classic template |
| [streaming](examples/streaming) | three streaming Flex Template jobs: Pub/Sub to BigQuery and to Cloud Storage, pinned versions, in-place updates |
| [batch-pipelines](examples/batch-pipelines) | scheduled Data Pipelines: daily, weekly, monthly (paused), FlexRS, a streaming pipeline, YAML anchors |
| [custom-flex-templates](examples/custom-flex-templates) | your own Flex and classic templates: SDK image, launcher, fixed workers, pipeline options |
| [secure-networking](examples/secure-networking) | private IPs, Shared VPC, CMEK, dedicated service accounts, worker regions and zones, deletion protection |
| [multi-environment](examples/multi-environment) | one file for dev, staging and prod |
| [complete](examples/complete) | every configuration key (checked by a test) |
| [standalone-modules](examples/standalone-modules) | the submodules from plain HCL |

## Documentation

- [docs/configuration.md](docs/configuration.md): file structure, templating, anchors, defaults and how they merge, precedence, validation
- [docs/jobs.md](docs/jobs.md): every key of a job, and the template types
- [docs/pipelines.md](docs/pipelines.md): every key of a pipeline
- [docs/design.md](docs/design.md), [docs/testing.md](docs/testing.md), [docs/troubleshooting.md](docs/troubleshooting.md)

## Testing

```bash
scripts/test.sh     # fmt, validate, 40+ terraform tests (mocked providers), schema/doc checks, real-provider plans of every example
```

A live test runs [tests/integration](tests/integration) in a real project (a small streaming job and, optionally, a paused pipeline), checks that a second plan is empty and destroys everything; see [docs/testing.md](docs/testing.md).

## License

Apache 2.0, see [LICENSE](LICENSE).

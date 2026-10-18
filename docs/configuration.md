# Configuration file

The configuration is one YAML mapping with four top-level keys, all optional:

```yaml
project_id: my-project        # default project of every job and pipeline

defaults:                     # applied underneath every entry
  region: europe-west1
  labels: { team: data }
  jobs: { ... }               # any job key except name
  pipelines: { ... }          # any pipeline key except name and job_name

jobs:                         # one entry per Dataflow job, keyed by a logical key
  orders-stream: { ... }

pipelines:                    # one entry per Data Pipeline
  nightly-export: { ... }
```

| Key | Description |
|---|---|
| `project_id` | Default project for every job and pipeline in the file. Overrides the module's `project_id` variable; an entry's own `project_id` overrides it. |
| `defaults` | Values every entry inherits, see [Defaults](#defaults). |
| `jobs` | Dataflow jobs keyed by logical key, see [jobs.md](jobs.md). |
| `pipelines` | Data Pipelines keyed by logical key, see [pipelines.md](pipelines.md). |

The key is the default name, the key of every output and part of every Terraform address (`module.flex_job["orders-stream"]`), so renaming a key replaces the job.

## Templating

`config_file` is rendered with Terraform's [`templatefile()`](https://developer.hashicorp.com/terraform/language/functions/templatefile) before it is parsed:

- `${name}` is replaced with a value from `template_vars`; `project_id` and `region` (the module variables) are always available;
- expressions work: `${env == "prod" ? 50 : 2}`;
- `%{ if cond ~}` ... `%{ endif ~}` and `%{ for x in list ~}` add or remove whole blocks;
- `$${` produces a literal `${`.

`config_yaml` is used as-is. Values must be known at plan time.

To keep a templated file valid YAML *before* rendering (for editors and the JSON Schema), quote placeholders that contain `: `, quotes or braces, and quote `${...}` inside flow collections:

```yaml
machine_type: '${env == "prod" ? "n2-standard-4" : "e2-standard-2"}'
parameters: { table: "${project_id}:sales.orders" }
```

## YAML anchors

Settings shared by jobs and pipelines can be written once with an anchor and merged with `<<:`:

```yaml
defaults:
  jobs: &workers
    service_account_email: dataflow@my-project.iam.gserviceaccount.com
    temp_location: gs://my-project-dataflow/tmp
    ip_configuration: WORKER_IP_PRIVATE
  pipelines:
    <<: *workers
    time_zone: Europe/Berlin
```

## Defaults

| Key | Description |
|---|---|
| `region` | Default region. Overrides the module's `region` variable; an entry's `region` (or `defaults.jobs.region` / `defaults.pipelines.region`) overrides it. |
| `labels` | Labels added to every job and to the jobs of every pipeline, over the module's `labels` variable. |
| `jobs` | Any job key except `name`, merged underneath every job. |
| `pipelines` | Any pipeline key except `name` and `job_name`, merged underneath every pipeline. |

### How defaults merge

Defaults are merged **three levels deep**: entry keys (`machine_type`, `parameters`), keys of nested mappings (`parameters.inputTopic`, `labels.team`, `google_template.version`), and keys inside those. The entry's value always wins; mappings merge; **lists** (`additional_experiments`, `additional_pipeline_options`) **are replaced**; empty keys never override a default.

**Defaults that don't fit an entry's template type are left out for that entry.** A `num_workers` default (Flex Templates only) is not applied to classic jobs, and a `zone` default (classic only) is not applied to Flex Template jobs. Only keys an entry sets itself are reported when they don't fit.

Labels merge in this order, later wins: module `labels` → `defaults.labels` → `defaults.jobs.labels` / `defaults.pipelines.labels` → entry `labels`.

## Precedence

| Setting | Highest → lowest |
|---|---|
| project | entry `project_id` → `defaults.jobs`/`defaults.pipelines` `project_id` → top-level `project_id` → module `project_id` |
| region | entry `region` → `defaults.jobs`/`defaults.pipelines` `region` → `defaults.region` → module `region` |
| name | entry `name` → YAML key |

## Enabling and disabling

`enabled: false` keeps an entry in the file without launching it; it is still validated. With templating: `enabled: ${env == "dev"}`.

## Validation

Before anything is planned, the module checks the whole file and reports every problem at once, each prefixed with its YAML path. While there are problems, nothing is planned.

Driven by the [JSON Schema](../schemas/dataflow-config.schema.json):

- unknown keys, with suggestions for likely typos (a pipeline-only key such as `schedule` on a job is unknown there);
- types, enumerations (`ip_configuration`, `on_delete`, `autoscaling_algorithm`, `type`, `state`, `flexrs_goal`, ...), ranges (`max_workers`, `num_workers`);
- patterns: job names, pipeline IDs, `gs://` paths for templates and temp and staging locations;
- required keys (`google_template.name`).

Rules beyond the schema, checked after defaults are merged:

- a project and a region must be determinable; the key must be a valid name unless `name` is set; keys that YAML read as booleans are reported;
- exactly one of `template_gcs_path`, `container_spec_gcs_path` and `google_template`;
- keys an entry sets that don't exist for its template type (e.g. `num_workers` on a classic job, `zone` on a Flex Template job, `launch_options` on a classic pipeline);
- classic jobs need `temp_location`; `num_workers` ≤ `max_workers`;
- pipelines: `schedule` and `flexrs_goal` only for batch pipelines, `time_zone` only with `schedule`, and a valid job name when it is derived from the pipeline ID;
- no two enabled jobs (classic and Flex share one namespace) or pipelines with the same project, region and name; `name` (and `job_name` for pipelines) cannot be a default.

The submodules validate their own inputs too.

## YAML gotchas

- Terraform's `yamldecode()` reads unquoted `yes`, `no`, `on`, `off`, `true` and `false` as booleans, also as keys. Quote such keys (`"on":`).
- Values that look like numbers become numbers (`version: 1.10` is `1.1`); template parameters are converted to strings, so quote them when the exact text matters.
- BigQuery table specs (`project:dataset.table`) are fine unquoted in block style, but must be quoted inside flow mappings and when they contain a placeholder: `{ table: "${project_id}:sales.orders" }`.

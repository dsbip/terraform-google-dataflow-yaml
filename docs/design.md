# Design

## Flow of a configuration

```text
config_file ──templatefile()──┐
config_yaml ──────────────────┴─▶ yamldecode ─▶ local.config_decoded
                                                   │
                     ┌─────────────────────────────┤
                     ▼                             ▼
            validation.tf part 1          main.tf: drop nulls, merge
            walk YAML + JSON Schema       defaults.jobs / defaults.pipelines
            (raw values, exact paths)     (3 levels); template type; drop
                     │                    defaults of the other type; Google
                     │                    template paths; project, region, labels
                     │                             │
                     │                    validation.tf part 2: rules on the
                     │                    merged entries
                     ▼                             │
            local.validation_errors ◀──────────────┘
                     │
        config_valid ├──▶ terraform_data.validation (precondition lists all errors)
                     ▼
            jobs.tf:      module "classic_job" / "flex_job" { for_each = jobs of that type }
            pipelines.tf: module "pipeline"                  { for_each = pipelines }
```

## Decisions

**One `jobs` map for both template types.** Users think in jobs, not in provider resources. The template key decides the type (`template_gcs_path` → classic, `container_spec_gcs_path` → Flex, `google_template` → `type`), and the root module dispatches to `modules/classic-job` (google) or `modules/flex-job` (google-beta). Both share one name namespace, like Dataflow itself.

**Type-aware defaults.** Several settings exist for only one template type (`num_workers`, `launcher_machine_type`, ... for Flex; `zone` for classic jobs). A default for one type is left out for entries of the other type, so one `defaults.jobs` block serves both; only keys an entry sets itself are reported when they don't fit.

**Google-provided templates by name.** `google_template` expands to the documented `gs://dataflow-templates-REGION/VERSION/[flex/]NAME` path with the entry's own region, so a job moves regions without editing paths, and a `version` pins a release.

**Pipelines for recurring batch work.** A finished batch job drops out of the Terraform state, so `jobs` relaunches batch work on every apply. Data Pipelines launch jobs from Cloud Scheduler instead. Their YAML uses the same keys as jobs for the template and workers; the module builds the provider's nested `workload.*_request.launch_parameter(s).environment` blocks, maps `labels` to `additional_user_labels`, derives `job_name`, `display_name` and `type`, and expands short forms of `type` and `state`.

**The schema is the single source of truth.** `validation.tf` reads allowed keys, types, enumerations, ranges and patterns from `schemas/dataflow-config.schema.json` at plan time; editors use the same file. Tests keep the schema readable by the Terraform walker and its patterns valid for RE2 (Terraform's regular expression engine rejects repetition counts above 1000).

**Report everything, plan nothing.** All problems are collected with YAML paths, and every module's `for_each` is empty until there are none; the precondition on `terraform_data.validation` then fails the plan with the complete list.

**Typed submodules.** Each submodule wraps one resource with strict, typed variables and its own validation, so it is useful without YAML.

## Compatibility rules for the code

- Terraform 1.5: no functions newer than 1.5; `&&` and `||` do not short-circuit before 1.12, so every operand must be safe on its own; `jsonencode(null)` fails before 1.9, so it is always wrapped in `try()`.
- Conditionals must not mix object types that hold YAML values; use `for ... if` filters instead.
- Never pass a possibly-null value to `contains()`; never let a null reach `${...}` interpolation.

# Testing

The module is tested in four layers. The first three need no Google Cloud access and run in CI on every push; the live test runs on demand.

| Layer | Tool | What it proves | Where |
|---|---|---|---|
| Static | `terraform fmt`, `terraform validate` | Formatting; valid HCL against the provider schemas, for the root module and the three submodules | |
| Unit | `terraform test` with mocked providers | Loading and templating, anchors, precedence, type-aware defaults, template dispatch and Google template paths, every attribute from YAML to the planned job and pipeline, outputs, the submodules on their own, every validation message, every example | `tests/*.tftest.hcl` (40+ runs) |
| Plan | pytest + real provider, dummy credentials | Every example and the live fixture pass the real provider's validation and plan logic with the expected resource count; examples and fixtures match the JSON Schema; the schema stays readable by `validation.tf`; the complete example uses every key; every key is documented; links resolve | `tests/python/` |
| Live | pytest + real providers, real project | A streaming job launches, a second plan is empty (no drift), a pipeline updates in place, destroy is clean | `tests/python/test_live.py`, `tests/integration/` |

## Requirements

- Terraform >= 1.7 for the unit tests (mock providers); the module itself supports >= 1.5
- Both the google and the google-beta provider are downloaded
- Python >= 3.9 with `pip install -r tests/python/requirements.txt` (pytest, PyYAML, jsonschema)
- Network access to download providers

## Running the tests

Everything offline, in one command:

```bash
scripts/test.sh
```

Or step by step from the repository root:

```bash
terraform fmt -check -recursive
terraform init -backend=false && terraform validate
terraform test                                    # unit tests
python -m pytest tests/python -v                  # schema, docs and real-provider plans
```

A single unit test file: `terraform test -filter=tests/validation.tftest.hcl`.

To check the minimum versions, run the plan tests with Terraform 1.5.7 and pin the provider:

```bash
TERRAFORM_BIN=/path/to/terraform-1.5.7 GOOGLE_PROVIDER_VERSION=7.42.0 python -m pytest tests/python -v
```

## Unit tests

| File | Covers |
|---|---|
| `config.tftest.hcl` | `config_file` templating (placeholders, `%{ if }`, `$${`), `config_yaml`, `yamlencode()`, blank files, precedence, labels, the three-level and type-aware defaults merge, YAML anchors, nulls, names, `enabled` |
| `jobs.tftest.hcl` | dispatch to classic and Flex modules, Google template paths (type, version, region), every classic and Flex job attribute |
| `pipelines.tftest.hcl` | Flex and classic pipelines with every setting, the launch request and environment, type inference, short and long forms of type and state |
| `modules.tftest.hcl` | the three submodules called directly, with their input validation and preconditions |
| `validation.tftest.hcl` | every validation message, as complete sets; defaults of the other template type are not errors |
| `examples.tftest.hcl` | the behaviour each example's README describes |
| `outputs.tftest.hcl` | outputs after a mocked apply |

Validation tests plant several mistakes and compare the complete set of messages, so a missing message and a spurious extra one both fail:

```hcl
run "rules_beyond_the_schema" {
  command         = plan
  variables { config_yaml = <<-EOT ... EOT }
  expect_failures = [terraform_data.validation]
  assert {
    condition = toset(local.validation_errors) == toset([
      "jobs.two-templates: set exactly one of template_gcs_path, container_spec_gcs_path and google_template (found template_gcs_path, container_spec_gcs_path)",
      ...
    ])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}
```

## Plan tests

`test_example_plans.py` copies the repository to a temporary directory and runs `terraform init` and `terraform plan -refresh=false` in every example with a dummy `GOOGLE_OAUTH_ACCESS_TOKEN`. The provider needs no API calls to plan new resources, so the plans exercise its full validation and diff logic offline. Each test checks the exact number of planned resources. The live-test fixture is planned the same way with every option enabled, so it stays deployable.

## Live test

The live test deploys `tests/integration/` into a real project: a bucket, a Pub/Sub topic and a streaming job from Google's `Cloud_PubSub_to_GCS_Text_Flex` template (one `e2-standard-2` worker, cancelled on destroy), and, if enabled, a paused Data Pipeline. It then runs:

1. `apply`
2. `plan -detailed-exitcode` must report no changes (catches permanent diffs)
3. `apply` with a changed pipeline display name and schedule (in-place update)
4. another empty plan
5. `destroy` (always, also after a failure)

A streaming job is used on purpose: a batch job would drop out of the state when it finishes and make step 2 depend on timing. The worker runs only for the few minutes the test takes; the pipeline is paused and launches nothing.

```bash
gcloud auth application-default login
export DF_YAML_TEST_PROJECT=my-sandbox-project
export DF_YAML_TEST_REGION=europe-west1        # optional
export DF_YAML_TEST_PIPELINES=true             # optional: needs the Data Pipelines API
python -m pytest tests/python/test_live.py -v
```

The project needs the Dataflow, Pub/Sub and Cloud Storage APIs (and Data Pipelines and Cloud Scheduler for the pipeline). The identity needs `roles/dataflow.admin`, `roles/storage.admin`, `roles/pubsub.admin`, `roles/iam.serviceAccountUser` on the worker service account (the Compute Engine default service account in this fixture) and `roles/datapipelines.admin` for the pipeline. If a run is interrupted before its destroy step, cancel the leftover `dfyaml-*` job and delete the bucket, topic and pipeline by hand.

The **Live test** workflow runs the same test from GitHub Actions. To enable it:

1. Create a Workload Identity Federation provider for the repository.
2. Set the repository variables `DF_YAML_TEST_PROJECT`, `GCP_WORKLOAD_IDENTITY_PROVIDER` and `GCP_SERVICE_ACCOUNT`.
3. Start the workflow from the Actions tab.

## Continuous integration

`.github/workflows/ci.yml` runs on pushes to `main` and on pull requests:

| Job | Terraform | Provider |
|---|---|---|
| fmt and validate | latest | latest |
| terraform test | 1.7.5, latest | 7.42.0, latest (4 combinations, google and google-beta pinned together) |
| example plans, schema and docs tests | 1.5.7 with 7.42.0 (the minimums), latest with latest | |

## Adding a feature

1. Add the key to the `job` or `pipeline` definition in `schemas/dataflow-config.schema.json` (with a description; enumerations, ranges and patterns are enforced automatically). If it exists for one template type only, add it to `local.only_for` in `main.tf`.
2. Add it to the submodule's variables and pass it to the resource.
3. Add a rule to `validation.tf` part 2 if invalid combinations are possible, with a message that starts with the YAML path.
4. Add a unit test for the planned attribute, and a validation test if you added a rule.
5. Use it in `examples/complete` and document it in `docs/jobs.md` or `docs/pipelines.md` (tests fail otherwise).

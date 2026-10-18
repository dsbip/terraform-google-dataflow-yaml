# Validation: each run plants several mistakes and compares the complete set
# of messages, so a missing message and a spurious extra one both fail.

mock_provider "google" {}
mock_provider "google-beta" {}

variables {
  project_id = "test-project"
  region     = "europe-west1"
}

run "schema_checks_keys_types_enums_patterns_ranges_and_required_keys" {
  command = plan

  variables {
    config_yaml = <<-EOT
      job:
        x: {}
      defaults:
        pipeline: {}
        jobs:
          machine: n1
      jobs:
        api:
          template_path: gs://x
          container_spec_gcs_path: s3://bucket/spec.json
          max_workers: 0
          num_workers: 5000
          ip_configuration: PRIVATE
          on_delete: DRAIN
          enable_streaming_engine: maybe
          parameters: { a: [1] }
          additional_experiments: x
          temp_location: /tmp
          google_template: { nme: x }
      pipelines:
        p:
          type: CRON
          state: STOPPED
          flexrs_goal: CHEAP
          job_name: Bad_Name
          name: "bad name"
          container_spec_gcs_path: gs://t/spec.json
          labels: [a]
    EOT
  }

  expect_failures = [terraform_data.validation]

  assert {
    condition = toset(local.validation_errors) == toset([
      "(root): unknown key \"job\" (did you mean jobs?)",
      "defaults: unknown key \"pipeline\" (did you mean pipelines?)",
      "jobs.api: unknown key \"template_path\" (did you mean temp_location or template_gcs_path?)",
      "defaults.jobs: unknown key \"machine\" (did you mean machine_type?)",
      "jobs.api.google_template: unknown key \"nme\"",
      "jobs.api.additional_experiments: must be a list",
      "jobs.api.enable_streaming_engine: must be true or false",
      "pipelines.p.labels: must be a mapping",
      "jobs.api.parameters.a: must be a string",
      "jobs.api.ip_configuration: must be one of WORKER_IP_PUBLIC, WORKER_IP_PRIVATE (got \"PRIVATE\")",
      "jobs.api.on_delete: must be one of drain, cancel (got \"DRAIN\")",
      "pipelines.p.flexrs_goal: must be one of FLEXRS_UNSPECIFIED, FLEXRS_SPEED_OPTIMIZED, FLEXRS_COST_OPTIMIZED (got \"CHEAP\")",
      "pipelines.p.state: must be one of ACTIVE, PAUSED, STATE_ACTIVE, STATE_PAUSED (got \"STOPPED\")",
      "pipelines.p.type: must be one of BATCH, STREAMING, PIPELINE_TYPE_BATCH, PIPELINE_TYPE_STREAMING (got \"CRON\")",
      "jobs.api.container_spec_gcs_path: \"s3://bucket/spec.json\" is not valid (Flex Template: gs:// path of the template spec file)",
      "jobs.api.temp_location: \"/tmp\" is not valid (gs:// path for temporary files. Required for classic templates)",
      "pipelines.p.job_name: \"Bad_Name\" is not valid (Name of the launched jobs (default: the pipeline ID in lowercase, with underscores as hyphens))",
      "pipelines.p.name: \"bad name\" is not valid (Pipeline ID (default: the key): letters, digits, hyphens and underscores)",
      "jobs.api.max_workers: must be at least 1",
      "jobs.api.num_workers: must be at most 4000",
      "jobs.api.google_template: missing required key \"name\"",
      "jobs.api: set exactly one of template_gcs_path, container_spec_gcs_path and google_template (found container_spec_gcs_path, google_template)",
      "jobs.api: num_workers (5000) is greater than max_workers (0)",
    ])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
  assert {
    condition     = length(module.classic_job) + length(module.flex_job) + length(module.pipeline) == 0
    error_message = "Nothing may be planned while the configuration is invalid."
  }
}

run "rules_beyond_the_schema" {
  command = plan

  variables {
    project_id  = null
    region      = null
    config_yaml = <<-EOT
      defaults:
        jobs: { name: shared }
        pipelines: { job_name: shared }
      jobs:
        Bad_Key: {}
        two-templates:
          project_id: p
          region: r
          template_gcs_path: gs://t/a
          container_spec_gcs_path: gs://t/b
        classic-without-temp:
          project_id: p
          region: r
          template_gcs_path: gs://t/a
          num_workers: 2
          launcher_machine_type: n2
        flex-with-zone:
          project_id: p
          region: r
          container_spec_gcs_path: gs://t/b
          zone: z
          num_workers: 10
          max_workers: 2
        dup-a: { name: same, project_id: p, region: r, container_spec_gcs_path: gs://t/b }
        dup-b: { name: same, project_id: p, region: r, template_gcs_path: gs://t/a, temp_location: gs://t/tmp }
      pipelines:
        streaming-with-schedule:
          project_id: p
          region: r
          type: STREAMING
          schedule: "0 1 * * *"
          flexrs_goal: FLEXRS_COST_OPTIMIZED
          container_spec_gcs_path: gs://t/b
        tz-only:
          project_id: p
          region: r
          time_zone: UTC
          container_spec_gcs_path: gs://t/b
        classic-flex-keys:
          project_id: p
          region: r
          schedule: "0 1 * * *"
          template_gcs_path: gs://t/a
          launch_options: { a: b }
          flexrs_goal: FLEXRS_SPEED_OPTIMIZED
        flex-classic-keys:
          project_id: p
          region: r
          container_spec_gcs_path: gs://t/b
          bypass_temp_dir_validation: true
        _x:
          project_id: p
          region: r
          container_spec_gcs_path: gs://t/b
        no-template:
          project_id: p
          region: r
        off:
          project_id: p
          region: r
          container_spec_gcs_path: gs://t/b
    EOT
  }

  expect_failures = [terraform_data.validation]

  # `off` became "false"; the module reports it.
  assert {
    condition = toset(local.validation_errors) == toset([
      "defaults.jobs: \"name\" cannot be a default",
      "defaults.pipelines: \"job_name\" cannot be a default",
      "jobs.Bad_Key: no project_id; set it here, at the top level of the file, or in the module's project_id variable",
      "jobs.Bad_Key: no region; set it here, in defaults.region, or in the module's region variable",
      "jobs.Bad_Key: the key is used as the name but is not a valid one (lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen); rename it or set name",
      "jobs.Bad_Key: set exactly one of template_gcs_path, container_spec_gcs_path and google_template",
      "jobs.classic-without-temp.num_workers: only available for Flex Templates (container_spec_gcs_path, or google_template)",
      "jobs.classic-without-temp.launcher_machine_type: only available for Flex Templates (container_spec_gcs_path, or google_template)",
      "jobs.classic-without-temp: temp_location is required for classic templates",
      "jobs.flex-with-zone.zone: only available for classic templates (template_gcs_path, or google_template with type: classic)",
      "jobs.flex-with-zone: num_workers (10) is greater than max_workers (2)",
      "jobs.two-templates: set exactly one of template_gcs_path, container_spec_gcs_path and google_template (found template_gcs_path, container_spec_gcs_path)",
      "pipelines._x: the job name derived from the pipeline ID (\"-x\") is not a valid job name; set job_name",
      "pipelines.classic-flex-keys.launch_options: only available for Flex Templates (container_spec_gcs_path, or google_template)",
      "pipelines.classic-flex-keys.flexrs_goal: only available for Flex Templates (container_spec_gcs_path, or google_template)",
      "pipelines.false: YAML reads unquoted yes, no, on, off, true and false as booleans; quote the key (e.g. \"on\":) or choose another name",
      "pipelines.flex-classic-keys.bypass_temp_dir_validation: only available for classic templates (template_gcs_path, or google_template with type: classic)",
      "pipelines.no-template: set exactly one of template_gcs_path, container_spec_gcs_path and google_template",
      "pipelines.streaming-with-schedule: schedule is only for batch pipelines (type is STREAMING)",
      "pipelines.streaming-with-schedule: flexrs_goal is only for batch pipelines",
      "pipelines.tz-only: time_zone needs schedule",
      "jobs: dup-a, dup-b would all create job p/r/same",
    ])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "defaults_for_the_other_template_type_are_not_errors" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        jobs:
          temp_location: gs://t/tmp
          num_workers: 2
          launcher_machine_type: n2-standard-2
          zone: europe-west1-b
        pipelines:
          launch_options: { a: b }
          bypass_temp_dir_validation: true
          time_zone: UTC
      jobs:
        classic: { template_gcs_path: gs://t/a }
        flex: { container_spec_gcs_path: gs://t/b }
      pipelines:
        classic: { template_gcs_path: gs://t/a, schedule: "0 1 * * *" }
        flex-streaming: { container_spec_gcs_path: gs://t/b }
    EOT
  }

  assert {
    condition     = length(local.validation_errors) == 0
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
  assert {
    condition = (
      local.jobs["classic"].num_workers == null && local.jobs["classic"].zone == "europe-west1-b" &&
      local.jobs["flex"].num_workers == 2 && local.jobs["flex"].zone == null &&
      local.pipelines["classic"].launch_options == null && local.pipelines["classic"].bypass_temp_dir_validation == true &&
      local.pipelines["flex-streaming"].bypass_temp_dir_validation == null
    )
    error_message = "Defaults should apply only where they fit."
  }
}

run "the_document_and_its_sections_must_be_mappings" {
  command = plan

  variables {
    config_yaml = "[jobs, pipelines]"
  }

  expect_failures = [terraform_data.validation]

  assert {
    condition     = local.validation_errors == tolist(["(root): the configuration must be a mapping (key: value pairs)"])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "sections_and_entries_with_the_wrong_type" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults: [region]
      jobs:
        job: just a string
      pipelines: [p]
    EOT
  }

  expect_failures = [terraform_data.validation]

  assert {
    condition = toset(local.validation_errors) == toset([
      "defaults: must be a mapping",
      "jobs.job: must be a mapping",
      "pipelines: must be a mapping",
    ])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "config_file_and_config_yaml_are_exclusive" {
  command = plan

  variables {
    config_file = "tests/fixtures/blank.yaml"
    config_yaml = "jobs: {}"
  }

  expect_failures = [terraform_data.validation]

  assert {
    condition     = local.validation_errors == tolist(["(module): set config_file or config_yaml, not both"])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "one_of_config_file_and_config_yaml_is_required" {
  command = plan

  expect_failures = [terraform_data.validation]

  assert {
    condition     = local.validation_errors == tolist(["(module): set config_file or config_yaml"])
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

run "config_file_must_exist" {
  command = plan

  variables {
    config_file = "tests/fixtures/missing.yaml"
  }

  expect_failures = [var.config_file]
}

run "a_valid_file_has_no_messages" {
  command = plan

  variables {
    config_file   = "tests/fixtures/templated.yaml"
    template_vars = { env = "prod" }
  }

  assert {
    condition     = length(local.validation_errors) == 0 && local.config_valid
    error_message = "Unexpected messages: ${jsonencode(local.validation_errors)}"
  }
}

# Loading the configuration: files, inline YAML, templating, precedence,
# defaults (also per template type), YAML anchors, names, enabled.

mock_provider "google" {}
mock_provider "google-beta" {}

variables {
  project_id = "test-project"
  region     = "europe-west1"
}

run "config_file_is_rendered_with_template_vars" {
  command = plan

  variables {
    config_file   = "tests/fixtures/templated.yaml"
    template_vars = { env = "dev" }
  }

  assert {
    condition     = toset(keys(module.flex_job)) == toset(["ingest-dev"]) && length(module.classic_job) == 0 && toset(keys(module.pipeline)) == toset(["nightly_dev"])
    error_message = "Expected ingest-dev and nightly_dev only."
  }
  assert {
    condition = (
      module.flex_job["ingest-dev"].job.parameters == tomap({ inputTopic = "projects/test-project/topics/in-dev" }) &&
      module.flex_job["ingest-dev"].job.temp_location == "gs://test-project-df/tmp" &&
      module.flex_job["ingest-dev"].job.labels == tomap({ environment = "dev" }) &&
      module.flex_job["ingest-dev"].job.region == "europe-west1"
    )
    error_message = "Placeholders, defaults and the region variable were not applied."
  }
  assert {
    condition     = local.jobs["ingest-dev"].max_workers == null
    error_message = "The %%{ if } block must not render in dev."
  }
}

run "template_directives_and_enabled_follow_the_variables" {
  command = plan

  variables {
    config_file   = "tests/fixtures/templated.yaml"
    template_vars = { env = "prod" }
  }

  assert {
    condition     = module.flex_job["ingest-prod"].job.max_workers == 50 && toset(keys(module.classic_job)) == toset(["literal"])
    error_message = "The %%{ if } block and enabled should follow env."
  }
  assert {
    condition     = module.classic_job["literal"].job.parameters["output"] == "gs://bucket/$${not_a_placeholder}"
    error_message = "$$${ must produce a literal $${."
  }
}

run "config_yaml_and_yamlencode" {
  command = plan

  variables {
    config_yaml = yamlencode({
      jobs = { job = { container_spec_gcs_path = "gs://t/spec.json", parameters = { a = "$${literal}" } } }
    })
  }

  assert {
    condition     = module.flex_job["job"].job.parameters["a"] == "$${literal}"
    error_message = "config_yaml must be used verbatim."
  }
}

run "blank_or_comment_only_file_creates_nothing" {
  command = plan

  variables {
    config_file = "tests/fixtures/blank.yaml"
  }

  assert {
    condition     = length(module.classic_job) + length(module.flex_job) + length(module.pipeline) == 0 && length(local.validation_errors) == 0
    error_message = "A comment-only file should be valid and create nothing."
  }
}

run "project_region_and_label_precedence" {
  command = plan

  variables {
    project_id  = "var-project"
    region      = "var-region"
    labels      = { managed-by = "terraform", layer = "var" }
    config_yaml = <<-EOT
      project_id: yaml-project
      defaults:
        region: defaults-region
        labels: { layer: defaults, team: data }
        pipelines:
          region: pipelines-region
      jobs:
        from-file:
          container_spec_gcs_path: gs://t/spec.json
          labels: { layer: job, count: 3 }
        own:
          project_id: own-project
          region: own-region
          container_spec_gcs_path: gs://t/spec.json
      pipelines:
        p:
          container_spec_gcs_path: gs://t/spec.json
    EOT
  }

  assert {
    condition     = module.flex_job["from-file"].project_id == "yaml-project" && module.flex_job["from-file"].region == "defaults-region"
    error_message = "The top-level project_id and defaults.region should override the variables."
  }
  assert {
    condition     = module.flex_job["own"].project_id == "own-project" && module.flex_job["own"].region == "own-region"
    error_message = "An entry's own project and region should win."
  }
  assert {
    condition     = module.pipeline["p"].region == "pipelines-region"
    error_message = "defaults.pipelines.region should override defaults.region."
  }
  assert {
    condition     = module.flex_job["from-file"].job.labels == tomap({ managed-by = "terraform", layer = "job", team = "data", count = "3" })
    error_message = "Unexpected labels: ${jsonencode(module.flex_job["from-file"].job.labels)}"
  }
}

run "defaults_merge_three_levels_and_per_template_type" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        jobs:
          temp_location: gs://t/tmp
          machine_type: n2-standard-2
          num_workers: 3                         # Flex only
          zone: europe-west1-b                   # classic only
          parameters: { shared: "1", over: default }
          additional_experiments: [a]
      jobs:
        flex:
          container_spec_gcs_path: gs://t/spec.json
          machine_type: n2-standard-8
          parameters: { over: own, extra: "2" }  # level 2 merge
          additional_experiments: [b]            # lists replace
        classic:
          template_gcs_path: gs://t/classic
        classic-with-own-zone:
          template_gcs_path: gs://t/classic
          zone: europe-west1-d
    EOT
  }

  assert {
    condition     = module.flex_job["flex"].job.machine_type == "n2-standard-8" && module.flex_job["flex"].job.temp_location == "gs://t/tmp"
    error_message = "Level 1: own machine type, temp_location from defaults."
  }
  assert {
    condition     = module.flex_job["flex"].job.parameters == tomap({ shared = "1", over = "own", extra = "2" })
    error_message = "Level 2: parameters should merge: ${jsonencode(module.flex_job["flex"].job.parameters)}"
  }
  assert {
    condition     = module.flex_job["flex"].job.additional_experiments == toset(["b"])
    error_message = "Lists must replace the default."
  }
  assert {
    condition     = module.flex_job["flex"].job.num_workers == 3 && local.jobs["flex"].zone == null
    error_message = "A Flex job takes the Flex-only default and leaves out the classic-only one."
  }
  assert {
    condition     = local.jobs["classic"].num_workers == null && module.classic_job["classic"].job.zone == "europe-west1-b"
    error_message = "A classic job takes the classic-only default and leaves out the Flex-only one."
  }
  assert {
    condition     = module.classic_job["classic-with-own-zone"].job.zone == "europe-west1-d"
    error_message = "An own zone should win."
  }
}

run "yaml_anchors_share_settings" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        jobs: &shared
          service_account_email: df@test-project.iam.gserviceaccount.com
          temp_location: gs://t/tmp
        pipelines:
          <<: *shared
          time_zone: Europe/Berlin
      jobs:
        j: { container_spec_gcs_path: gs://t/spec.json }
      pipelines:
        p: { container_spec_gcs_path: gs://t/spec.json, schedule: "0 1 * * *" }
    EOT
  }

  assert {
    condition = (
      module.flex_job["j"].job.service_account_email == "df@test-project.iam.gserviceaccount.com" &&
      module.pipeline["p"].pipeline.workload[0].dataflow_flex_template_request[0].launch_parameter[0].environment[0].service_account_email == "df@test-project.iam.gserviceaccount.com" &&
      module.pipeline["p"].pipeline.schedule_info[0].time_zone == "Europe/Berlin"
    )
    error_message = "Anchors and merge keys should share defaults."
  }
}

run "explicit_nulls_never_override_defaults" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        jobs:
          machine_type: n2-standard-2
          parameters: { a: "1" }
      jobs:
        j:
          container_spec_gcs_path: gs://t/spec.json
          machine_type:
          parameters:
            a:
    EOT
  }

  assert {
    condition     = module.flex_job["j"].job.machine_type == "n2-standard-2" && module.flex_job["j"].job.parameters == tomap({ a = "1" })
    error_message = "Empty keys must not override defaults."
  }
}

run "names_and_enabled" {
  command = plan

  variables {
    config_yaml = <<-EOT
      jobs:
        from-key: { container_spec_gcs_path: gs://t/spec.json }
        renamed: { name: actual-name, container_spec_gcs_path: gs://t/spec.json }
        disabled: { enabled: false, container_spec_gcs_path: gs://t/spec.json }
      pipelines:
        Daily_Export: { container_spec_gcs_path: gs://t/spec.json, schedule: "0 1 * * *" }
        off-pipeline: { enabled: "false", container_spec_gcs_path: gs://t/spec.json }
    EOT
  }

  assert {
    condition     = toset(keys(module.flex_job)) == toset(["from-key", "renamed"]) && toset(keys(module.pipeline)) == toset(["Daily_Export"])
    error_message = "Disabled entries must not be deployed."
  }
  assert {
    condition     = module.flex_job["from-key"].name == "from-key" && module.flex_job["renamed"].name == "actual-name"
    error_message = "The key is the default name."
  }
  assert {
    condition     = module.pipeline["Daily_Export"].job_name == "daily-export"
    error_message = "The job name is derived from the pipeline ID: ${module.pipeline["Daily_Export"].job_name}"
  }
}

# Jobs: dispatch to modules/classic-job or modules/flex-job, Google-provided
# template paths, and every attribute from YAML to the planned resource.

mock_provider "google" {}
mock_provider "google-beta" {}

variables {
  project_id = "test-project"
  region     = "europe-west1"
}

run "template_type_decides_the_module" {
  command = plan

  variables {
    config_yaml = <<-EOT
      defaults:
        jobs: { temp_location: gs://t/tmp }
      jobs:
        own-classic: { template_gcs_path: gs://t/classic/tpl }
        own-flex: { container_spec_gcs_path: gs://t/flex/spec.json }
        google-flex: { google_template: { name: PubSub_to_BigQuery_Flex } }
        google-flex-explicit: { google_template: { name: Cloud_PubSub_to_GCS_Text_Flex, type: flex, version: 2026-09-15-00_RC00 } }
        google-classic: { google_template: { name: Word_Count, type: classic } }
        google-elsewhere: { region: us-east1, google_template: { name: Word_Count, type: classic } }
    EOT
  }

  assert {
    condition = (
      toset(keys(module.classic_job)) == toset(["own-classic", "google-classic", "google-elsewhere"]) &&
      toset(keys(module.flex_job)) == toset(["own-flex", "google-flex", "google-flex-explicit"])
    )
    error_message = "Wrong dispatch: ${jsonencode({ classic = keys(module.classic_job), flex = keys(module.flex_job) })}"
  }
  assert {
    condition = (
      module.classic_job["own-classic"].job.template_gcs_path == "gs://t/classic/tpl" &&
      module.flex_job["own-flex"].job.container_spec_gcs_path == "gs://t/flex/spec.json"
    )
    error_message = "Own template paths must be used as-is."
  }
  assert {
    condition = (
      module.flex_job["google-flex"].job.container_spec_gcs_path == "gs://dataflow-templates-europe-west1/latest/flex/PubSub_to_BigQuery_Flex" &&
      module.flex_job["google-flex-explicit"].job.container_spec_gcs_path == "gs://dataflow-templates-europe-west1/2026-09-15-00_RC00/flex/Cloud_PubSub_to_GCS_Text_Flex" &&
      module.classic_job["google-classic"].job.template_gcs_path == "gs://dataflow-templates-europe-west1/latest/Word_Count" &&
      module.classic_job["google-elsewhere"].job.template_gcs_path == "gs://dataflow-templates-us-east1/latest/Word_Count"
    )
    error_message = "Google-provided template paths are wrong."
  }
}

run "classic_job_attributes" {
  command = plan

  variables {
    config_yaml = <<-EOT
      jobs:
        classic:
          name: classic-job
          project_id: other-project
          region: us-central1
          zone: us-central1-a
          template_gcs_path: gs://t/classic/tpl
          temp_location: gs://t/tmp
          parameters: { input: gs://in/*, limit: 10, dry_run: false }
          labels: { app: etl }
          service_account_email: df@other-project.iam.gserviceaccount.com
          network: vpc
          subnetwork: regions/us-central1/subnetworks/df
          machine_type: n2-standard-4
          max_workers: 8
          ip_configuration: WORKER_IP_PRIVATE
          kms_key_name: projects/p/locations/us-central1/keyRings/r/cryptoKeys/k
          additional_experiments: [use_runner_v2, enable_prime]
          enable_streaming_engine: true
          transform_name_mapping: { Old: New }
          on_delete: cancel
          skip_wait_on_job_termination: true
          deletion_policy: ABANDON
    EOT
  }

  assert {
    condition = (
      module.classic_job["classic"].job.name == "classic-job" &&
      module.classic_job["classic"].job.project == "other-project" &&
      module.classic_job["classic"].job.region == "us-central1" &&
      module.classic_job["classic"].job.zone == "us-central1-a" &&
      module.classic_job["classic"].job.temp_gcs_location == "gs://t/tmp"
    )
    error_message = "Wrong identity, location or temp location (temp_location → temp_gcs_location)."
  }
  assert {
    condition     = module.classic_job["classic"].job.parameters == tomap({ input = "gs://in/*", limit = "10", dry_run = "false" })
    error_message = "Parameters should be strings: ${jsonencode(module.classic_job["classic"].job.parameters)}"
  }
  assert {
    condition = (
      module.classic_job["classic"].job.labels == tomap({ app = "etl" }) &&
      module.classic_job["classic"].job.service_account_email == "df@other-project.iam.gserviceaccount.com" &&
      module.classic_job["classic"].job.network == "vpc" &&
      module.classic_job["classic"].job.subnetwork == "regions/us-central1/subnetworks/df" &&
      module.classic_job["classic"].job.machine_type == "n2-standard-4" &&
      module.classic_job["classic"].job.max_workers == 8 &&
      module.classic_job["classic"].job.ip_configuration == "WORKER_IP_PRIVATE" &&
      module.classic_job["classic"].job.kms_key_name == "projects/p/locations/us-central1/keyRings/r/cryptoKeys/k"
    )
    error_message = "Wrong worker settings."
  }
  assert {
    condition = (
      module.classic_job["classic"].job.additional_experiments == toset(["use_runner_v2", "enable_prime"]) &&
      module.classic_job["classic"].job.enable_streaming_engine == true &&
      module.classic_job["classic"].job.transform_name_mapping == tomap({ Old = "New" }) &&
      module.classic_job["classic"].job.on_delete == "cancel" &&
      module.classic_job["classic"].job.skip_wait_on_job_termination == true &&
      module.classic_job["classic"].job.deletion_policy == "ABANDON"
    )
    error_message = "Wrong experiments, streaming, mapping or deletion settings."
  }
}

run "flex_job_attributes" {
  command = plan

  variables {
    config_yaml = <<-EOT
      jobs:
        flex:
          container_spec_gcs_path: gs://t/flex/spec.json
          parameters: { topic: projects/p/topics/t }
          labels: { app: stream }
          temp_location: gs://t/tmp
          staging_location: gs://t/staging
          service_account_email: df@test-project.iam.gserviceaccount.com
          network: vpc
          subnetwork: regions/europe-west1/subnetworks/df
          machine_type: n2-standard-2
          max_workers: 20
          num_workers: 2
          ip_configuration: WORKER_IP_PUBLIC
          kms_key_name: projects/p/locations/europe-west1/keyRings/r/cryptoKeys/k
          additional_experiments: [enable_prime]
          additional_pipeline_options: [numberOfWorkerHarnessThreads=8]
          enable_streaming_engine: true
          launcher_machine_type: n2-standard-4
          sdk_container_image: europe-docker.pkg.dev/p/r/sdk:1
          autoscaling_algorithm: AUTOSCALING_ALGORITHM_NONE
          transform_name_mapping: { Old: New }
          on_delete: drain
          skip_wait_on_job_termination: false
          create_ignore_already_exists: true
          deletion_policy: PREVENT
    EOT
  }

  assert {
    condition = (
      module.flex_job["flex"].job.container_spec_gcs_path == "gs://t/flex/spec.json" &&
      module.flex_job["flex"].job.parameters == tomap({ topic = "projects/p/topics/t" }) &&
      module.flex_job["flex"].job.labels == tomap({ app = "stream" }) &&
      module.flex_job["flex"].job.temp_location == "gs://t/tmp" &&
      module.flex_job["flex"].job.staging_location == "gs://t/staging"
    )
    error_message = "Wrong template, parameters, labels or locations."
  }
  assert {
    condition = (
      module.flex_job["flex"].job.service_account_email == "df@test-project.iam.gserviceaccount.com" &&
      module.flex_job["flex"].job.network == "vpc" &&
      module.flex_job["flex"].job.subnetwork == "regions/europe-west1/subnetworks/df" &&
      module.flex_job["flex"].job.machine_type == "n2-standard-2" &&
      module.flex_job["flex"].job.max_workers == 20 &&
      module.flex_job["flex"].job.num_workers == 2 &&
      module.flex_job["flex"].job.ip_configuration == "WORKER_IP_PUBLIC" &&
      module.flex_job["flex"].job.kms_key_name == "projects/p/locations/europe-west1/keyRings/r/cryptoKeys/k"
    )
    error_message = "Wrong worker settings."
  }
  assert {
    condition = (
      module.flex_job["flex"].job.additional_experiments == toset(["enable_prime"]) &&
      module.flex_job["flex"].job.additional_pipeline_options == toset(["numberOfWorkerHarnessThreads=8"]) &&
      module.flex_job["flex"].job.enable_streaming_engine == true &&
      module.flex_job["flex"].job.launcher_machine_type == "n2-standard-4" &&
      module.flex_job["flex"].job.sdk_container_image == "europe-docker.pkg.dev/p/r/sdk:1" &&
      module.flex_job["flex"].job.autoscaling_algorithm == "AUTOSCALING_ALGORITHM_NONE"
    )
    error_message = "Wrong Flex-only settings."
  }
  assert {
    condition = (
      module.flex_job["flex"].job.transform_name_mapping == tomap({ Old = "New" }) &&
      module.flex_job["flex"].job.on_delete == "drain" &&
      module.flex_job["flex"].job.skip_wait_on_job_termination == false &&
      module.flex_job["flex"].job.create_ignore_already_exists == true &&
      module.flex_job["flex"].job.deletion_policy == "PREVENT"
    )
    error_message = "Wrong update or deletion settings."
  }
}

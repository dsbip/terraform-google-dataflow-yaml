# Every example configuration, planned with mocked providers. Each run checks
# the behaviour the example's README describes. (tests/python plans the same
# examples with the real providers.)

mock_provider "google" {}
mock_provider "google-beta" {}

variables {
  project_id = "example-project"
}

run "basic" {
  command = plan

  variables {
    region        = "europe-west1"
    config_file   = "examples/basic/config.yaml"
    template_vars = { bucket = "example-bucket" }
  }

  assert {
    condition = (
      toset(keys(module.classic_job)) == toset(["word-count"]) &&
      module.classic_job["word-count"].job.template_gcs_path == "gs://dataflow-templates-europe-west1/latest/Word_Count" &&
      module.classic_job["word-count"].job.temp_gcs_location == "gs://example-bucket/tmp"
    )
    error_message = "basic: one Word Count job."
  }
}

run "streaming" {
  command = plan

  variables {
    config_file = "examples/streaming/config.yaml"
    labels      = { managed-by = "terraform" }
  }

  assert {
    condition     = toset(keys(module.flex_job)) == toset(["orders-to-bigquery", "clicks-to-gcs", "audit-to-bigquery"])
    error_message = "streaming: three Flex Template jobs."
  }
  assert {
    condition = (
      module.flex_job["orders-to-bigquery"].job.max_workers == 20 &&
      module.flex_job["clicks-to-gcs"].job.max_workers == 10 &&
      alltrue([for j in values(module.flex_job) : j.job.enable_streaming_engine == true && j.job.on_delete == "drain"])
    )
    error_message = "streaming: shared defaults and overrides."
  }
  assert {
    condition = (
      module.flex_job["audit-to-bigquery"].job.region == "us-central1" &&
      module.flex_job["audit-to-bigquery"].job.container_spec_gcs_path == "gs://dataflow-templates-us-central1/2026-09-15-00_RC00/flex/PubSub_to_BigQuery_Flex" &&
      module.flex_job["audit-to-bigquery"].job.transform_name_mapping == tomap({ ReadPubSubTopic = "ReadAuditEvents" })
    )
    error_message = "streaming: pinned template in another region."
  }
  assert {
    condition     = module.flex_job["clicks-to-gcs"].job.labels == tomap({ managed-by = "terraform", team = "data-platform", kind = "streaming", pii = "false" })
    error_message = "streaming: labels."
  }
}

run "batch_pipelines" {
  command = plan

  variables {
    config_file = "examples/batch-pipelines/config.yaml"
  }

  assert {
    condition     = toset(keys(module.pipeline)) == toset(["daily-orders-load", "weekly-parquet-export", "monthly-compress", "events-stream"])
    error_message = "batch-pipelines: four pipelines."
  }
  assert {
    condition = (
      module.pipeline["daily-orders-load"].type == "PIPELINE_TYPE_BATCH" &&
      module.pipeline["events-stream"].type == "PIPELINE_TYPE_STREAMING" &&
      module.pipeline["monthly-compress"].state == "STATE_PAUSED"
    )
    error_message = "batch-pipelines: types and states."
  }
  assert {
    condition = (
      module.pipeline["daily-orders-load"].pipeline.workload[0].dataflow_flex_template_request[0].launch_parameter[0].environment[0].flexrs_goal == "FLEXRS_COST_OPTIMIZED" &&
      module.pipeline["daily-orders-load"].pipeline.workload[0].dataflow_flex_template_request[0].launch_parameter[0].environment[0].ip_configuration == "WORKER_IP_PRIVATE" &&
      module.pipeline["monthly-compress"].pipeline.workload[0].dataflow_launch_template_request[0].gcs_path == "gs://dataflow-templates-europe-west1/latest/Bulk_Compress_GCS_Files"
    )
    error_message = "batch-pipelines: anchored worker settings and templates."
  }
  assert {
    condition     = module.pipeline["weekly-parquet-export"].pipeline.schedule_info[0].time_zone == "Europe/Berlin" && length(module.pipeline["events-stream"].pipeline.schedule_info) == 0
    error_message = "batch-pipelines: default time zone only where there is a schedule."
  }
}

run "custom_flex_templates" {
  command = plan

  variables {
    config_file   = "examples/custom-flex-templates/config.yaml"
    template_vars = { templates_bucket = "tpl", version = "3.2.0" }
  }

  assert {
    condition = (
      module.flex_job["enrich-customers"].job.container_spec_gcs_path == "gs://tpl/flex/enrich-customers-3.2.0.json" &&
      module.flex_job["enrich-customers"].job.autoscaling_algorithm == "AUTOSCALING_ALGORITHM_NONE" &&
      module.flex_job["enrich-customers"].job.num_workers == 8 &&
      module.flex_job["enrich-customers"].job.parameters == tomap({ input_table = "example-project:crm.customers", output_table = "example-project:crm.customers_enriched", batch_size = "500", dry_run = "false" })
    )
    error_message = "custom-flex-templates: enrich-customers."
  }
  assert {
    condition     = module.flex_job["fraud-scoring"].job.create_ignore_already_exists == true && module.flex_job["fraud-scoring"].job.on_delete == "cancel"
    error_message = "custom-flex-templates: fraud-scoring."
  }
  assert {
    condition     = module.classic_job["nightly-dedupe"].job.zone == "us-central1-b" && module.classic_job["nightly-dedupe"].job.labels["version"] == "3.2.0"
    error_message = "custom-flex-templates: nightly-dedupe."
  }
}

run "secure_networking" {
  command = plan

  variables {
    config_file   = "examples/secure-networking/config.yaml"
    template_vars = { host_project = "net-host" }
  }

  assert {
    condition = alltrue(concat(
      [for j in values(module.flex_job) : j.job.ip_configuration == "WORKER_IP_PRIVATE" && j.job.kms_key_name != null && startswith(j.job.subnetwork, "https://www.googleapis.com/compute/v1/projects/net-host/")],
      [for j in values(module.classic_job) : j.job.ip_configuration == "WORKER_IP_PRIVATE" && j.job.kms_key_name != null],
    ))
    error_message = "secure-networking: private IPs, CMEK and Shared VPC everywhere."
  }
  assert {
    condition     = module.flex_job["payments-stream"].job.deletion_policy == "PREVENT"
    error_message = "secure-networking: payments-stream is protected."
  }
  assert {
    condition = (
      module.pipeline["nightly-reconciliation"].pipeline.scheduler_service_account_email == "df-scheduler@example-project.iam.gserviceaccount.com" &&
      module.pipeline["nightly-reconciliation"].pipeline.workload[0].dataflow_flex_template_request[0].launch_parameter[0].environment[0].worker_region == "europe-west4"
    )
    error_message = "secure-networking: pipeline settings."
  }
}

run "multi_environment_dev" {
  command = plan

  variables {
    config_file   = "examples/multi-environment/config.yaml"
    template_vars = { env = "dev", max_workers = 2 }
  }

  assert {
    condition = (
      toset(keys(module.flex_job)) == toset(["events-ingest", "backfill"]) &&
      module.flex_job["events-ingest"].job.machine_type == "e2-standard-2" &&
      module.flex_job["events-ingest"].job.on_delete == "cancel" &&
      module.pipeline["daily-aggregates"].pipeline.schedule_info[0].schedule == "0 6 * * 1"
    )
    error_message = "multi-environment: dev settings."
  }
}

run "multi_environment_prod" {
  command = plan

  variables {
    config_file   = "examples/multi-environment/config.yaml"
    template_vars = { env = "prod", max_workers = 50 }
  }

  assert {
    condition = (
      toset(keys(module.flex_job)) == toset(["events-ingest"]) &&
      module.flex_job["events-ingest"].job.machine_type == "n2-standard-4" &&
      module.flex_job["events-ingest"].job.max_workers == 50 &&
      module.flex_job["events-ingest"].job.deletion_policy == "PREVENT" &&
      module.pipeline["daily-aggregates"].state == "STATE_ACTIVE"
    )
    error_message = "multi-environment: prod settings."
  }
}

run "multi_environment_staging" {
  command = plan

  variables {
    config_file   = "examples/multi-environment/config.yaml"
    template_vars = { env = "staging", max_workers = 5 }
  }

  assert {
    condition     = module.pipeline["daily-aggregates"].state == "STATE_PAUSED" && local.jobs["backfill"].enabled == false
    error_message = "multi-environment: staging settings."
  }
}

run "complete" {
  command = plan

  variables {
    config_file = "examples/complete/config.yaml"
    labels      = { managed-by = "terraform" }
  }

  assert {
    condition = (
      toset(keys(module.flex_job)) == toset(["orders-stream", "scoring"]) &&
      toset(keys(module.classic_job)) == toset(["dedupe", "word-count"]) &&
      toset(keys(module.pipeline)) == toset(["daily-load", "monthly-compress", "events", "weekly-report"])
    )
    error_message = "complete: four jobs and four pipelines enabled."
  }
  assert {
    condition = (
      module.flex_job["orders-stream"].name == "orders-to-bq" &&
      module.flex_job["scoring"].project_id == "ml-platform" &&
      module.flex_job["scoring"].job.num_workers == 1 &&
      local.jobs["dedupe"].num_workers == null
    )
    error_message = "complete: names, projects and per-type defaults."
  }
  assert {
    condition = (
      module.pipeline["daily-load"].pipeline.name == "projects/example-project/locations/europe-west1/pipelines/daily_load" &&
      module.pipeline["daily-load"].job_name == "daily-orders-load" &&
      module.pipeline["events"].type == "PIPELINE_TYPE_STREAMING" &&
      module.pipeline["weekly-report"].state == "STATE_PAUSED"
    )
    error_message = "complete: pipeline settings."
  }
}

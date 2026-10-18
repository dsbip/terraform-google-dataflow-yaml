# The submodules work without YAML: modules/classic-job, modules/flex-job and
# modules/pipeline take typed inputs. Note the google-beta provider for Flex
# Template jobs.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.42.0, < 9.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 7.42.0, < 9.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

provider "google-beta" {
  project = var.project_id
}

variable "project_id" {
  description = "Project to run the jobs in."
  type        = string
}

locals {
  region = "europe-west1"
  bucket = "${var.project_id}-dataflow"
}

module "word_count" {
  source = "../../modules/classic-job"

  name              = "word-count"
  project_id        = var.project_id
  region            = local.region
  template_gcs_path = "gs://dataflow-templates-${local.region}/latest/Word_Count"
  temp_location     = "gs://${local.bucket}/tmp"
  parameters = {
    inputFile = "gs://dataflow-samples/shakespeare/kinglear.txt"
    output    = "gs://${local.bucket}/wordcount/out"
  }
}

# One streaming job per topic.
module "topic_to_bigquery" {
  source   = "../../modules/flex-job"
  for_each = toset(["orders", "payments"])

  name                    = "${each.key}-to-bq"
  project_id              = var.project_id
  region                  = local.region
  container_spec_gcs_path = "gs://dataflow-templates-${local.region}/latest/flex/PubSub_to_BigQuery_Flex"
  temp_location           = "gs://${local.bucket}/tmp"
  enable_streaming_engine = true
  on_delete               = "drain"
  parameters = {
    inputTopic      = "projects/${var.project_id}/topics/${each.key}"
    outputTableSpec = "${var.project_id}:raw.${each.key}"
  }
}

module "nightly_export" {
  source = "../../modules/pipeline"

  name                    = "nightly_export"
  project_id              = var.project_id
  region                  = local.region
  type                    = "BATCH"
  schedule                = "0 3 * * *"
  container_spec_gcs_path = "gs://dataflow-templates-${local.region}/latest/flex/BigQuery_to_Parquet"
  temp_location           = "gs://${local.bucket}/tmp"
  parameters = {
    tableRef = "${var.project_id}:raw.orders"
    bucket   = "gs://${local.bucket}/exports/"
  }
}

output "jobs" {
  value = merge({ word_count = module.word_count.job_id }, { for k, m in module.topic_to_bigquery : k => m.job_id })
}

output "pipeline" {
  value = module.nightly_export.id
}

# Live-test fixture (see docs/testing.md): a bucket, a topic, one streaming
# Flex Template job and, optionally, a paused Data Pipeline.

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
  description = "Project to test in."
  type        = string
}

variable "region" {
  description = "Region to test in (an App Engine region if enable_pipeline is set)."
  type        = string
  default     = "europe-west1"
}

variable "suffix" {
  description = "Random suffix that keeps names of concurrent runs apart."
  type        = string
}

variable "revision" {
  description = "Changes the pipeline's display name and schedule (in-place update test)."
  type        = number
  default     = 1
}

variable "enable_pipeline" {
  description = "Also create a paused Data Pipeline."
  type        = bool
  default     = false
}

resource "google_storage_bucket" "data" {
  name                        = "dfyaml-${var.suffix}-${var.project_id}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
  labels                      = { purpose = "terraform-module-test" }
}

resource "google_pubsub_topic" "input" {
  name   = "dfyaml-${var.suffix}-input"
  labels = { purpose = "terraform-module-test" }
}

module "dataflow" {
  source = "../.."

  project_id  = var.project_id
  region      = var.region
  config_file = "${path.module}/dataflow.yaml"
  template_vars = {
    suffix          = var.suffix
    revision        = var.revision
    bucket          = google_storage_bucket.data.name
    topic           = google_pubsub_topic.input.name
    enable_pipeline = var.enable_pipeline
  }
}

output "jobs" {
  value = module.dataflow.jobs
}

output "pipelines" {
  value = module.dataflow.pipelines
}

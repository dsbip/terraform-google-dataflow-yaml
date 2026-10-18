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

variable "region" {
  description = "Region of the job."
  type        = string
  default     = "europe-west1"
}

variable "bucket" {
  description = "Existing bucket for temporary files and the output."
  type        = string
}

module "dataflow" {
  source = "../.."

  project_id    = var.project_id
  region        = var.region
  config_file   = "${path.module}/config.yaml"
  template_vars = { bucket = var.bucket }
}

output "jobs" {
  value = module.dataflow.jobs
}

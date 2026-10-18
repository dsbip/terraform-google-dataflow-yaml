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
variable "templates_bucket" {
  description = "Bucket with the template spec files, staging and temp locations."
  type        = string
  default     = "example-dataflow-templates"
}

variable "release" {
  description = "Template release to run."
  type        = string
  default     = "3.2.0"
}

module "dataflow" {
  source = "../.."

  project_id  = var.project_id
  config_file = "${path.module}/config.yaml"
  template_vars = {
    templates_bucket = var.templates_bucket
    version          = var.release
  }
}

output "jobs" {
  value = module.dataflow.jobs
}

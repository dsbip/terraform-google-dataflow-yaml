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
module "dataflow" {
  source = "../.."

  project_id  = var.project_id
  config_file = "${path.module}/config.yaml"
  labels      = { managed-by = "terraform" }
}

output "jobs" {
  value = module.dataflow.jobs
}

output "pipelines" {
  value = module.dataflow.pipelines
}

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

provider "google" {}

provider "google-beta" {}

variable "environments" {
  description = "Environments to deploy, each with its own project."
  type = map(object({
    project_id  = string
    max_workers = number
  }))
  default = {
    dev     = { project_id = "example-dev", max_workers = 2 }
    staging = { project_id = "example-staging", max_workers = 5 }
    prod    = { project_id = "example-prod", max_workers = 50 }
  }
}

module "dataflow" {
  source   = "../.."
  for_each = var.environments

  project_id  = each.value.project_id
  config_file = "${path.module}/config.yaml"
  template_vars = {
    env         = each.key
    max_workers = each.value.max_workers
  }
}

output "jobs" {
  value = { for env, m in module.dataflow : env => keys(m.jobs) }
}

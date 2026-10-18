terraform {
  # 1.5 is the oldest release this module is tested against (see docs/testing.md).
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source = "hashicorp/google"
      # 7.42 is the first release with every attribute the module sets
      # (deletion_policy on jobs and pipelines).
      version = ">= 7.42.0, < 9.0.0"
    }
    # Flex Template jobs (google_dataflow_flex_template_job) are only
    # available in google-beta.
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 7.42.0, < 9.0.0"
    }
  }
}

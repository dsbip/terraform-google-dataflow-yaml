terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # google_dataflow_flex_template_job is only available in google-beta.
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 7.42.0, < 9.0.0"
    }
  }
}

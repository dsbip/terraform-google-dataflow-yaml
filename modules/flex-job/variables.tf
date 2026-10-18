variable "container_spec_gcs_path" {
  description = "gs:// path of the Flex Template spec file."
  type        = string

  validation {
    condition     = startswith(var.container_spec_gcs_path, "gs://")
    error_message = "The container_spec_gcs_path must be a gs:// path."
  }
}

variable "name" {
  description = "Job name: lowercase letters, digits and hyphens, starting with a letter and ending with a letter or digit."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", var.name))
    error_message = "The name must start with a lowercase letter, contain only lowercase letters, digits and hyphens, and not end with a hyphen."
  }
}

variable "project_id" {
  description = "Project of the job."
  type        = string
}

variable "region" {
  description = "Region of the job, e.g. europe-west1."
  type        = string
}

variable "parameters" {
  description = "Template parameters."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "labels" {
  description = "Job labels."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "temp_location" {
  description = "gs:// path for temporary files."
  type        = string
  default     = null

  validation {
    condition     = var.temp_location == null || startswith(coalesce(var.temp_location, "gs://"), "gs://")
    error_message = "The temp_location must be a gs:// path."
  }
}

variable "service_account_email" {
  description = "Worker service account."
  type        = string
  default     = null
}

variable "network" {
  description = "VPC network of the workers."
  type        = string
  default     = null
}

variable "subnetwork" {
  description = "Subnetwork of the workers: regions/REGION/subnetworks/NAME or a full URL."
  type        = string
  default     = null
}

variable "machine_type" {
  description = "Worker machine type."
  type        = string
  default     = null
}

variable "max_workers" {
  description = "Maximum number of workers."
  type        = number
  default     = null
}

variable "ip_configuration" {
  description = "WORKER_IP_PUBLIC or WORKER_IP_PRIVATE."
  type        = string
  default     = null

  validation {
    condition     = var.ip_configuration == null || contains(["WORKER_IP_PUBLIC", "WORKER_IP_PRIVATE"], coalesce(var.ip_configuration, "WORKER_IP_PUBLIC"))
    error_message = "The ip_configuration must be WORKER_IP_PUBLIC or WORKER_IP_PRIVATE."
  }
}

variable "kms_key_name" {
  description = "Cloud KMS key (CMEK)."
  type        = string
  default     = null
}

variable "additional_experiments" {
  description = "Dataflow experiments."
  type        = list(string)
  default     = null
}

variable "enable_streaming_engine" {
  description = "Use Streaming Engine."
  type        = bool
  default     = null
}

variable "transform_name_mapping" {
  description = "Old to new transform name prefixes for in-place updates."
  type        = map(string)
  default     = null
}

variable "on_delete" {
  description = "drain or cancel the running job on destroy or replacement."
  type        = string
  default     = null

  validation {
    condition     = var.on_delete == null || contains(["drain", "cancel"], coalesce(var.on_delete, "drain"))
    error_message = "The on_delete must be drain or cancel."
  }
}

variable "skip_wait_on_job_termination" {
  description = "Don't wait for draining or cancelling to finish."
  type        = bool
  default     = null
}

variable "deletion_policy" {
  description = "DELETE, PREVENT or ABANDON."
  type        = string
  default     = null

  validation {
    condition     = var.deletion_policy == null || contains(["DELETE", "PREVENT", "ABANDON"], coalesce(var.deletion_policy, "DELETE"))
    error_message = "The deletion_policy must be DELETE, PREVENT or ABANDON."
  }
}

variable "num_workers" {
  description = "Initial number of workers."
  type        = number
  default     = null
}

variable "staging_location" {
  description = "gs:// path for staging files."
  type        = string
  default     = null
}

variable "launcher_machine_type" {
  description = "Machine type of the launcher VM (default n1-standard-1)."
  type        = string
  default     = null
}

variable "sdk_container_image" {
  description = "Custom SDK container image for the workers."
  type        = string
  default     = null
}

variable "autoscaling_algorithm" {
  description = "AUTOSCALING_ALGORITHM_NONE or AUTOSCALING_ALGORITHM_BASIC."
  type        = string
  default     = null

  validation {
    condition     = var.autoscaling_algorithm == null || contains(["AUTOSCALING_ALGORITHM_NONE", "AUTOSCALING_ALGORITHM_BASIC"], coalesce(var.autoscaling_algorithm, "AUTOSCALING_ALGORITHM_BASIC"))
    error_message = "The autoscaling_algorithm must be AUTOSCALING_ALGORITHM_NONE or AUTOSCALING_ALGORITHM_BASIC."
  }
}

variable "additional_pipeline_options" {
  description = "Extra pipeline options, e.g. [\"numberOfWorkerHarnessThreads=20\"]."
  type        = list(string)
  default     = null
}

variable "create_ignore_already_exists" {
  description = "Adopt an existing job with the same name instead of failing."
  type        = bool
  default     = null
}

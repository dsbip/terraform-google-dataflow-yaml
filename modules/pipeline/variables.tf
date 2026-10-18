variable "name" {
  description = "Pipeline ID: letters, digits, hyphens and underscores (at most 63)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,63}$", var.name))
    error_message = "The name may contain only letters, digits, hyphens and underscores (at most 63)."
  }
}

variable "project_id" {
  description = "Project of the pipeline and of the jobs it launches."
  type        = string
}

variable "region" {
  description = "Region of the pipeline and of the jobs it launches (an App Engine region)."
  type        = string
}

variable "display_name" {
  description = "Display name (default: the pipeline ID)."
  type        = string
  default     = null
}

variable "type" {
  description = "BATCH or STREAMING (or PIPELINE_TYPE_BATCH / PIPELINE_TYPE_STREAMING)."
  type        = string

  validation {
    condition     = contains(["BATCH", "STREAMING", "PIPELINE_TYPE_BATCH", "PIPELINE_TYPE_STREAMING"], var.type)
    error_message = "The type must be BATCH or STREAMING."
  }
}

variable "state" {
  description = "ACTIVE or PAUSED (or STATE_ACTIVE / STATE_PAUSED)."
  type        = string
  default     = "ACTIVE"
  nullable    = false

  validation {
    condition     = contains(["ACTIVE", "PAUSED", "STATE_ACTIVE", "STATE_PAUSED"], var.state)
    error_message = "The state must be ACTIVE or PAUSED."
  }
}

variable "schedule" {
  description = "Cron schedule (batch pipelines). Null: launched on demand only."
  type        = string
  default     = null
}

variable "time_zone" {
  description = "Time zone of the schedule (default UTC)."
  type        = string
  default     = null
}

variable "scheduler_service_account_email" {
  description = "Service account Cloud Scheduler uses to launch the jobs."
  type        = string
  default     = null
}

variable "pipeline_sources" {
  description = "Source metadata of the pipeline."
  type        = map(string)
  default     = null
}

variable "job_name" {
  description = "Name of the launched jobs (default: the pipeline ID in lowercase, underscores replaced by hyphens)."
  type        = string
  default     = null
}

variable "template_gcs_path" {
  description = "Classic template to launch. Set this or container_spec_gcs_path."
  type        = string
  default     = null
}

variable "container_spec_gcs_path" {
  description = "Flex Template to launch. Set this or template_gcs_path."
  type        = string
  default     = null
}

variable "parameters" {
  description = "Template parameters."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "labels" {
  description = "Labels of the launched jobs (additional_user_labels)."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "launch_options" {
  description = "Flex Template launch options."
  type        = map(string)
  default     = null
}

variable "transform_name_mapping" {
  description = "Old to new transform name prefixes (streaming updates)."
  type        = map(string)
  default     = null
}

variable "update" {
  description = "Update a running streaming job with the same name."
  type        = bool
  default     = null
}

variable "validate_only" {
  description = "Only validate the launch request."
  type        = bool
  default     = null
}

variable "temp_location" {
  description = "gs:// path for temporary files."
  type        = string
  default     = null
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
  description = "Subnetwork of the workers."
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

variable "num_workers" {
  description = "Initial number of workers."
  type        = number
  default     = null
}

variable "ip_configuration" {
  description = "WORKER_IP_PUBLIC or WORKER_IP_PRIVATE."
  type        = string
  default     = null
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

variable "zone" {
  description = "Worker zone."
  type        = string
  default     = null
}

variable "worker_region" {
  description = "Region of the workers."
  type        = string
  default     = null
}

variable "worker_zone" {
  description = "Zone of the workers."
  type        = string
  default     = null
}

variable "flexrs_goal" {
  description = "FlexRS goal (Flex Templates): FLEXRS_SPEED_OPTIMIZED or FLEXRS_COST_OPTIMIZED."
  type        = string
  default     = null
}

variable "bypass_temp_dir_validation" {
  description = "Skip validating temp_location (classic templates)."
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

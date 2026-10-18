output "id" {
  description = "Resource ID of the job."
  value       = google_dataflow_flex_template_job.this.id
}

output "job_id" {
  description = "Dataflow job ID."
  value       = google_dataflow_flex_template_job.this.job_id
}

output "name" {
  description = "Job name."
  value       = google_dataflow_flex_template_job.this.name
}

output "project_id" {
  description = "Project of the job."
  value       = var.project_id
}

output "region" {
  description = "Region of the job."
  value       = var.region
}

output "state" {
  description = "Current state, e.g. JOB_STATE_RUNNING."
  value       = google_dataflow_flex_template_job.this.state
}

output "type" {
  description = "JOB_TYPE_BATCH or JOB_TYPE_STREAMING."
  value       = google_dataflow_flex_template_job.this.type
}

output "job" {
  description = "The google_dataflow_flex_template_job resource."
  value       = google_dataflow_flex_template_job.this
}

output "id" {
  description = "Pipeline resource name (projects/P/locations/R/pipelines/ID)."
  value       = google_data_pipeline_pipeline.this.name
}

output "name" {
  description = "Pipeline ID."
  value       = var.name
}

output "project_id" {
  description = "Project of the pipeline."
  value       = var.project_id
}

output "region" {
  description = "Region of the pipeline."
  value       = var.region
}

output "job_name" {
  description = "Name of the jobs the pipeline launches."
  value       = local.job_name
}

output "type" {
  description = "PIPELINE_TYPE_BATCH or PIPELINE_TYPE_STREAMING."
  value       = local.type
}

output "state" {
  description = "Requested state, e.g. STATE_ACTIVE."
  value       = local.state
}

output "next_job_time" {
  description = "When the next scheduled job starts (batch pipelines)."
  value       = try(google_data_pipeline_pipeline.this.schedule_info[0].next_job_time, null)
}

output "pipeline" {
  description = "The google_data_pipeline_pipeline resource."
  value       = google_data_pipeline_pipeline.this
}

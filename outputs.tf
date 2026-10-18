output "jobs" {
  description = "Launched jobs keyed by YAML key: id, job_id, name, project_id, region, state, type, template_type (classic or flex) and template."
  value = merge(
    {
      for k, m in module.classic_job : k => {
        id    = m.id, job_id = m.job_id, name = m.name, project_id = m.project_id, region = m.region
        state = m.state, type = m.type, template_type = "classic", template = local.jobs[k].template_path
      }
    },
    {
      for k, m in module.flex_job : k => {
        id    = m.id, job_id = m.job_id, name = m.name, project_id = m.project_id, region = m.region
        state = m.state, type = m.type, template_type = "flex", template = local.jobs[k].template_path
      }
    },
  )
}

output "pipelines" {
  description = "Data Pipelines keyed by YAML key: id, name, project_id, region, job_name, type, state, template_type, template and next_job_time."
  value = {
    for k, m in module.pipeline : k => {
      id            = m.id, name = m.name, project_id = m.project_id, region = m.region, job_name = m.job_name
      type          = m.type, state = m.state, template_type = local.pipelines[k].kind, template = local.pipelines[k].template_path
      next_job_time = m.next_job_time
    }
  }
}

output "job_ids" {
  description = "Dataflow job IDs, keyed by YAML key."
  value       = merge({ for k, m in module.classic_job : k => m.job_id }, { for k, m in module.flex_job : k => m.job_id })
}

output "config" {
  description = "The normalised configuration (after defaults), as { jobs = {...}, pipelines = {...} }, including disabled entries."
  value       = { jobs = local.jobs, pipelines = local.pipelines }
}

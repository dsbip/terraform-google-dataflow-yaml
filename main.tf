# -----------------------------------------------------------------------------
# Configuration loading
#
# The YAML is decoded into plain objects, merged with its defaults and passed
# to one modules/classic-job, modules/flex-job or modules/pipeline instance
# per entry (jobs.tf, pipelines.tf). Loading never fails on bad input: every
# lookup is wrapped in try() so that validation.tf can report all problems at
# once with YAML paths.
# -----------------------------------------------------------------------------

locals {
  # JSON Schema of the configuration file. validation.tf reads allowed keys,
  # types, enumerations, ranges and patterns from it.
  schema = jsondecode(file("${path.module}/schemas/dataflow-config.schema.json"))

  config_template_vars = try(
    merge({ project_id = var.project_id, region = var.region }, var.template_vars),
    { project_id = var.project_id, region = var.region },
  )

  config_text = (
    var.config_yaml != null ? var.config_yaml :
    var.config_file != null ? templatefile(var.config_file, local.config_template_vars) :
    ""
  )

  # yamldecode() rejects documents that are empty or contain only comments.
  config_is_blank = length(regexall("(?m)^[ \\t]*[^#\\s]", local.config_text)) == 0
  config_decoded  = local.config_is_blank ? null : yamldecode(local.config_text)
  config          = try(merge({}, local.config_decoded), {})

  project_id = try(coalesce(try(tostring(local.config.project_id), null), var.project_id), null)
  defaults   = try(merge({}, local.config.defaults), {})
  region     = try(coalesce(try(tostring(local.defaults.region), null), var.region), null)
  labels     = merge(var.labels, try({ for k, v in local.defaults.labels : k => tostring(v) if v != null }, {}))

  # ---------------------------------------------------------------------------
  # Defaults
  #
  # defaults.jobs / defaults.pipelines are merged underneath every job /
  # pipeline, three levels deep (entry keys, keys of nested mappings such as
  # parameters and labels, and the keys inside those). Lists and scalars are
  # replaced. Explicit nulls are dropped first, so an empty `key:` line never
  # overrides a default. Defaults that don't apply to an entry's template type
  # (e.g. a Flex-only num_workers for a classic job) are left out for that
  # entry.
  # ---------------------------------------------------------------------------

  defaults_forbidden_keys = {
    for type in ["jobs", "pipelines"] :
    type => try(local.schema.definitions.defaults.properties[type].allOf[1].propertyNames.not.enum, [])
  }

  type_defaults = {
    for type in ["jobs", "pipelines"] : type => {
      for k, v in try(merge({}, local.defaults[type]), {}) : k => v
      if v != null && !contains(local.defaults_forbidden_keys[type], k)
    }
  }

  # Keys that only apply to one template type.
  only_for = {
    jobs = {
      flex    = ["num_workers", "staging_location", "launcher_machine_type", "sdk_container_image", "autoscaling_algorithm", "additional_pipeline_options", "create_ignore_already_exists"]
      classic = ["zone"]
    }
    pipelines = {
      flex    = ["launch_options", "flexrs_goal"]
      classic = ["bypass_temp_dir_validation"]
    }
  }

  inputs = {
    jobs      = try(merge({}, local.config.jobs), {})
    pipelines = try(merge({}, local.config.pipelines), {})
  }

  inputs_clean = {
    for type, entries in local.inputs : type => {
      for key, e in entries : key => { for k, v in try(merge({}, e), {}) : k => v if v != null }
    }
  }

  merged_all = {
    for type, entries in local.inputs_clean : type => {
      for key, e in entries : key => {
        for k in setunion(keys(local.type_defaults[type]), keys(e)) : k => try(
          {
            for k2 in setunion(keys(local.type_defaults[type][k]), keys(e[k])) : k2 => try(
              merge(local.type_defaults[type][k][k2], e[k][k2]),
              [for v in [e[k][k2]] : v if v != null][0],
              local.type_defaults[type][k][k2],
            )
          },
          e[k],
          local.type_defaults[type][k],
        )
      }
    }
  }

  # classic, flex, or null when no (or more than one) template is set.
  kinds = {
    for type, entries in local.merged_all : type => {
      for key, e in entries : key => (
        length([for t in ["template_gcs_path", "container_spec_gcs_path", "google_template"] : t if try(e[t], null) != null]) != 1 ? null :
        try(e.template_gcs_path, null) != null ? "classic" :
        try(e.container_spec_gcs_path, null) != null ? "flex" :
        try(lower(tostring(e.google_template.type)), "flex") == "classic" ? "classic" : "flex"
      )
    }
  }

  merged = {
    for type, entries in local.merged_all : type => {
      for key, e in entries : key => {
        for k, v in e : k => v
        if local.kinds[type][key] == null || contains(keys(local.inputs_clean[type][key]), k) || !contains(try(local.only_for[type][local.kinds[type][key] == "classic" ? "flex" : "classic"], []), k)
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Normalised entries: exactly the inputs of the submodules.
  # ---------------------------------------------------------------------------

  common = {
    for type, entries in local.merged : type => {
      for key, e in entries : key => {
        enabled    = try(tobool(e.enabled), true)
        kind       = local.kinds[type][key]
        name       = try(tostring(e.name), key)
        project_id = try(coalesce(try(tostring(e.project_id), null), local.project_id), null)
        region     = try(coalesce(try(tostring(e.region), null), local.region), null)
        labels     = merge(local.labels, try({ for k, v in e.labels : k => tostring(v) if v != null }, {}))
        parameters = try({ for k, v in e.parameters : k => tostring(v) if v != null }, {})

        # Google-provided templates: gs://dataflow-templates-REGION/VERSION/[flex/]NAME
        template_path = try(coalesce(
          try(tostring(e.template_gcs_path), null),
          try(tostring(e.container_spec_gcs_path), null),
          try(format(
            "gs://dataflow-templates-%s/%s/%s%s",
            coalesce(try(tostring(e.region), null), local.region),
            try(tostring(e.google_template.version), "latest"),
            local.kinds[type][key] == "classic" ? "" : "flex/",
            tostring(e.google_template.name),
          ), null),
        ), null)

        temp_location           = try(tostring(e.temp_location), null)
        service_account_email   = try(tostring(e.service_account_email), null)
        network                 = try(tostring(e.network), null)
        subnetwork              = try(tostring(e.subnetwork), null)
        machine_type            = try(tostring(e.machine_type), null)
        max_workers             = try(tonumber(e.max_workers), null)
        num_workers             = try(tonumber(e.num_workers), null)
        ip_configuration        = try(tostring(e.ip_configuration), null)
        kms_key_name            = try(tostring(e.kms_key_name), null)
        additional_experiments  = try([for x in e.additional_experiments : tostring(x)], null)
        enable_streaming_engine = try(tobool(e.enable_streaming_engine), null)
        transform_name_mapping  = try({ for k, v in e.transform_name_mapping : k => tostring(v) }, null)
        zone                    = try(tostring(e.zone), null)
        deletion_policy         = try(tostring(e.deletion_policy), null)
      }
    }
  }

  jobs = {
    for key, e in local.merged.jobs : key => merge(local.common.jobs[key], {
      staging_location             = try(tostring(e.staging_location), null)
      launcher_machine_type        = try(tostring(e.launcher_machine_type), null)
      sdk_container_image          = try(tostring(e.sdk_container_image), null)
      autoscaling_algorithm        = try(tostring(e.autoscaling_algorithm), null)
      additional_pipeline_options  = try([for x in e.additional_pipeline_options : tostring(x)], null)
      create_ignore_already_exists = try(tobool(e.create_ignore_already_exists), null)
      on_delete                    = try(tostring(e.on_delete), null)
      skip_wait_on_job_termination = try(tobool(e.skip_wait_on_job_termination), null)
    })
  }

  pipelines = {
    for key, e in local.merged.pipelines : key => merge(local.common.pipelines[key], {
      display_name = try(tostring(e.display_name), null)
      # BATCH when there is a schedule, STREAMING otherwise, unless set.
      type                            = try(tostring(e.type), try(e.schedule, null) != null ? "BATCH" : "STREAMING")
      state                           = try(tostring(e.state), "ACTIVE")
      schedule                        = try(tostring(e.schedule), null)
      time_zone                       = try(tostring(e.time_zone), null)
      scheduler_service_account_email = try(tostring(e.scheduler_service_account_email), null)
      pipeline_sources                = try({ for k, v in e.pipeline_sources : k => tostring(v) }, null)
      job_name                        = try(tostring(e.job_name), null)
      launch_options                  = try({ for k, v in e.launch_options : k => tostring(v) }, null)
      update                          = try(tobool(e.update), null)
      validate_only                   = try(tobool(e.validate_only), null)
      worker_region                   = try(tostring(e.worker_region), null)
      worker_zone                     = try(tostring(e.worker_zone), null)
      flexrs_goal                     = try(tostring(e.flexrs_goal), null)
      bypass_temp_dir_validation      = try(tobool(e.bypass_temp_dir_validation), null)
    })
  }
}

# -----------------------------------------------------------------------------
# Validation
#
# Every problem in the configuration is collected into local.validation_errors
# (as "<yaml path>: <problem>") and reported by the precondition at the end of
# this file. While there are problems, every module's for_each is empty
# (local.config_valid), so the plan fails with that list and nothing else.
#
# Part 1 is generic: it walks the YAML alongside the JSON Schema and checks
# keys, types, enumerations, ranges, patterns and required keys. Part 2 holds
# the rules a schema cannot express (exactly-one-of, keys that only apply to
# one template type, values that come from defaults, duplicates).
#
# Rules for code in this file:
# - && and || do not short-circuit in Terraform < 1.12, so every operand must
#   be safe to evaluate on its own; lookups that may fail are wrapped in try().
# - Conditional expressions must not mix object types; filters (`if`) are used
#   instead of `cond ? [] : [obj]` wherever the objects hold YAML values.
# - null means "not set": test with try(x, null) != null, not can(x).
# -----------------------------------------------------------------------------

locals {
  # ---------------------------------------------------------------------------
  # Part 1: schema-driven checks
  # ---------------------------------------------------------------------------

  ref_prefix      = "#/definitions/"
  placeholder_ref = "#/definitions/template_placeholder"

  # "root" is the top level of the file; every other name is a definition.
  schema_defs = merge(local.schema.definitions, { root = local.schema })

  # Every alternative a property allows: the property schema itself, its anyOf
  # and allOf members, and the definitions their $refs point to (plus those
  # definitions' anyOf members). ${...} placeholders are not alternatives here:
  # templatefile() has replaced them before the YAML is parsed.
  schema_options = {
    for dname, d in local.schema_defs : dname => {
      for pname, p in try(d.properties, {}) : pname => flatten([
        for o in concat([p], try(p.anyOf, []), try(p.allOf, [])) : [
          for r in concat(
            [try(local.schema.definitions[trimprefix(o["$ref"], local.ref_prefix)], o)],
            try(local.schema.definitions[trimprefix(o["$ref"], local.ref_prefix)].anyOf, []),
          ) : r if try(r["$ref"], "") != local.placeholder_ref
        ] if try(o["$ref"], "") != local.placeholder_ref
      ])
    }
  }

  # The same for list items (`items`) and mapping values (`additionalProperties`).
  schema_item_options = {
    for dname, props in local.schema_options : dname => {
      for pname, opts in props : pname => flatten([
        for o in opts : [
          for r in concat(
            [try(local.schema.definitions[trimprefix(o.items["$ref"], local.ref_prefix)], o.items)],
            try(local.schema.definitions[trimprefix(o.items["$ref"], local.ref_prefix)].anyOf, []),
          ) : r if try(r["$ref"], "") != local.placeholder_ref
        ] if can(o.items.type) || can(o.items["$ref"])
      ])
    }
  }

  schema_value_options = {
    for dname, props in local.schema_options : dname => {
      for pname, opts in props : pname => flatten([
        for o in opts : [
          for r in concat(
            [try(local.schema.definitions[trimprefix(o.additionalProperties["$ref"], local.ref_prefix)], o.additionalProperties)],
            try(local.schema.definitions[trimprefix(o.additionalProperties["$ref"], local.ref_prefix)].anyOf, []),
          ) : r if try(r["$ref"], "") != local.placeholder_ref
        ] if can(o.additionalProperties.type) || can(o.additionalProperties["$ref"])
      ])
    }
  }

  # Definition that a property's value, each of its items, or each of its
  # mapping values must satisfy (null: not an object definition).
  schema_refs = {
    for dname, d in local.schema_defs : dname => {
      for pname, p in try(d.properties, {}) : pname => {
        object = try(one(distinct([
          for o in concat([p], try(p.anyOf, []), try(p.allOf, [])) : trimprefix(o["$ref"], local.ref_prefix)
          if can(local.schema.definitions[trimprefix(o["$ref"], local.ref_prefix)].properties)
        ])), null)
        items = try(one(distinct([
          for o in concat([try(p.items, null)], try(p.items.anyOf, [])) : trimprefix(o["$ref"], local.ref_prefix)
          if can(local.schema.definitions[trimprefix(o["$ref"], local.ref_prefix)].properties)
        ])), null)
        values = try(one(distinct([
          for o in concat([try(p.additionalProperties, null)], try(p.additionalProperties.anyOf, [])) : trimprefix(o["$ref"], local.ref_prefix)
          if can(local.schema.definitions[trimprefix(o["$ref"], local.ref_prefix)].properties)
        ])), null)
      }
    }
  }

  # Allowed keys of each definition, for unknown-key checks.
  schema_keys = { for dname, d in local.schema_defs : dname => keys(try(d.properties, {})) }

  type_phrases = {
    string  = "a string"
    integer = "a whole number"
    number  = "a number"
    boolean = "true or false"
    array   = "a list"
    object  = "a mapping"
  }

  # Walk the YAML along the schema: every mapping that a definition describes,
  # with its YAML path. Six levels are more than the deepest nesting of the
  # schema (defaults.jobs.google_template); tests/python/test_schema.py fails
  # if the schema ever grows deeper.
  walk_0 = [{ path = "", value = local.config_decoded, def = "root" }]

  walk_1 = flatten([
    for c in local.walk_0 : [
      for k, v in try(merge({}, c.value), {}) : concat(
        [for x in [v] : { path = "${c.path}${c.path == "" ? "" : "."}${k}", value = x, def = local.schema_refs[c.def][k].object } if try(local.schema_refs[c.def][k].object, null) != null],
        [for i, x in try(concat(v, []), []) : { path = "${c.path}${c.path == "" ? "" : "."}${k}[${i}]", value = x, def = local.schema_refs[c.def][k].items } if try(local.schema_refs[c.def][k].items, null) != null],
        [for k2, x in try(merge({}, v), {}) : { path = "${c.path}${c.path == "" ? "" : "."}${k}.${k2}", value = x, def = local.schema_refs[c.def][k].values } if try(local.schema_refs[c.def][k].values, null) != null],
      ) if v != null
    ]
  ])

  walk_2 = flatten([
    for c in local.walk_1 : [
      for k, v in try(merge({}, c.value), {}) : concat(
        [for x in [v] : { path = "${c.path}.${k}", value = x, def = local.schema_refs[c.def][k].object } if try(local.schema_refs[c.def][k].object, null) != null],
        [for i, x in try(concat(v, []), []) : { path = "${c.path}.${k}[${i}]", value = x, def = local.schema_refs[c.def][k].items } if try(local.schema_refs[c.def][k].items, null) != null],
        [for k2, x in try(merge({}, v), {}) : { path = "${c.path}.${k}.${k2}", value = x, def = local.schema_refs[c.def][k].values } if try(local.schema_refs[c.def][k].values, null) != null],
      ) if v != null
    ]
  ])

  walk_3 = flatten([
    for c in local.walk_2 : [
      for k, v in try(merge({}, c.value), {}) : concat(
        [for x in [v] : { path = "${c.path}.${k}", value = x, def = local.schema_refs[c.def][k].object } if try(local.schema_refs[c.def][k].object, null) != null],
        [for i, x in try(concat(v, []), []) : { path = "${c.path}.${k}[${i}]", value = x, def = local.schema_refs[c.def][k].items } if try(local.schema_refs[c.def][k].items, null) != null],
        [for k2, x in try(merge({}, v), {}) : { path = "${c.path}.${k}.${k2}", value = x, def = local.schema_refs[c.def][k].values } if try(local.schema_refs[c.def][k].values, null) != null],
      ) if v != null
    ]
  ])

  walk_4 = flatten([
    for c in local.walk_3 : [
      for k, v in try(merge({}, c.value), {}) : concat(
        [for x in [v] : { path = "${c.path}.${k}", value = x, def = local.schema_refs[c.def][k].object } if try(local.schema_refs[c.def][k].object, null) != null],
        [for i, x in try(concat(v, []), []) : { path = "${c.path}.${k}[${i}]", value = x, def = local.schema_refs[c.def][k].items } if try(local.schema_refs[c.def][k].items, null) != null],
        [for k2, x in try(merge({}, v), {}) : { path = "${c.path}.${k}.${k2}", value = x, def = local.schema_refs[c.def][k].values } if try(local.schema_refs[c.def][k].values, null) != null],
      ) if v != null
    ]
  ])

  walk_5 = flatten([
    for c in local.walk_4 : [
      for k, v in try(merge({}, c.value), {}) : concat(
        [for x in [v] : { path = "${c.path}.${k}", value = x, def = local.schema_refs[c.def][k].object } if try(local.schema_refs[c.def][k].object, null) != null],
        [for i, x in try(concat(v, []), []) : { path = "${c.path}.${k}[${i}]", value = x, def = local.schema_refs[c.def][k].items } if try(local.schema_refs[c.def][k].items, null) != null],
        [for k2, x in try(merge({}, v), {}) : { path = "${c.path}.${k}.${k2}", value = x, def = local.schema_refs[c.def][k].values } if try(local.schema_refs[c.def][k].values, null) != null],
      ) if v != null
    ]
  ])

  # Mappings found by the walk (non-mappings are reported by their parent's type check).
  schema_nodes = [
    for c in concat(local.walk_0, local.walk_1, local.walk_2, local.walk_3, local.walk_4, local.walk_5) : c
    if can(keys(c.value))
  ]

  # One entry per key present in a mapping, with what the schema allows there.
  key_checks = flatten([
    for c in local.schema_nodes : [
      for k, v in c.value : {
        parent    = c.path == "" ? "(root)" : c.path
        path      = c.path == "" ? k : "${c.path}.${k}"
        key       = k
        value     = v
        is_string = try(startswith(jsonencode(v), "\""), false)
        known     = contains(local.schema_keys[c.def], k)
        # Likely intended keys: the same first three letters or the same
        # letters in another order; only if there are none, the same last
        # three letters.
        suggestions = length(k) < 3 ? [] : try(coalescelist(
          [for a in local.schema_keys[c.def] : a if length(a) >= 3 && (substr(a, 0, 3) == substr(k, 0, 3) || join("", sort(split("", a))) == join("", sort(split("", k))))],
          [for a in local.schema_keys[c.def] : a if length(a) >= 3 && substr(a, length(a) - 3, 3) == substr(k, length(k) - 3, 3)],
        ), [])
        types         = distinct(flatten([for o in try(local.schema_options[c.def][k], []) : try(flatten([o.type]), [])]))
        enums         = distinct(flatten([for o in try(local.schema_options[c.def][k], []) : try(o.enum, [])]))
        patterns      = distinct([for o in try(local.schema_options[c.def][k], []) : o.pattern if can(o.pattern)])
        minimum       = try(max([for o in try(local.schema_options[c.def][k], []) : o.minimum if can(o.minimum)]...), null)
        maximum       = try(min([for o in try(local.schema_options[c.def][k], []) : o.maximum if can(o.maximum)]...), null)
        min_items     = try(max([for o in try(local.schema_options[c.def][k], []) : o.minItems if can(o.minItems)]...), null)
        description   = try([for o in try(local.schema_options[c.def][k], []) : o.description if can(o.description)][0], "")
        item_types    = distinct(flatten([for o in try(local.schema_item_options[c.def][k], []) : try(flatten([o.type]), [])]))
        item_enums    = distinct(flatten([for o in try(local.schema_item_options[c.def][k], []) : try(o.enum, [])]))
        item_patterns = distinct([for o in try(local.schema_item_options[c.def][k], []) : o.pattern if can(o.pattern)])
        item_desc     = try([for o in try(local.schema_item_options[c.def][k], []) : o.description if can(o.description)][0], "")
        value_types   = distinct(flatten([for o in try(local.schema_value_options[c.def][k], []) : try(flatten([o.type]), [])]))
      } if v != null
    ]
  ])

  # List items and mapping values, checked against the item/value schema.
  element_checks = concat(
    flatten([
      for kc in local.key_checks : [
        for i, x in try(concat(kc.value, []), []) : {
          path = "${kc.path}[${i}]", value = x, is_string = try(startswith(jsonencode(x), "\""), false), types = kc.item_types, enums = kc.item_enums, patterns = kc.item_patterns, description = kc.item_desc
        }
      ] if length(kc.item_types) > 0
    ]),
    flatten([
      for kc in local.key_checks : [
        for k2, x in try(merge({}, kc.value), {}) : {
          path = "${kc.path}.${k2}", value = x, is_string = try(startswith(jsonencode(x), "\""), false), types = kc.value_types, enums = [], patterns = [], description = ""
        } if x != null
      ] if length(kc.value_types) > 0
    ]),
  )

  value_checks = concat(
    [for kc in local.key_checks : { path = kc.path, value = kc.value, is_string = kc.is_string, types = kc.types, enums = kc.enums, patterns = kc.patterns, description = kc.description } if kc.known],
    local.element_checks,
  )

  unknown_key_errors = [
    for kc in local.key_checks : "${kc.parent}: unknown key \"${kc.key}\"${length(kc.suggestions) == 0 ? "" : " (did you mean ${join(" or ", slice(kc.suggestions, 0, min(3, length(kc.suggestions))))}?)"}"
    if !kc.known
  ]

  type_errors = [
    for vc in local.value_checks : "${vc.path}: must be ${join(" or ", distinct([
      for t in vc.types : local.type_phrases[contains(vc.types, "string") && contains(["number", "integer", "boolean"], t) ? "string" : t] if t != "null"
    ]))}"
    if length(vc.types) > 0 && !anytrue([
      for t in vc.types :
      t == "string" ? can(tostring(vc.value)) :
      t == "integer" ? try(floor(tonumber(vc.value)) == tonumber(vc.value), false) :
      t == "number" ? can(tonumber(vc.value)) :
      t == "boolean" ? can(tobool(vc.value)) :
      t == "array" ? can(concat(vc.value, [])) :
      t == "object" ? can(keys(vc.value)) :
      t == "null" ? vc.value == null :
      false
    ])
  ]

  enum_errors = [
    for vc in local.value_checks : "${vc.path}: must be one of ${join(", ", vc.enums)} (got \"${vc.value}\")"
    if length(vc.enums) > 0 && can(tostring(vc.value)) && !contains([for e in vc.enums : tostring(e)], try(coalesce(tostring(vc.value)), ""))
  ]

  # A pattern belongs to the string alternative: values of another allowed
  # type (e.g. the number in "number or octal string") are not matched.
  pattern_errors = [
    for vc in local.value_checks : "${vc.path}: \"${vc.value}\" is not valid${vc.description == "" ? "" : " (${trimsuffix(vc.description, ".")})"}"
    if length(vc.patterns) == 1 && can(tostring(vc.value)) && (vc.is_string || !anytrue([for t in vc.types : t != "string"])) && length(regexall(try(vc.patterns[0], "^"), try(tostring(vc.value), ""))) == 0
  ]

  # Ranges belong to the numeric alternative: strings are not compared when
  # strings are allowed too.
  range_errors = concat(
    [for kc in local.key_checks : "${kc.path}: must be at least ${kc.minimum}" if try(tonumber(kc.value) < kc.minimum, false) && !(kc.is_string && contains(kc.types, "string"))],
    [for kc in local.key_checks : "${kc.path}: must be at most ${kc.maximum}" if try(tonumber(kc.value) > kc.maximum, false) && !(kc.is_string && contains(kc.types, "string"))],
    [for kc in local.key_checks : "${kc.path}: must have at least ${kc.min_items} item(s)" if try(length(concat(kc.value, [])) < kc.min_items, false)],
  )

  required_errors = flatten([
    for c in local.schema_nodes : [
      for r in try(local.schema_defs[c.def].required, []) : "${c.path == "" ? "(root)" : c.path}: missing required key \"${r}\""
      if try(c.value[r], null) == null
    ]
  ])

  schema_errors = concat(
    local.config_decoded == null || can(keys(local.config_decoded)) ? [] : ["(root): the configuration must be a mapping (key: value pairs)"],
    local.unknown_key_errors,
    local.type_errors,
    local.enum_errors,
    local.pattern_errors,
    local.range_errors,
    local.required_errors,
  )

  # ---------------------------------------------------------------------------
  # Part 2: rules beyond the schema
  # ---------------------------------------------------------------------------

  job_name_pattern = "^[a-z]([-a-z0-9]*[a-z0-9])?$"
  name_patterns = {
    jobs      = local.job_name_pattern
    pipelines = "^[A-Za-z0-9_-]{1,63}$"
  }
  name_rules = {
    jobs      = "lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen"
    pipelines = "letters, digits, hyphens and underscores, at most 63 characters"
  }
  kind_names = { classic = "classic templates (template_gcs_path, or google_template with type: classic)", flex = "Flex Templates (container_spec_gcs_path, or google_template)" }

  input_errors = concat(
    var.config_file != null && var.config_yaml != null ? ["(module): set config_file or config_yaml, not both"] : [],
    var.config_file == null && var.config_yaml == null ? ["(module): set config_file or config_yaml"] : [],
    flatten([
      for type, forbidden in local.defaults_forbidden_keys : [
        for k in keys(try(merge({}, local.defaults[type]), {})) : "defaults.${type}: \"${k}\" cannot be a default" if contains(forbidden, k)
      ]
    ]),
  )

  # Entry-level rules, on the merged entry (defaults applied), for entries
  # that are mappings: anything else already has a type error.
  entry_errors = flatten([
    for type, entries in local.merged : [
      for key, e in entries : concat(
        local.common[type][key].project_id == null ? ["${type}.${key}: no project_id; set it here, at the top level of the file, or in the module's project_id variable"] : [],
        local.common[type][key].region == null ? ["${type}.${key}: no region; set it here, in defaults.region, or in the module's region variable"] : [],
        contains(["true", "false"], key) ? ["${type}.${key}: YAML reads unquoted yes, no, on, off, true and false as booleans; quote the key (e.g. \"on\":) or choose another name"] : [],
        try(e.name, null) != null || length(regexall(local.name_patterns[type], key)) > 0 ? [] : [
          "${type}.${key}: the key is used as the name but is not a valid one (${local.name_rules[type]}); rename it or set name"
        ],

        # Template
        length([for t in ["template_gcs_path", "container_spec_gcs_path", "google_template"] : t if try(e[t], null) != null]) == 1 ? [] : [
          "${type}.${key}: set exactly one of template_gcs_path, container_spec_gcs_path and google_template${length([for t in ["template_gcs_path", "container_spec_gcs_path", "google_template"] : t if try(e[t], null) != null]) == 0 ? "" : " (found ${join(", ", [for t in ["template_gcs_path", "container_spec_gcs_path", "google_template"] : t if try(e[t], null) != null])})"}"
        ],
        local.kinds[type][key] == null ? [] : [
          for k in try(local.only_for[type][local.kinds[type][key] == "classic" ? "flex" : "classic"], []) :
          "${type}.${key}.${k}: only available for ${local.kind_names[local.kinds[type][key] == "classic" ? "flex" : "classic"]}"
          if try(e[k], null) != null
        ],
        type == "jobs" && local.kinds[type][key] == "classic" && try(e.temp_location, null) == null ? [
          "${type}.${key}: temp_location is required for classic templates"
        ] : [],

        # Workers
        try(tonumber(e.num_workers) > tonumber(e.max_workers), false) ? [
          "${type}.${key}: num_workers (${e.num_workers}) is greater than max_workers (${e.max_workers})"
        ] : [],

        # Pipelines
        type != "pipelines" ? [] : concat(
          contains(["STREAMING", "PIPELINE_TYPE_STREAMING"], local.pipelines[key].type) && try(e.schedule, null) != null ? [
            "${type}.${key}: schedule is only for batch pipelines (type is ${local.pipelines[key].type})"
          ] : [],
          contains(["STREAMING", "PIPELINE_TYPE_STREAMING"], local.pipelines[key].type) && try(e.flexrs_goal, null) != null ? [
            "${type}.${key}: flexrs_goal is only for batch pipelines"
          ] : [],
          # Only a time_zone set on the pipeline itself: a default one is
          # simply unused by pipelines without a schedule.
          try(local.inputs_clean[type][key].time_zone, null) != null && try(e.schedule, null) == null ? [
            "${type}.${key}: time_zone needs schedule"
          ] : [],
          try(e.job_name, null) != null || length(regexall(local.job_name_pattern, local.pipeline_job_names[key])) > 0 ? [] : [
            "${type}.${key}: the job name derived from the pipeline ID (\"${local.pipeline_job_names[key]}\") is not a valid job name; set job_name"
          ],
        ),
      )
      if local.inputs[type][key] == null || can(keys(local.inputs[type][key]))
    ]
  ])

  pipeline_job_names = { for key, p in local.pipelines : key => replace(lower(p.name), "_", "-") }

  # Two enabled entries with the same name in the same project and region.
  # Classic and Flex Template jobs share one namespace.
  entry_ids = {
    for type, entries in local.common : type => {
      for key, e in entries : key => "${e.project_id}/${e.region}/${e.name}"
      if e.enabled && e.project_id != null && e.region != null
    }
  }
  duplicate_errors = flatten([
    for type, ids in local.entry_ids : [
      for id, ks in { for key, id in ids : id => key... } : "${type}: ${join(", ", ks)} would all create ${trimsuffix(type, "s")} ${id}" if length(ks) > 1
    ]
  ])

  validation_errors = distinct(concat(
    local.input_errors,
    local.schema_errors,
    local.entry_errors,
    local.duplicate_errors,
  ))

  # Every module's for_each is empty while the configuration is invalid. The
  # provider validates each planned instance before any precondition runs, so
  # without this an invalid file would fail with type or provider errors
  # instead of the message below.
  config_valid = length(local.validation_errors) == 0
}

resource "terraform_data" "validation" {
  lifecycle {
    precondition {
      condition     = length(local.validation_errors) == 0
      error_message = "The Dataflow YAML configuration has ${length(local.validation_errors)} problem(s):\n  - ${join("\n  - ", local.validation_errors)}"
    }
  }
}

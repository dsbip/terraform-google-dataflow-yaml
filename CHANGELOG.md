# Changelog

All notable changes to this module are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-18

First release.

### Added

- YAML-driven Dataflow jobs from classic templates (`google_dataflow_job`) and Flex Templates (`google_dataflow_flex_template_job`), in one `jobs` map; the template key decides the type.
- `google_template`: Google-provided templates by name, type and version, expanded with each job's region.
- Data Pipelines (`google_data_pipeline_pipeline`) for scheduled batch and streaming pipelines, with the same template and worker keys as jobs, inferred type, short forms of type and state, derived job names.
- Every worker, networking, encryption, update and deletion setting of the three resources.
- `defaults` for region, labels, jobs and pipelines, merged three levels deep and applied only where they fit the template type; YAML anchors and merge keys.
- Templating of `config_file` with `templatefile()`, and `enabled` per entry.
- Validation driven by the JSON Schema plus rules (exactly one template, keys of the other template type, batch-only settings, derived job names, duplicates), all reported at once with YAML paths.
- Standalone submodules `modules/classic-job`, `modules/flex-job` and `modules/pipeline`.
- Eight examples, 40+ unit tests with mocked providers, real-provider plan tests, schema and documentation tests, and a live test.

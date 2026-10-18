# Standalone modules example

The YAML layer is optional. [`modules/classic-job`](../../modules/classic-job), [`modules/flex-job`](../../modules/flex-job) and [`modules/pipeline`](../../modules/pipeline) are ordinary modules with typed inputs:

- `module.word_count`: a classic template job.
- `module.topic_to_bigquery`: two streaming Flex Template jobs with `for_each`.
- `module.nightly_export`: a scheduled Data Pipeline.

The YAML root module calls the same modules, once per entry; it also expands `google_template` names into the template paths written out here.

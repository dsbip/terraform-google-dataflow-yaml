# Basic example

Runs Google's classic **Word Count** template once: it reads a public sample text and writes word counts to your bucket.

- `google_template: { name: Word_Count, type: classic }` expands to `gs://dataflow-templates-REGION/latest/Word_Count`.
- Classic templates need `temp_location`.

```bash
terraform init
terraform apply -var project_id=my-project -var bucket=my-dataflow-bucket
gsutil cat "gs://my-dataflow-bucket/wordcount/kinglear*" | head
```

A batch job ends. The provider then removes it from the state, so the next `terraform apply` runs it again. Use [pipelines](../batch-pipelines) for batch work that should run on a schedule.

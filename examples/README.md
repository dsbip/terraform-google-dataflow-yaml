# Examples

Each example is a root module with a `config.yaml` (the standalone one has HCL only) and a `main.tf` that configures the google and google-beta providers and calls the module. All of them are planned with the real providers in CI (`tests/python/test_example_plans.py`) and checked against their README by `tests/examples.tftest.hcl`.

| Example | Jobs | Pipelines | Shows |
|---|---|---|---|
| [basic](basic) | 1 | | Google's Word Count classic template |
| [streaming](streaming) | 3 | | Pub/Sub to BigQuery and to Cloud Storage, pinned template version, other region, transform mapping, shared defaults |
| [batch-pipelines](batch-pipelines) | | 4 | daily, weekly and monthly schedules, FlexRS, paused pipeline, streaming pipeline, YAML anchors |
| [custom-flex-templates](custom-flex-templates) | 3 | | your own Flex and classic templates: SDK image, launcher machine type, fixed workers, pipeline options, adopting running jobs |
| [secure-networking](secure-networking) | 2 | 1 | private IPs, Shared VPC, CMEK, dedicated service accounts, worker zone and region, deletion protection |
| [multi-environment](multi-environment) | 1–2 per env | 1 per env | dev, staging and prod from one file |
| [complete](complete) | 5 | 5 | every configuration key |
| [standalone-modules](standalone-modules) | 3 | 1 | the submodules without YAML |

Run one:

```bash
cd examples/basic
terraform init
terraform apply -var project_id=my-project -var bucket=my-dataflow-bucket
```

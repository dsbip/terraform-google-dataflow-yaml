# Secure networking example

Every job and pipeline runs with private worker IPs in a Shared VPC subnetwork (given as a full URL into the host project), encrypts with a customer-managed key, and uses a dedicated worker service account. The settings are written once (`&secure`) and shared by jobs and pipelines.

| Entry | Shows |
|---|---|
| `payments-stream` | streaming Flex Template, `deletion_policy: PREVENT`, drain on delete |
| `archive-compress` | classic template with workers in one zone |
| `nightly-reconciliation` | scheduled pipeline whose workers run in another region (`worker_region`) |

Prerequisites: Private Google Access on the subnetwork; `roles/compute.networkUser` on it for the Dataflow service agent and the worker service account; `roles/cloudkms.cryptoKeyEncrypterDecrypter` on the key for the Dataflow and Compute Engine service agents.

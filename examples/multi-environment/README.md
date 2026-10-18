# Multi-environment example

One [`config.yaml`](config.yaml) runs in dev, staging and prod; [`main.tf`](main.tf) calls the module once per environment.

| | dev | staging | prod |
|---|---|---|---|
| `events-ingest` | `e2-standard-2`, up to 2 workers, cancel on delete | up to 5 workers | `n2-standard-4`, up to 50 workers, drain on delete, `PREVENT` deletion |
| `backfill` | runs | validated, not deployed | validated, not deployed |
| `daily-aggregates` | Mondays 06:00 | Mondays 06:00, paused | daily 02:00 |

Techniques: placeholders and expressions in typed fields, quoted where the expression contains `: `, a `%{ if }` block, `enabled`, and a YAML anchor that shares worker settings between `defaults.jobs` and `defaults.pipelines`.

# Command and Workflow Surfaces

Repo commands and workflows do not need to live in one place.

`dev.kit` should treat them as **repo-owned surfaces** that can appear in different forms depending on the repo design.

## Common command surfaces

Commands are often packaged in:

- `Makefile`
- `package.json`
- shell scripts under `bin/`, `scripts/`, or `tests/`
- `composer.json`
- `Dockerfile`
- deploy manifests
- GitHub workflows
- repo docs when a command is intentionally documented rather than declared in a manifest

## Common workflow surfaces

Workflow and operational contracts are often packaged in:

- `.github/workflows/*.yml` when the workflow expresses repo-specific execution contracts
- reusable workflow refs
- Docker build and runtime files
- deploy manifests such as `deploy.yml`
- repo docs that explain how those assets fit together

## Practical rule

`dev.kit` should not assume one preferred packaging mechanism.

Instead it should:

1. detect the strongest repo-owned source
2. record where the command or workflow was found
3. prefer declared surfaces over guessed ones
4. point gaps back to the repo asset that should become clearer

## Example

A repo may expose its main flow through a mix like:

- `Makefile` for `make test`, `make build`, `make run`
- `.github/workflows/` for CI/CD execution
- `deploy.yml` for deploy contract details
- `docs/` for operator-facing explanation

That is valid as long as the repo makes those surfaces clear and traceable.

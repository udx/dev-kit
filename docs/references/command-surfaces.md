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

## Build and deploy may be separate

Some repos intentionally separate:

- build commands that create a reusable artifact once
- deploy or runtime commands that inject environment-specific values later

`dev.kit` should treat that as a valid repo design when the contract is explicit.

Typical shape:

- `package.json`, `Makefile`, or docs define the build command and its defaults
- deploy manifests and workflows define runtime env injection, release promotion, or start-time wiring
- repo docs explain how the build artifact and runtime configuration fit together

## Workflow trigger caveat

Workflow contracts should reflect how automation is actually triggered, not only the ideal event name.

For example, a downstream workflow that waits only on `release.published` may not run when the release is created by another workflow or bot token. In that case the repo may need a stronger repo-owned trigger such as:

- `workflow_run`
- `workflow_dispatch`
- a direct reusable workflow edge

The important contract is the repo-owned execution path that really fires in practice.

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

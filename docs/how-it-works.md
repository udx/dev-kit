# How It Works

`dev.kit` turns repo-declared structure into context coverage for repo handoffs.

The default starting point is:

```bash
dev.kit
```

When a repo is detected, that one command should:

- check the current environment
- summarize whether `.rabbit/context.yaml` already exists
- point to `dev.kit repo` when regeneration is needed
- point to the next focused subcommand when needed

The important idea is that the flow is dynamic:

1. environment state shapes what can be detected and recommended
2. repo signals shape what can be serialized
3. gaps shape what should be repaired next
4. regenerated context shapes what repo-owned asset should be repaired next

The lower-level commands still exist:

- `dev.kit env`
- `dev.kit repo`

Those are useful when only one layer needs to be refreshed, but the default experience should start from `dev.kit`.

## Command Flow

Think of the command flow as four linked layers:

### 1. Environment layer

`dev.kit env` detects tools, auth state, and local capability controls.

That matters because later steps should only claim repo or dependency resolution that the current machine actually supports.

### 2. Repo contract layer

`dev.kit repo` inspects repo-owned signals and writes `.rabbit/context.yaml`.

For the split between repo docs and generated contract output, see [Repo Contract Boundary](repo-contract-boundary.md).

That file should describe:

- what the repo declares clearly
- what `dev.kit` could trace deterministically
- what is still missing or only partial

Before writing context, `dev.kit repo` can also ensure a small default repo baseline so even an empty repo becomes regeneration-friendly:

- `README.md`
- `.github/dependabot.yml`
- `.github/workflows/`
- `.rabbit/`
- `docs/`

That baseline is intentionally small. It is there to create repo-owned places for contracts and docs, not to scaffold an application architecture.

### 3. Repair and regeneration layer

If gaps are detected, the intended loop is:

1. fix the repo-owned source asset that should declare the missing contract
2. rerun `dev.kit repo`
3. validate that the gap was actually reduced or resolved

That makes gaps part of the workflow, not just passive reporting.

## Generated Artifacts

`dev.kit` produces one core artifact:

- `.rabbit/context.yaml`

`.rabbit/context.yaml` is the structured repo contract. It contains repo identity, direct-read refs, detected commands with their source, structured gaps, manifests, and meaningful external contract traces.

The goal is to keep the operating model current, reviewable, and repo-local.

Files such as `AGENTS.md` or `CLAUDE.md` are not generated artifacts. They are repo-owned instruction surfaces that teams can maintain alongside the generated contract, optionally normalized from repo docs such as `docs/references/agent-dev-workflow.md`.

Example:

```bash
dev.kit
dev.kit repo
```

This keeps the default loop short: inspect first, then regenerate only when the repo contract needs refresh.

## Repo Assets

The repo is intentionally split into a small set of assets:

- `src/configs/*.yaml` defines repo detection, context sections, signal lists, and gap rules.
- `src/configs/*.yaml` configures the behavior of `dev.kit` modules and scripts.
- `lib/modules/*.sh` implements thin, config-driven detection and rendering helpers.
- `lib/commands/*.sh` exposes the public command flow: `env`, `repo`, and `uninstall`.
- `bin/dev-kit` is the CLI entrypoint and the only happy-path runner.
- `docs/` documents `dev.kit` behavior, boundaries, workflow, and outputs.
- `docs/references/` holds compact knowledgebase references for developers and agents.
- `.rabbit/context.yaml` is the generated output, refreshed from repo signals.
- `tests/` covers command flow, generated context, and user-facing CLI output.

Backend-specific details such as Terraform modules, Docker images, reusable workflows, and package scripts should appear as traced manifest or contract details. They should not become top-level repo identities unless the repo explicitly declares that contract.

## Command Roles

`dev.kit env` inspects tools, auth state, and local env config. It defines what later steps can responsibly assume.

`dev.kit repo` analyzes the repository, records deterministic coverage, and writes `.rabbit/context.yaml`.

It also points to recommended supporting repos when they are useful for shared workers, reusable workflow contracts, or related repo tooling:

- `udx/worker`
- `udx/reusable-workflows`
- `udx/github-rabbit-action`

## Working Model

The working model is repo-first and regeneration-first:

1. read the repo’s declared context
2. serialize it into `context.yaml`
3. repair gaps in repo-owned source assets when needed
4. regenerate context and continue from the refreshed contract

That keeps the repo as the source of truth and avoids drifting away from repo-owned standards.

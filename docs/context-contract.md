# Context Contract

`dev.kit` is a deterministic repo tool. It reads repo-owned evidence, emits a compact generated contract, and exposes weak coverage so humans, agents, scripts, and CI/CD can work from the same repository state.

The generated contract is `.rabbit/context.yaml`.

## What dev.kit Reads

`dev.kit` should prefer repo-owned surfaces that a maintainer can review and repair:

- `.rabbit/context.yaml` when checking existing generated context state
- `AGENTS.md`, `CLAUDE.md`, and similar repo-owned instruction files
- `README.md`, `changes.md`, and focused docs
- `.github/workflows/`
- manifests such as typed YAML configs, package manifests, Docker files, and workflow contracts
- scripts, Makefiles, tests, and checked-in examples that define runnable behavior

Live services such as GitHub issues, PRs, reviews, and workflow runs can help a current task, but they should not become durable repo truth inside `.rabbit/context.yaml`.

## What dev.kit Emits

`.rabbit/context.yaml` should contain generated repo evidence and deterministic interpretation:

- generator metadata, version, source refs, and generation timestamp
- repo identity and archetype
- direct-read refs for humans and agents
- detected verify, build, and run commands with sources
- coverage gaps with evidence and repair targets
- dependency contracts such as reusable workflows, images, and versioned manifests
- manifest inventory with provenance and usage evidence

The artifact should be portable. It must not contain machine-local absolute paths, temp files, cache paths, or generated evidence that only exists on one workstation.

## What dev.kit Must Not Own

`dev.kit` must not become the source of truth for:

- global UDX strategy
- app-specific runtime truth
- secrets, credentials, or local machine state
- issue, PR, or Slack conversation history
- long-form agent prompts or subjective workflow narration
- hand-authored corrections to generated context

If a gap needs durable meaning, repair the owning repo asset and rerun `dev.kit repo`.

## Workflow Boundary

The command surface stays small:

- `dev.kit` inspects environment and repo context status.
- `dev.kit env` reports tool, credential, and capability coverage.
- `dev.kit repo` generates or refreshes `.rabbit/context.yaml`.

Inspection should be read-only unless the command is explicitly a writer. Repair should happen in repo-owned assets, not in generated output.

## Integrity Rules

The context contract is useful only when it stays traceable:

- Prefer structured evidence over inferred prose.
- Keep observed facts and inferred relationships visibly separate.
- Emit gaps instead of guessing.
- Record source paths for commands, manifests, and repair references.
- Keep direct-read refs concise.
- Keep generated output portable across machines.
- Treat stale or legacy generator metadata as a reason to rerun `dev.kit repo`.

For the stable machine-readable shapes, see [Reference: Output Schemas](references/output-schemas.md).

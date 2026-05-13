# dev.kit

<https://udx.dev/kit>

`dev.kit` turns repositories into self-explaining repo contracts for humans, scripts, and CI/CD.

It helps teams and repositories:

1. understand how the repo actually works
2. keep repo standards, manifests, refs, and dependency contracts traceable
3. regenerate reliable context from repo signals instead of tribal knowledge

The model is:

- repo-first
- gap-aware
- regeneration-friendly
- standard-driven
- manifest-driven

## Install

```bash
npm install -g @udx/dev-kit
```

```bash
curl -fsSL https://raw.githubusercontent.com/udx/dev.kit/latest/bin/scripts/install.sh | bash
```

## Quick start

```bash
# make sure your dev.kit install is current first
cd my-repo

dev.kit      # inspect environment and repo context status
dev.kit repo # generate or refresh .rabbit/context.yaml
```

Optional capability refresh:

```bash
dev.kit env
```

## Operating loop

`dev.kit` uses staged repo-driven context generation:

```text
dev.kit
  → inspect environment
  → summarize repo-local context status
  → warn when existing context is stale
  → point to the next safe step

dev.kit env
  → detect tools, auth, and resolution capabilities

dev.kit repo
  → resolve repo standards, manifests, refs, dependency contracts, and gaps
  → ensure a minimal repo-owned structure when needed
  → generate .rabbit/context.yaml
```

Each step produces metadata that guides the next safe repo repair or regeneration step.

## `.rabbit/context.yaml`

`dev.kit repo` generates `.rabbit/context.yaml` as the repo operational contract.

It may include:

- generator metadata
- manifests
- refs
- workflows
- commands
- dependencies
- dependency repo contracts
- coverage gaps
- repair hints

The repo should remain usable even when `dev.kit` is unavailable.

Committed repo-local context should stay useful for maintenance and automation.

## Agent instruction files

Agent instruction files such as `AGENTS.md` or `CLAUDE.md` are optional repo-owned policy surfaces.

`dev.kit` can point maintainers toward the kind of guidance those files should contain. A repo may keep that guidance in docs and, if preferred, normalize it into `AGENTS.md` as a maintained repo-owned surface.

Use those files for consumer behavior rules and team-specific operating guidance. Keep `.rabbit/context.yaml` focused on generated repo facts.

## Repo surfaces

This repo is intentionally split by responsibility:

- `src/configs/` configures `dev.kit` detection, gap rules, context sections, and other module inputs
- scripts, workflows, and YAML manifests are the programmatic execution layer
- `docs/` documents `dev.kit` behavior, repo-context boundaries, workflow, and outputs
- `docs/references/` is a small knowledgebase for developers and agents when gaps or contract surfaces need interpretation
- `tests/` validates command flow, generated context, and user-facing outputs

## Empty repos

`dev.kit repo` is safe to run on nearly empty repos.

It can establish a minimal default structure so the repo becomes regeneration-friendly immediately:

- `README.md`
- `.github/dependabot.yml`
- `.github/workflows/`
- `.rabbit/`
- `docs/`

That gives the repo clear places for context coverage, workflow traceability, docs, and future repair loops without inventing app-specific structure.

## Refs and traceability

`dev.kit` resolves refs using:

1. manifest metadata/header refs
2. repo-local usage
3. dependency-repo usage and workflow relationships

If refs cannot be resolved:

- gaps are emitted
- repair hints are suggested
- unresolved state is preserved instead of guessed

Example:

```bash
dev.kit repo
```

Then read:

- `README.md`
- `docs/`
- `.rabbit/context.yaml`

## Commands

| Command                | Purpose                                            |
| ---------------------- | -------------------------------------------------- |
| `dev.kit`              | Inspect repo context status and suggest next steps |
| `dev.kit env`          | Detect tools, auth, and resolution capabilities    |
| `dev.kit env --config` | Configure capability restrictions                  |
| `dev.kit repo`         | Generate `.rabbit/context.yaml`                    |
| `dev.kit repo --force` | Re-resolve repo and dependency context             |

All commands support `--json`.

## Recommended tooling repos

`dev.kit repo` also points to a small set of supporting UDX repos when you need shared worker, workflow, or repo-contract tooling:

- <https://github.com/udx/worker>
- <https://github.com/udx/reusable-workflows>
- <https://github.com/udx/github-rabbit-action>

## Principles

- automate what can be verified
- expose unresolved gaps instead of guessing
- prefer refs over duplicated docs
- stay app-agnostic and language-agnostic
- keep repo-owned contracts compact and markdown-friendly
- degrade gracefully when tooling, auth, or external context is unavailable
- optimize for operational clarity over automation complexity

## Docs

- [How It Works](docs/how-it-works.md)
- [Repo Contract Boundary](docs/repo-contract-boundary.md)
- [Environment Config](docs/environment-config.md)
- [Context Coverage](docs/context-coverage.md)
- [Smart Dependency Detection](docs/smart-dependency-detection.md)
- [Reference Docs](docs/references/README.md)
- [Reference: Command and Workflow Surfaces](docs/references/command-surfaces.md)
- [Reference: Agent and Developer Workflow](docs/references/agent-dev-workflow.md)
- [Installation](docs/installation.md)

## Testing

```bash
bash tests/suite.sh --only core
```

```bash
bash tests/worker-smoke.sh
```

```bash
bash tests/real-repos.sh /path/to/repo1 /path/to/repo2
```

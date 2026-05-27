# Output Schemas

This is the stable schema reference for `dev.kit` outputs. It documents the intended shape for humans, agents, scripts, and CI/CD without changing the command surface.

The current contract is intentionally small and may grow by adding fields. Consumers should ignore unknown fields.

## Home Output

Command:

```bash
dev.kit --json
```

Top-level fields:

- `name`: tool name
- `home`: local `dev.kit` home path
- `state`: install state
- `workflow`: environment and repo workflow jobs
- `workspace`: current directory and detected repo state
- `synced`: generated context path, status, reason, and counts
- `localhost_tools`: detected local tools
- `global_context`: capability summary derived from environment detection
- `start_here`: ordered local workflow hints
- `helpers`: supported command entrypoints

Stable status values should stay compact: `ready`, `blocked`, `workspace_only`, `needs_repo_context`, `stale_context`, and `needs_repair`.

## Environment Output

Command:

```bash
dev.kit env --json
```

Top-level fields:

- `command`: `env`
- `home`: local `dev.kit` home path
- `workflow`: environment workflow job
- `tools`: detected tools grouped by category
- `capabilities`: derived capability booleans
- `config`: environment override config path and disabled tool or credential lists

Environment output describes what can be observed safely from the current machine. It should not imply unavailable credentials or tools exist.

## Repo Output

Command:

```bash
dev.kit repo --json
```

Top-level fields:

- `command`: `repo`
- `repo`: repo name
- `path`: repo root path for the current machine
- `mode`: `write` or `check`
- `archetype`: detected repo archetype
- `markers`: root and capability markers
- `factors`: coverage summary by factor
- `gaps`: missing or partial coverage entries
- `actions`: structured next actions
- `workflow`: repo workflow job
- `context`: generated context path
- `dependencies`: dependency contract summary parsed from generated context
- `recommended_repos`: supporting tool repos

Repo JSON may include local paths because it reports the current machine state. `.rabbit/context.yaml` must remain portable and relative.

## Context Artifact

File:

```text
.rabbit/context.yaml
```

Stable sections:

- `kind`
- `version`
- `generator`
- `repo`
- `refs`
- `commands`
- `gaps`
- `dependencies`
- `manifests`

`generator` should include:

- `tool`
- `repo`
- `version`
- `generated_at`
- `sources`

`commands` should stay limited to repo entrypoints such as `verify`, `build`, and `run`. Installation, source, and guide references belong under generator/source metadata or docs, not in `commands`.

## Repair Proposals

Repair guidance should be structured as data, not prose-only advice:

- `factor`: the weak coverage area
- `status`: `missing` or `partial`
- `message`: short explanation
- `repair_target`: repo-owned asset to improve
- `reference`: local guidance doc when available
- `evidence`: observed signals that caused the gap

The repair loop is:

1. inspect the gap
2. update the owning repo asset
3. rerun `dev.kit repo`
4. verify the generated context changed for the right reason

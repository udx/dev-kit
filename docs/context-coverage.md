# Context Coverage

`.rabbit/context.yaml` is the structured coverage report for the repository.

It should answer three questions:

1. what did `dev.kit` detect?
2. what can be serialized cleanly?
3. what is still missing or only partial?

## What It Covers

`context.yaml` is for facts and deterministic transforms built from repo signals.

For the boundary between generated contract data and durable repo docs, see [Repo Contract Boundary](repo-contract-boundary.md).

Structured sources such as YAML, JSON, workflow refs, and manifest metadata should be parsed programmatically where possible. Prose sources such as Markdown docs, prompts, reviews, and session notes should be treated as interpreted intent unless they point to a concrete script, manifest, or command.

Typical sections include:

- generator metadata
- repo identity
- direct-read refs
- detected verify, build, and run commands with source hints
- structured gaps with factor, status, message, and evidence
- manifests as structured entries
- meaningful external contracts such as reusable workflows, images, versioned manifests, and dependency repos

Live GitHub state such as issues, pull requests, reviews, workflow runs, and alerts is intentionally not serialized. `context.yaml` should stay focused on repo-owned signals and deterministic dependency traces.

This is important: `context.yaml` is not trying to be a complete narrative. It is trying to be a usable contract with explicit coverage boundaries.

Observed facts and inferred relationships should stay visibly separate.

For example:

- manifest paths, workflow refs, and command sources are observed facts
- normalized dependency ownership or same-org repo matches are inferred relationships

That keeps the contract reviewable instead of magical.

## What Gaps Mean

`gaps` is not a generic TODO list. It is the set of engineering factors that `dev.kit` could not confirm fully from the available signals.

That means a gap can represent:

- something missing
- something incomplete
- something present but too thin to treat as strong coverage

Each gap entry should say:

- which factor is weak
- whether it is `missing` or `partial`
- the current message for that condition
- the observed evidence that led to that result

This is why context coverage testing should include broken or degraded repos, not only healthy ones.

## Gap Repair Loop

Gaps are meant to drive a repair loop:

1. read the gap and its evidence
2. identify the repo-owned source asset that should carry that contract
3. patch that source asset instead of editing generated output
4. rerun `dev.kit repo`
5. confirm that the regenerated context improved

That means gaps are part of maximum context discovery, not just an error report.

Example:

```yaml
gaps:
  - factor: config
    status: missing
    message: No explicit configuration contract was detected.
```

That should lead to a repo change such as adding config docs, manifest metadata, or a checked-in example file, then regenerating context.

## What Does Not Belong There

`context.yaml` should not become a prompt or a workflow script.

It is not the right place for:

- consumer behavior rules
- long-form operating guidance
- issue or PR handling advice
- subjective reasoning about what a consumer should do next
- local-only lesson artifacts

Those should stay outside the generated repo contract.

If a repo wants explicit behavior guidance for agents or reviewers, keep that in repo-owned docs or instruction files such as `AGENTS.md` or `CLAUDE.md`, not in `context.yaml`.

If a gap needs reusable interpretation guidance, prefer a compact reference in `docs/references/` over embedding that explanation into generated output.

## Coverage Strategy

The coverage model is repo-first:

- read README, docs, manifests, workflows, tests, and deploy config
- detect commands and factor signals
- trace deterministic custom contracts
- report gaps where coverage is weak

When Git metadata is available, deep file-usage scans should prefer tracked and unignored files so generated artifacts and dependency caches do not dominate context generation.

That keeps `context.yaml` useful both for healthy repos and for repos that need cleanup.

The measure of success is not perfect inference. It is:

- strong traceability where possible
- explicit unknowns where not
- a clear path to improve repo coverage over time

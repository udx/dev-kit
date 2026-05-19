# Repo Contract Boundary

`dev.kit` should help a repo explain itself without turning `.rabbit/context.yaml` into duplicated documentation.

## Split of responsibility

Use **repo-owned docs and assets** for durable human meaning:

- `README.md`
- `docs/*.md`
- `AGENTS.md`, `CLAUDE.md`, or similar team-owned instruction files
- checked-in example files when they fit the repo design
- manifest metadata such as `kind`, `description`, and `version`
- workflow and deploy docs near the repo assets they explain

Use **scripts and manifests** for programmatic execution:

- `Makefile`, `package.json`, and shell scripts
- `.github/workflows/*.yml`
- deploy manifests such as `deploy.yml`
- checked-in config examples when they are part of the runnable contract

Use **structured refs** for deterministic parsing:

- YAML and JSON manifests
- package and tool config files
- workflow references
- version, kind, and description metadata
- explicit command definitions

Use **prose and session material** for interpreted intent:

- Markdown docs and design notes
- issue, PR, and review discussions
- agent prompts and session summaries
- manual decisions that are not encoded in scripts yet

Use **`.rabbit/context.yaml`** for generated operational summary:

- direct-read refs
- detected commands and their sources
- structured gaps with evidence
- traced dependency contracts
- manifest inventory and provenance

## Practical rule

If a repo needs explanation, examples, or repair guidance, prefer fixing the repo-owned source asset first.

That source asset may be a reference doc that later gets normalized into `AGENTS.md` if the repo prefers a dedicated instruction surface.

If a repo needs a compact generated summary for tooling or safe repo-scoped execution, put it in `.rabbit/context.yaml`.

If a repo needs something to be executed safely by tools, keep that in a script or manifest rather than only in prose docs.

When both structured and prose sources exist, `dev.kit` should parse the structured source first and use prose to explain intent, repair guidance, or open decisions. That keeps automation deterministic while still preserving the human and agent context behind the repo design.

## Repair loop

1. `dev.kit repo` detects a gap or weak contract
2. fix the repo-owned doc, example, manifest, or workflow that should carry that meaning
3. rerun `dev.kit repo`
4. let the regenerated contract point back to the improved repo assets

## Example

If config coverage is weak:

- add repo-owned config docs or a checked-in example file when appropriate
- document required variables in `README.md` or `docs/`
- keep `.rabbit/context.yaml` limited to the resulting summary and evidence

That keeps the repo useful even when `dev.kit` is unavailable.

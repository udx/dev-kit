# Changes

### unreleased

- Expose repo-centric workflow status in `dev.kit`, `dev.kit env`, and `dev.kit repo` output so environment checks, context refresh, and gap repair appear as one repo-owned loop
- Clarify the repo contract boundary between deterministic structured parsing and interpreted prose/session intent

### 0.10.0

- Remove `dev.kit agent` so `.rabbit/context.yaml` is the single generated repo contract
- Make `dev.kit` non-destructive at home: inspect env, summarize context status, and guide to `dev.kit repo`
- Add generator metadata to `.rabbit/context.yaml` (`tool`, `repo`, `version`, `generated_at`)
- Make `dev.kit repo` ensure a minimal default repo structure for empty repos: `README.md`, `.github/dependabot.yml`, `.github/workflows/`, `.rabbit/`, and `docs/`
- Add recommended tooling repo output for `udx/worker`, `udx/reusable-workflows`, and `udx/github-rabbit-action`
- Fix global `--json` routing so `dev.kit --json <command>` reaches the requested command instead of falling back to home output
- Add machine-readable JSON output for `dev.kit uninstall --json --yes`
- Ignore exported Copilot session transcripts so local session history does not leak into release diffs
- Add a repo-owned workflow reference doc for developer and agent best practices tied to `dev.kit` commands
- Add a normalized repo-owned `AGENTS.md` for this repo, sourced from the workflow reference doc
- Clarify docs for build-default vs runtime env contracts and workflow triggers when releases are created by automation
- Clarify that scripts and YAML manifests are the execution layer, while docs guide developer and agent decisions
- Add integration and repo-design docs covering local/remote usage, scope, limits, and how repo contracts fit pipelines

### 0.9.0

- Add `dev.kit env` and env config controls so repo and agent output can reflect actual tool and credential availability
- Keep `.rabbit/context.yaml` focused on repo facts, tracing, commands, and gaps instead of inlining engineering practices and canonical workflow text
- Generate workflow guidance for `AGENTS.md` directly from the config catalogs and repo context, simplifying the boundary between repo context and agent behavior
- Rework the docs surface around that model: simplify the README, add focused `installation`, `context`, `agents`, and `integration` docs, and remove older overlapping overview/workflow/architecture pages
- Tighten GitHub-first workflow guidance across configs and generated agent instructions
- Remove `dev.kit learn` from the public command surface and trim the related configs, templates, and docs
- Clean up install and packaging flow with global npm postinstall cleanup and explicit npm-versus-curl ownership rules
- Improve manifest contract tracing with repo-owned evidence from top-level `version` headers, GitHub references, and actual usage paths
- Collapse duplicate dependency evidence into single repo entries and avoid false dependency traces from nested YAML metadata or placeholder GitHub refs
- Add optional `tests/real-repos.sh` coverage for local public/private repos and trim unused synthetic fixtures
- Add upgrade-first guidance to generated `AGENTS.md` and installation/experience docs so new sessions start from the current `dev.kit` build

### 0.7.0

- Dynamic PR description guide in AGENTS.md — fetches recent merged PRs via `gh api`, detects common section headings, includes best-structured PR as a reference example
- Dynamic issue update guide in AGENTS.md — detects comment patterns (checklists, structured sections, status tracking) from the authenticated user's recent issue comments
- Inject learned workflow rules from lesson artifacts into AGENTS.md — session-derived patterns appear directly in the workflow section, not just as file refs
- Fix bare template IDs in lesson artifacts — add flow template cases for `docs-first-alignment`, `workflow-tracing`, `verification-scope`, `legacy-reduction`, `agent-handoff`

### 0.6.0

- Switch default branch from `main` to `latest` so `npm create` tags align with the branch name
- Update all workflow triggers, release config, install script, and raw GitHub URLs to reference `latest`
- Add `latest` to recognized base branch names in development-workflows config
- Bump fallback default branch from `main` to `latest` in dev_sync

### 0.5.1

- Fix absolute local paths leaking into context.yaml and AGENTS.md refs
- Use GitHub tree URLs for directory refs, raw URLs for file refs
- Add `cross-repo-issue-context` practice from learned agent sessions
- Filter placeholder URLs (test/repo, org/repo) from learned references
- Add regression test for absolute path prevention

### 0.5.0

- Slim factors from 7 to 4: documentation, dependencies, config, pipeline
- Drop architecture, runtime, build_release_run — dev.kit detects repo/CI/CD signals, not app structure
- Merge test commands and deploy config into single pipeline factor
- Widen workflow tracing: catch direct actions (`uses: org/repo@ref`), docker actions, workflow images
- Resolve Docker images to same-org source repos (Docker Hub org ≠ GitHub org matching)
- Simplify documentation factor to binary present/missing
- Simplify README as pitch + quick start, move deep details to docs/
- Add bot feedback loop practice for PR reviews

### 0.4.0

- Add structured dependency resolution with cross-repo tracing
- Resolve same-org dependencies via `gh api` and sibling directory lookup
- Track file-level relationships (`used_by`) mapping current repo files to their dependencies
- Trace 6 dependency sources: workflow reuse, Docker images, Compose images, versioned YAML configs, GitHub URLs, npm packages
- Add `--force` flag to `dev.kit repo` for full dependency re-resolution
- Include structured dependencies in JSON output (`repo.json`, `agent.json`)
- Render dependency relationships in AGENTS.md with resolved metadata and source file mappings
- Add `dependency_trace_compose_files` and `dependency_trace_url_globs` to detection-signals.yaml

### 0.3.0

- Restructure AGENTS.md as a deterministic execution contract with layered sections
- Add 8 contract rules: no scanning, strict boundaries, manifests before code, context over memory, verify locally, follow workflow, reuse over invention, remember context
- Add GitHub context layer to `context.yaml` — open issues, recent PRs, security alerts via `gh api`
- Add 10 engineering practices from lessons learned: context-over-memory, manifests-before-code, reuse-over-invention, localhost-first, delivery-chain-traceability, structured-outcome-reporting, docs-first-alignment, config-over-code, legacy-reduction, verification-scope
- Add learning workflow patterns: docs-first-alignment, workflow-tracing, verification-scope, legacy-reduction, agent-handoff
- Enrich knowledge-base.yaml with GitHub as a context source
- Strengthen post-merge close-out reporting (exact URLs, versions, deltas)
- Remove `--scaffold` flag (created empty stubs — gap reporting is the useful part)
- Fix package name to `@udx/dev-kit` (matches npm registry)
- npm install support (`npm install -g @udx/dev-kit`)

### 0.2.1

- Fix release workflow trigger to match reusable-workflows pattern
- Add `workflow_dispatch` for manual re-triggers
- Enable OIDC provenance for npm publishing

### 0.2.0

- npm release workflow with OIDC provenance via `udx/reusable-workflows`
- GitHub releases created automatically on merge to default branch
- `dev.kit --version` flag
- Copilot review feedback fixes (JSON escaping, cache multi-line values, fixture portability)

### 0.1.0

Initial release.

- `dev.kit repo` — analyse repo structure, archetype detection, gap reporting, scaffold generation
- `dev.kit agent` — generate agent context (AGENTS.md + `.rabbit/context.yaml`) from repo signals
- `dev.kit learn` — multi-source lesson extraction from Claude, Codex, and Copilot sessions
- YAML config catalog for detection signals, archetype rules, scaffold templates, and workflows
- JSON output (`--json`) for all commands
- Shell completions (bash + zsh)
- Install/uninstall scripts
- Test suite with fixture repos (docker, wordpress, shell, php, workflow)

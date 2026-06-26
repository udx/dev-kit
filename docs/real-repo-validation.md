# Real Repo Validation

dev.kit is validated at two levels:

- fixtures verify deterministic contracts inside this repo
- real repos verify whether dev.kit reads repo-owned evidence well enough to guide work

Keep fixtures small. They should cover stable output shape, gap categories, manifest handling, and known regressions. They should not try to model every UDX repo.

Use real repos as optimization probes before a release. Run them read-only by default so the probe reports what dev.kit sees without changing the target repo.

## Local UDX Matrix

Use the matrix declared in `src/configs/repo-validation.yaml` when the listed repos are available locally.

Example:

```bash
bash tests/real-repos.sh --check ./reusable-workflows ./github-rabbit-action
```

The summary should be used to compare:

- home context status
- repo workflow status
- repo context status
- gap count
- read-first ref count

When one repo looks noisy or inconsistent, repair the strongest repo-owned gap or dev.kit normalization issue, rerun the matrix, and verify the output changed.

For config and manifest contract releases, include `udx/rabbit-automation-action`
when it is available locally. It is a useful probe because it relies on
repo-owned manifests instead of generic `.env.example` files.

## Public Repo Probes

Public repos are useful for compatibility checks, but they should be optional and pinned when used for repeatable release evidence. Upstream repos change for reasons unrelated to dev.kit.

Use public probes to test broad ecosystem recognition:

- package manifests and scripts
- docs-first repos
- workflow-only repos
- container repos

Do not assert exact output for moving public repos in the default suite.

## Write Mode

`tests/real-repos.sh --write` generates `.rabbit/context.yaml` in the target repo. Use it only for temp clones or repos intentionally selected for context regeneration.

## Release Verification

Before reporting a release as published, verify each source precisely:

- GitHub PR is merged into the release branch.
- GitHub release and tag exist for the intended version.
- Release workflow completed successfully.
- npm registry API reports the intended dist-tag and version.
- npm tarball URL returns a successful response.
- npmjs.com package page is treated as optional UI evidence because it can lag
  behind registry metadata.

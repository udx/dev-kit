# Release

This repo releases `@udx/dev-kit` through the release workflow on the release
branch. Release-bound PRs should make the intended package version, changelog,
generated context, and validation evidence explicit before merge.

## Pre-Actions

Before opening or updating a release-bound PR:

- Check the currently published version through GitHub releases and npm.
- If the current `package.json` version is already published, bump to the next
  intended version in `package.json` and `package-lock.json`.
- Add pending user-facing changes under that new version in `changes.md`; keep
  already published versions as historical records.
- Run `dev.kit repo` after repo contract or release metadata changes so
  `.rabbit/context.yaml` records the current generator version.
- Run the focused fixture check first, then `make test`, before asking for
  review or merge.

## Strategy

- Treat `changes.md` as the release intent. Published versions are immutable
  history; new work goes under the next intended version.
- Use the next minor version for ordinary `0.x` feature releases. A `0.x`
  minor may change generated context or detection behavior.
- Reserve milestone jumps, such as `0.20.0`, for intentional contract shifts:
  removing deprecated surfaces, changing manifest/interface strategy, or
  making output changes that users should notice before upgrading.
- Keep release mechanics in GitHub Actions and package metadata, not in
  generated context.
- Use `docs/real-repo-validation.md` for optional local probe strategy and
  post-release verification evidence.
- Verify GitHub release evidence and npm registry evidence separately before
  reporting a release as published.

# Dependency Contract Surfaces

External execution-shaping dependencies should be traceable from repo-owned assets.

`dev.kit` should only treat a dependency as meaningful when the repo points to it through a contract surface that affects how the repo is built, verified, or deployed.

## Common dependency contract surfaces

Dependency contracts are often declared through:

- reusable workflow refs in `.github/workflows/*.yml`
- image refs in `Dockerfile`, `compose.yaml`, or deploy manifests
- versioned YAML/JSON manifests with source repo metadata
- focused docs that explain how an external repo shapes execution

## Practical rule

When dependency gaps are detected:

1. point to the repo asset that should trace the external contract
2. prefer explicit refs and metadata over implied tool knowledge
3. keep the dependency explanation in the repo, not only in agent memory

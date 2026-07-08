# Smart Dependency Detection

`dev.kit repo` does more than list local files. It also traces dependency repos and external contracts that shape the repo design.

## What It Detects

Cross-repo tracing currently covers sources such as:

- reusable GitHub workflows
- Docker images
- Docker actions and workflow container images
- versioned YAML references

These are then mapped into dependency entries in `.rabbit/context.yaml`.

Ordinary marketplace-style GitHub action refs and package-manager inventories are intentionally lower priority. They are usually standard ecosystem knowledge, not repo-specific contract context.

## Resolution Model

The tracing model is deterministic.

If `dev.kit` can resolve a dependency confidently, it records:

- the dependency target
- its kind
- whether it was resolved
- where it is used in the current repo

Example:

```yaml
version: example.dev/runtime-v1/config
```

That kind of versioned manifest header can be normalized into a dependency repo contract when the repo evidence is strong enough.

For versioned manifests such as `udx.dev/dev.kit/v1`, the domain is treated as an org hint and the repo segment is normalized into a GitHub-style slug such as `udx/dev.kit`.

When possible, same-org dependencies are resolved from repo refs, local sibling repos, and available GitHub metadata. Docker images may also be mapped back to likely source repos.

The point is not to invent a full dependency graph. The point is to make repo-shaping external contracts visible and traceable without flooding the contract with standard tooling inventory.

The repo command can also point users toward a few known supporting repos when they need shared workers, reusable workflows, or related repo tooling:

- `udx/worker`
- `udx/reusable-workflows`
- `udx/github-rabbit-action`

## Why It Matters

This is what makes `context.yaml` more useful than a plain file inventory.

A repo often depends on workflows, images, or external modules that live elsewhere. If those relationships are visible in the generated contract, maintainers can repair the repo and its dependency contracts with less guesswork.

## Coverage Limits

Dependency detection still follows the same rule as the rest of `dev.kit`: report what can actually be observed.

If a dependency cannot be resolved confidently from the available repo and environment signals, it should remain partial rather than be invented.

That is also why unresolved or weak dependency coverage should feed the broader gap-repair loop instead of being hidden.

# Configuration Contract Surfaces

Repo configuration contracts do not need to live in one file type.

`dev.kit` should treat configuration as a **repo-owned contract surface** and point repairs to the asset that should become explicit.

## Common config contract surfaces

Configuration is often declared through:

- `.env.example`, `.env.sample`, or `.env.template`
- focused repo docs such as `README.md` or `docs/config.md`
- deploy manifests such as `deploy.yml`
- versioned YAML/JSON manifests with explicit config metadata
- checked-in example config files when the repo uses a custom format

## Build defaults and runtime overlays

Some repos intentionally split config responsibility across build and deploy stages.

Example pattern:

- `.env.example` declares the variables needed for local builds, CI, or a default `npm build`
- deploy manifests, runtime docs, or workflow/env wiring declare how host/container env overrides are injected at deploy or start time
- the running server resolves runtime values from host env rather than relying only on build-time client env expansion

That is still one coherent repo contract as long as the split is explicit and checked in.

## Practical rule

When config gaps are detected:

1. prefer the repo file already closest to the truth
2. make required variables or settings explicit there
3. avoid forcing one universal packaging style
4. keep the contract checked in so humans and agents can review it

If a repo builds once and deploys many times, prefer documenting both:

- the default config needed to build successfully
- the runtime config surface that host, container, or deployment tooling will override later

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

## Practical rule

When config gaps are detected:

1. prefer the repo file already closest to the truth
2. make required variables or settings explicit there
3. avoid forcing one universal packaging style
4. keep the contract checked in so humans and agents can review it

# Environment Config

`dev.kit` is environment-aware. Generated output depends on what can actually be observed from the current machine, available tools, and allowed credentials.

That is why environment detection is a first-class command:

```bash
dev.kit env
```

## What `dev.kit env` Does

`dev.kit env` reports:

- required tools such as `git`, `gh`, `npm`, `docker`, `jq`, and `yq`
- cloud tools when present
- recommended helper tools
- the current env config file when it exists

This lets `dev.kit` describe real capability instead of pretending repo or dependency resolution is available when it is not.

That output should shape subsequent behavior:

- repo guidance should only recommend capabilities that are actually available
- dependency tracing should be thinner when required tools or auth are unavailable
- repo repair guidance should stay honest about what can be done from the current environment

## `--config`

Use:

```bash
dev.kit env --config
```

This creates or updates:

```text
$DEV_KIT_HOME/config/env.yaml
```

Example:

```bash
dev.kit env --config
dev.kit env
```

The goal is a small, explicit control surface for disabling tools or credentials you do not want `dev.kit` to use.

## Config Shape

Example:

```yaml
kind: envConfig
version: udx.dev/dev.kit/v1

config:
  disabled_tools:
    - gh
    - docker
  disabled_credentials:
    - gh
    - aws
```

This does not uninstall tools or revoke credentials. It only changes what `dev.kit` treats as available for its own detection and guidance.

## Why This Matters

Environment state affects context coverage.

Examples:

- if `gh` is unavailable or disabled, dependency-repo tracing and guidance should be thinner
- if a cloud credential is intentionally disabled, `dev.kit` should not claim that cloud path is usable
- if only local repo signals are available, generated output should stay grounded in those signals

That makes the generated contract more honest and more reusable across local and controlled environments.

In other words, `dev.kit env` is not a side utility. It is the capability layer that makes later repo outputs trustworthy.

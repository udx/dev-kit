# Integration

Use `dev.kit` where you want a repo-local contract that helps developers, agents, and automation work from the same declared surfaces.

## Where it fits

`dev.kit` is a good fit when a repo has:

- scripts, manifests, or workflows that shape real execution
- docs that explain how those repo surfaces fit together
- a need to reduce guesswork for local work, remote agents, or CI/CD handoffs

It is most useful when the repo wants a compact generated summary without turning docs into automation output.

## Local and remote usage

### Local

Use local execution when:

- you are actively editing the repo
- local tools and auth are available
- you want `dev.kit env` to reflect the real machine capabilities

Typical loop:

```bash
dev.kit
dev.kit repo
```

### Remote or cloud agent

Use remote or cloud execution when:

- the repo already includes committed docs and manifests that define the contract
- the agent needs repo-local facts more than local machine state
- you want execution to stay grounded in committed assets rather than personal workstation setup

In that case, committed docs, scripts, workflows, manifests, and `.rabbit/context.yaml` should carry the important contract.

## Scope

`dev.kit` is for:

- repo contract discovery
- gap detection and repair loops
- dependency and manifest tracing
- environment-aware repo guidance

It is not for:

- replacing CI/CD systems
- inventing app architecture
- encoding every team decision into generated output
- turning docs into the execution layer

## Limitations

- `dev.kit` only reports what the repo and current environment actually reveal
- weak or missing repo signals produce partial gaps, not invented certainty
- local environment state affects what can be traced confidently
- generated context should summarize, not replace, repo-owned docs and manifests

## When to initialize

Initialize or refresh when:

- starting work in a repo for the first time
- after meaningful repo workflow or manifest changes
- when `.rabbit/context.yaml` is missing or stale
- when a gap suggests the repo contract has become unclear

## Where to integrate

Integrate `dev.kit` into:

- repo setup and contributor workflow docs
- agent instruction surfaces such as `AGENTS.md`
- CI/CD or release workflows when regeneration checks are useful
- repo maintenance loops that need contract validation after changes

## Question and answer examples

**Question:** Should `dev.kit` be used only locally?  
**Answer:** No. It works best wherever the repo contract is committed and reviewable.

**Question:** What should remote agents rely on first?  
**Answer:** Repo-owned docs, scripts, manifests, and `.rabbit/context.yaml` when it exists.

**Question:** When should `dev.kit repo` run?  
**Answer:** After repo contract changes or when context is missing or stale.

**Question:** What if a repo has both docs and workflows?  
**Answer:** That is expected. Workflows/scripts execute; docs explain behavior and decisions.

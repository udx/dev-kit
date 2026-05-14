# Repo Design

`dev.kit` depends on **repo design** more than app implementation.

The better a repo declares its own contracts, the more useful `dev.kit` can be without guessing.

## Why repo design matters

Good repo design gives agents and developers:

- clear command surfaces for build, verify, run, and deploy
- explicit manifests and workflow files for programmatic execution
- repo-owned docs for behavior, interpretation, and decision points
- stable places to repair gaps without editing generated output

That makes the repo easier to work with locally, remotely, and through automation.

## How it fits into pipelines

`dev.kit` does not replace CI/CD.

It helps normalize the repo contract that pipelines and agents already depend on.

Typical fit:

1. scripts, workflows, and manifests define what actually runs
2. docs explain why those surfaces exist and how to use them
3. `dev.kit repo` serializes the observed contract into `.rabbit/context.yaml`
4. gaps point maintainers back to the repo asset that should become clearer

## Practical design rules

- keep executable behavior in scripts and YAML manifests
- keep behavior guidance and smart-search material in docs
- prefer one clear source surface over many overlapping partial ones
- add metadata near manifests so ownership and purpose are traceable
- make build, verify, and deploy paths explicit even if they are split across files

## Question and answer examples

**Question:** What makes a repo easy for `dev.kit` to understand?  
**Answer:** Clear scripts, workflows, manifests, and docs that each carry one kind of responsibility.

**Question:** Should docs contain executable workflow only?  
**Answer:** No. Docs explain behavior and decisions; scripts and manifests should remain the runnable layer.

**Question:** Why does repo design help pipelines?  
**Answer:** It reduces guesswork, keeps workflow edges reviewable, and makes automation easier to trace.

**Question:** What should happen when coverage is weak?  
**Answer:** Improve the repo-owned source asset, then rerun `dev.kit repo` so the contract reflects the fix.

## Anti-patterns

- commands that exist only in prose
- manifests with no ownership or purpose metadata
- docs that duplicate generated context
- generated files edited to hide repo design gaps

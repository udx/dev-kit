# Agent and Developer Workflow

This reference doc is for **repo-owned workflow guidance** that should stay close to `dev.kit` command usage.

Use it for compact practices, decision rules, and examples that help developers and agents work from the same contract.

## Default loop

1. make sure the local `dev.kit` install is current
2. run `dev.kit`
3. read `.rabbit/context.yaml` when context exists
4. run `dev.kit repo` after repo changes or when context is missing/stale
5. repair repo-owned gaps in source assets, not in generated output

## Practical rules

- prefer repo-declared commands over remembered habits
- treat `.rabbit/context.yaml` as generated evidence, not hand-authored guidance
- keep workflow guidance in repo-owned docs such as `docs/references/`
- when a gap appears, patch the owning repo asset and rerun `dev.kit repo`
- use docs to explain intent; use manifests and scripts to declare execution

## Question and answer examples

**Question:** Where should an agent start?  
**Answer:** Run `dev.kit`, then read `.rabbit/context.yaml` and the highest-priority refs it points to.

**Question:** What if `.rabbit/context.yaml` is missing?  
**Answer:** Run `dev.kit repo`, then use the generated context instead of scanning broadly.

**Question:** What if the repo shows a gap?  
**Answer:** Fix the repo-owned source asset that should declare that contract, then rerun `dev.kit repo`.

**Question:** Where should best practices live?  
**Answer:** In repo-owned docs like this file, not in generated context output.

**Question:** When should GitHub data be fetched live?  
**Answer:** Only when the current task needs issues, PRs, reviews, workflow runs, or alerts.

## Good repo-owned guidance

- short command-driven workflows
- examples tied to real repo assets
- repair loops for common gap types
- explicit boundaries between generated output and maintained docs

## Avoid

- duplicating `.rabbit/context.yaml`
- hiding gaps by editing generated files
- hardcoding app-specific structure into general `dev.kit` rules
- spreading the same workflow guidance across many overlapping docs

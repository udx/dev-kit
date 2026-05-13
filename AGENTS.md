# AGENTS.md

_Normalized repo-owned guidance for agents. Keep it aligned with `docs/references/agent-dev-workflow.md` and `.rabbit/context.yaml`._

## Repo: dev.kit

- context: ./.rabbit/context.yaml
- workflow_ref: ./docs/references/agent-dev-workflow.md

## Start here

1. Make sure `dev.kit` itself is current, then run `dev.kit`.
2. Read `.rabbit/context.yaml` first when it exists.
3. Read the highest-priority refs and manifests that `context.yaml` points to.
4. Run `dev.kit repo` after repo changes or when context is missing or stale.

## Operating rules

- treat `.rabbit/context.yaml` as generated repo evidence, not hand-authored guidance
- prefer repo-declared commands and manifests over guessed behavior
- keep durable workflow guidance in repo-owned docs, especially `docs/references/agent-dev-workflow.md`
- when a gap appears, repair the owning repo asset and rerun `dev.kit repo`
- use live GitHub data only when the task needs issues, PRs, reviews, workflow runs, or alerts

## Workflow

- read: `README.md`, `changes.md`, `deploy.yml`, `.github/workflows/`, `docs/`
- verify: `make test`

## Notes

- `AGENTS.md` is optional and repo-owned in this repo
- the reference doc is the fuller source of examples, Q&A, and best practices

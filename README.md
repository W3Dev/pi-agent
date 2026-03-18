# pi-agent

Reusable GitHub Actions packaging for running the `pi` coding agent from `/pi ...` comments.

## What this repo contains

- `.github/workflows/pi-comment-agent.yml`: reusable workflow that installs `pi`, configures models, collects repo context, runs the agent, optionally pushes changes, and posts a comment back.
- `scripts/pi-agent-runner.sh`: shared shell runner used by the reusable workflow.
- `examples/caller-workflow.yml`: minimal workflow to copy into any target repository.

## Target repo setup

Create these in the consuming repository:

- Repository secret: `PI_MODEL_JSON`
- Repository variable: `PI_ALLOW_PUSH` with `true` or `false`
- Workflow file copied from `examples/caller-workflow.yml`

The caller workflow is responsible for:

- listening to `issue_comment` and `pull_request_review_comment`
- authorizing who may use `/pi`
- extracting event metadata
- calling the reusable workflow in this repo

The reusable workflow is responsible for:

- checking out the target repo
- installing `pi`
- writing `~/.pi/agent/models.json`
- listing available models for debugging
- collecting git context for the agent
- running the shared runner script
- optionally committing and pushing changes on PR branches
- posting the final markdown report back to the issue or PR

## Default behavior

Defaults:

- `pi_cli_version`: `0.58.3`
- `pi_model`: `zai/glm-5`
- push disabled unless `PI_ALLOW_PUSH=true`

## Notes

- The reusable workflow currently checks out this repo from `W3Dev/pi-agent`. Update that repository reference if you publish it elsewhere.
- `issue_comment` workflows are still defined by the caller repository's default branch. This repo reduces the logic in caller repos, but it does not change GitHub's event model.

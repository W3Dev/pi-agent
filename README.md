# pi-agent

Reusable GitHub Actions packaging for running the `pi` coding agent from `/pi ...` comments with minimal per-repository setup.

The workflow now uses a routed agent model:

- `general`: fallback agent for mixed or ambiguous requests
- `ask`: answers questions, reviews code, and explains behavior
- `build`: makes repository changes for implementation requests
- `plan`: produces scoped implementation plans without coding by default

The general router decides which agent to invoke based on the comment text.

## What this repo contains

- `.github/workflows/pi-comment-agent.yml`: reusable workflow that screens `/pi` comments, authorizes supported users, resolves PR metadata, installs `pi`, runs the routed agent flow, optionally pushes changes, and posts a comment back.
- `scripts/pi-agent-runner.sh`: shared shell runner that routes requests to `ask`, `build`, `plan`, or `general`.
- `examples/caller-workflow.yml`: tiny trigger-only wrapper for consuming repositories.

## Target repo setup

Create these in the consuming repository:

- Repository secret: `PI_MODEL_JSON`
- Repository variable: `PI_ALLOW_PUSH` with `true` or `false`
- Workflow file copied from `examples/caller-workflow.yml`

The caller workflow is responsible only for:

- listening to `issue_comment` and `pull_request_review_comment`
- calling the reusable workflow in this repo

The reusable workflow is responsible for:

- checking whether the comment starts with `/pi`
- authorizing supported comment authors (`OWNER`, `MEMBER`, `COLLABORATOR`)
- extracting event metadata and resolving PR branch details
- checking out the target repo
- installing `pi`
- writing `~/.pi/agent/models.json`
- listing available models for debugging
- collecting git context for the agent
- running the shared runner script
- routing the request to the best-fit agent
- optionally committing and pushing changes on PR branches
- posting the final markdown report back to the issue or PR

## Default behavior

Defaults:

- `pi_cli_version`: `0.58.3`
- `pi_model`: `zai/glm-5`
- push disabled unless `PI_ALLOW_PUSH=true`

Minimal wrapper:

```yaml
jobs:
  pi:
    uses: W3Dev/pi-agent/.github/workflows/pi-comment-agent.yml@main
    with:
      pi_allow_push: ${{ vars.PI_ALLOW_PUSH || 'false' }}
    secrets:
      pi_model_json: ${{ secrets.PI_MODEL_JSON }}
```

Example requests:

- `/pi explain why this workflow fails on forked PRs`
- `/pi add support for /pi plan comments in the caller workflow`
- `/pi plan how to split the runner into reusable prompt templates`

## Notes

- The reusable workflow currently checks out this repo from `W3Dev/pi-agent`. Update that repository reference if you publish it elsewhere.
- GitHub still requires the consuming repository to define the event trigger workflow on its default branch. This repo keeps that wrapper as small as possible, but it cannot remove that GitHub platform requirement.

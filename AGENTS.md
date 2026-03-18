# Repository Guidelines

## Project Structure & Module Organization

This repository packages a reusable GitHub Actions workflow for running the `pi` coding agent from `/pi` comments.

- `.github/workflows/pi-comment-agent.yml`: reusable workflow that checks out the target repo, installs `pi`, gathers git context, runs the agent, and posts the final comment.
- `scripts/pi-agent-runner.sh`: shared Bash runner that builds the prompt, invokes `pi`, and writes `.pi-agent/*` artifacts.
- `examples/caller-workflow.yml`: example workflow for consuming repositories.
- `README.md`: setup and usage notes for adopters.

Keep workflow logic in `.github/workflows/` and reusable shell behavior in `scripts/`. Treat `.pi-agent/` as generated runtime output, not source.

## Build, Test, and Development Commands

- `bash scripts/pi-agent-runner.sh`: run the local runner when required environment variables are set.
- `bash -n scripts/pi-agent-runner.sh`: syntax-check the shell script.
- `git diff -- .github/workflows scripts examples`: review changes in the main automation paths.

There is no build step or package manifest in this repository today. Prefer small, verifiable edits to YAML and shell scripts.

## Coding Style & Naming Conventions

Use 2 spaces for YAML indentation and 2 spaces for Markdown list indentation when needed. Shell scripts should start with `#!/usr/bin/env bash` and `set -euo pipefail`.

Prefer:

- lowercase, hyphenated workflow and file names
- uppercase snake case for environment variables such as `PI_MODEL_JSON`
- short, explicit step names in workflows

Keep scripts POSIX-aware where practical, but Bash is the current target.

## Testing Guidelines

This repo does not yet include an automated test suite. Validate changes with targeted checks:

- run `bash -n scripts/pi-agent-runner.sh`
- review workflow YAML for input, secret, and permission changes
- if editing the example workflow, confirm its `uses:` reference and passed inputs still match the reusable workflow

When adding tests later, place them under `tests/` and name them after the unit under test, for example `tests/pi-agent-runner.test.sh`.

## Commit & Pull Request Guidelines

There is no existing commit history yet, so use concise imperative commit subjects such as `Add PR diff context to final comment`. Keep subjects focused on one change.

Pull requests should include:

- a short description of the behavior change
- linked issue or context, if applicable
- sample workflow logs or comment output for changes that affect runtime behavior

## Security & Configuration Tips

Never commit real secrets. `PI_MODEL_JSON` must remain a repository secret in consuming repos, and `PI_ALLOW_PUSH` should default to `false` unless push-back behavior is explicitly required.

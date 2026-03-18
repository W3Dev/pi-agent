#!/usr/bin/env bash
set -euo pipefail

mkdir -p .pi-agent

MODEL_NAME="${PI_MODEL:-zai/glm-5}"

cat > .pi-agent/prompt.txt <<PROMPT
You are an autonomous repository coding agent running inside GitHub Actions.

User request:
${PI_COMMAND}

Execution rules:
- Work only in the checked out repository.
- Inspect the codebase before changing files.
- Prefer minimal, targeted edits.
- If the request is ambiguous, make the safest reasonable interpretation and explain it.
- If this is a PR, prioritize files already touched by the PR unless the request clearly requires broader changes.
- Run or suggest lightweight validation where practical.
- At the end, produce:
  1. A short summary of what you changed.
  2. Risks or assumptions.
  3. Validation steps performed.
  4. A concise markdown report suitable for posting as a GitHub comment.

Repository context:
- Event: ${PI_EVENT_NAME}
- Actor: ${PI_ACTOR}
- Is PR: ${PI_IS_PR}
- Base ref: ${PI_BASE_REF}
- Head ref: ${PI_HEAD_REF}

Useful local context files:
- .pi-agent/git-status.txt
- .pi-agent/current-branch.txt
- .pi-agent/recent-commits.txt
- .pi-agent/file-list.txt
- .pi-agent/pr-files.txt
- .pi-agent/pr-diff-stat.txt

Output instructions:
- Make any needed file changes directly in the repo.
- Also write a markdown report to .pi-agent/analysis.md.
- Keep the report under 6000 characters if possible.
PROMPT

(pi -p "/model" > .pi-agent/models.txt) || true

pi --model "$MODEL_NAME" -p "$(cat .pi-agent/prompt.txt)" | tee .pi-agent/pi-stdout.txt

if [[ ! -f .pi-agent/analysis.md ]]; then
  {
    echo "## pi agent report"
    echo
    echo "### Request"
    echo
    printf '%s\n' "${PI_COMMAND}"
    echo
    echo "### Result"
    echo
    echo "The agent completed a run. See the attached artifacts for the raw output."
    echo
    echo "### Raw output excerpt"
    echo
    echo '```text'
    tail -n 120 .pi-agent/pi-stdout.txt || true
    echo '```'
  } > .pi-agent/analysis.md
fi

CHANGED_FILES="$(git status --porcelain | wc -l | tr -d ' ')"

{
  echo "## pi agent result"
  echo
  echo "**Request**"
  echo
  echo '```text'
  printf '%s\n' "${PI_COMMAND}"
  echo '```'
  echo
  if [[ "${CHANGED_FILES}" != "0" ]]; then
    echo "**Repository changes detected:** yes"
  else
    echo "**Repository changes detected:** no"
  fi
  echo
  if [[ -f .pi-agent/pr-diff-stat.txt ]] && [[ -s .pi-agent/pr-diff-stat.txt ]]; then
    echo "<details><summary>PR diff context</summary>"
    echo
    echo '```text'
    cat .pi-agent/pr-diff-stat.txt
    echo '```'
    echo
    echo "</details>"
    echo
  fi
  cat .pi-agent/analysis.md
  echo
  if [[ "${PI_ALLOW_PUSH}" == "true" ]]; then
    echo
    echo "_Auto-push is enabled for this workflow run._"
  else
    echo
    echo "_Auto-push is disabled. Changes, if any, remain only in the workflow workspace unless you enable PI_ALLOW_PUSH._"
  fi
} > .pi-agent/final-comment.md

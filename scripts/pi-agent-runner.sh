#!/usr/bin/env bash
set -euo pipefail

mkdir -p .pi-agent

MODEL_NAME="${PI_MODEL:-aistack/coding}"

normalize_agent_name() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    ask|build|plan|general)
      printf '%s\n' "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
      ;;
    *)
      printf 'general\n'
      ;;
  esac
}

build_prompt() {
  local agent_name="$1"

  case "$agent_name" in
    ask)
      cat <<PROMPT
You are the "ask" agent for an autonomous repository assistant running inside GitHub Actions.

User request:
${PI_COMMAND}

Primary objective:
- Answer the request, explain behavior, review code, or provide guidance.
- Do not make file changes unless the request explicitly requires edits.

Execution rules:
- Work only in the checked out repository.
- Inspect the codebase before answering.
- Prefer explanation, diagnosis, and review over implementation.
- If this is a PR, focus first on files already touched by the PR.
- If you do change files, keep edits minimal and justify them in the report.
- Write a concise markdown report to .pi-agent/analysis.md.

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
PROMPT
      ;;
    build)
      cat <<PROMPT
You are the "build" agent for an autonomous repository assistant running inside GitHub Actions.

User request:
${PI_COMMAND}

Primary objective:
- Implement the requested change directly in the repository.

Execution rules:
- Work only in the checked out repository.
- Inspect the codebase before changing files.
- Prefer minimal, targeted edits.
- If this is a PR, prioritize files already touched by the PR unless broader changes are required.
- Run or suggest lightweight validation where practical.
- Write a concise markdown report to .pi-agent/analysis.md covering changes, risks, and validation.

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
PROMPT
      ;;
    plan)
      cat <<PROMPT
You are the "plan" agent for an autonomous repository assistant running inside GitHub Actions.

User request:
${PI_COMMAND}

Primary objective:
- Produce an implementation plan, not code changes.

Execution rules:
- Work only in the checked out repository.
- Inspect the codebase before planning.
- Do not modify repository files unless creating the markdown report at .pi-agent/analysis.md.
- Break the work into concrete steps, note risks, and call out any assumptions.
- If this is a PR, anchor the plan to the PR context first.

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
PROMPT
      ;;
    *)
      cat <<PROMPT
You are the "general" agent for an autonomous repository coding assistant running inside GitHub Actions.

User request:
${PI_COMMAND}

Primary objective:
- Choose the safest effective response for the request, whether that is implementation, explanation, review, or planning.

Execution rules:
- Work only in the checked out repository.
- Inspect the codebase before changing files.
- Prefer minimal, targeted edits.
- If the request is ambiguous, make the safest reasonable interpretation and explain it.
- If this is a PR, prioritize files already touched by the PR unless the request clearly requires broader changes.
- Run or suggest lightweight validation where practical.
- At the end, write a concise markdown report to .pi-agent/analysis.md that summarizes changes or guidance, risks, and validation.

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
PROMPT
      ;;
  esac
}

cat > .pi-agent/router-prompt.txt <<PROMPT
You are the routing agent for an autonomous repository assistant.

Classify the user's request into exactly one of these agent names:
- ask: explanation, code review, debugging guidance, questions, analysis, or requests that mainly need an answer
- build: implementation, edits, fixes, refactors, tests, workflow changes, or requests that mainly need repository changes
- plan: step-by-step implementation planning, scoping, breakdowns, or architecture planning without immediate code changes
- general: mixed or unclear requests that do not strongly fit the above

User request:
${PI_COMMAND}

Repository context:
- Event: ${PI_EVENT_NAME}
- Is PR: ${PI_IS_PR}

Respond with one word only: ask, build, plan, or general.
PROMPT

ROUTER_RAW_OUTPUT="$(
  pi --model "$MODEL_NAME" -p "$(cat .pi-agent/router-prompt.txt)" 2>/dev/null || true
)"
printf '%s\n' "$ROUTER_RAW_OUTPUT" > .pi-agent/router-output.txt

SELECTED_AGENT="$(
  printf '%s\n' "$ROUTER_RAW_OUTPUT" | grep -Eio 'ask|build|plan|general' | tail -n 1 || true
)"
SELECTED_AGENT="$(normalize_agent_name "${SELECTED_AGENT:-general}")"

printf '%s\n' "$SELECTED_AGENT" > .pi-agent/selected-agent.txt
build_prompt "$SELECTED_AGENT" > .pi-agent/prompt.txt

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
  echo "**Assigned agent:** \`${SELECTED_AGENT}\`"
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

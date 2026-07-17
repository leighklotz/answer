#!/usr/bin/env bash 

set -o pipefail
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/functions.sh"

# We use a Heredoc with 'EOF' (quoted) to load the prompt into a variable.
# This prevents "Quote Collapse"—the shell will treat this entire block 
# as literal text, meaning we don't have to escape every single quote or 
# backslash inside your instructions for the LLM.
read -r -d '' GIT_COMMIT_PROMPT << 'EOF'
Below is the output of a git bash session. Read the logs carefully. Your goal is to generate a single bash code fence containing commands to add unstaged changes and commit all currently staged files, while respecting user scope.

If no changes exist (all diffs are empty), output exactly: echo "no changes"
Otherwise, use one or more commands of this exact format:

git add <path> file1 file2 ...  # Only include if there are modified/new tracked files that aren't staged yet
git commit <path> \
  -m "<Brief summary>" \
  -m "- <Description 1>"

RULES FOR SCOPE & TARGETING (CRITICAL):
1. DIRECTORY PATHS (e.g., ".", "src/", "tests/"): If the user provided a directory path in their command, use that exact same path as an argument for both `git add` and `git commit`. This ensures we only act on changes within that specific scope.
2. REVISION RANGES (e.g., "main..HEAD", "origin/master...current"): If the arguments look like a Git range or branch comparison, DO NOT use them as targets in your command (i.e., do not run `git add main..HEAD`). Instead, treat those diffs purely as context for an accurate commit message and perform a standard `git commit -m "..."` of what is currently staged.
3. UNTRACKED FILES: Ignore any untracked files that are not part of the provided scope or revision range.
4. IMPERATIVE MOOD: Use imperative mood (e.g., "Add feature" not "Added feature").
5. FORMATTING: Ensure all strings are properly quoted and there is no commentary after the code fence.
6. ESCAPING: Properly escape special characters inside bash quotes so the command works when executed by a shell.
EOF

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "🦶$(basename "$0"): PWD=$PWD is not in a git repository"
    exit 1
fi

function usage() {
    local p=$(basename "$0")
    echo "$p: [--help] | [--quiet] [git diff options] [--] [ask options]"
    echo $'- --quiet: suppress introductory message'
    echo $'- any next arguments until `--` are given to `git diff`'
    echo $'- all after a `--` is given as parameters for the LLM context (e.g., main..HEAD)'
}

GIT_DIFF_OPTIONS=""
ASK_OPTIONS=()

# Parse command line arguments: 
# Everything before '--' goes to git diff options.
# Everything after '--' goes into an array for the LLM conversation/context.
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            usage
            exit 1
            ;;
        --quiet|-q)
            QUIET=1
            shift
            ;;
        --)
            shift
            ASK_OPTIONS=("$@")
            break
            ;;
        *)
            GIT_DIFF_OPTIONS+="${1} "
            shift
            ;;
    esac
done

log_info "ASK_OPTIONS=${ASK_OPTIONS[*]}"
log_info "GIT_DIFF_OPTIONS=$GIT_DIFF_OPTIONS"

# The pipeline: 
# We feed the LLM the current working directory, repo root, and several layers of diffs.
(bx pwd;
 bx git rev-parse --show-toplevel;
 git diff --stat --no-merges ${GIT_DIFF_OPTIONS};
 bx git diff --numstat ${GIT_DIFF_OPTIONS};
 bx git diff ${GIT_DIFF_OPTIONS};
 bx git diff --cached ${GIT_DIFF_OPTIONS}) |
  ask -i "${ASK_OPTIONS[@]}" -- "$GIT_COMMIT_PROMPT" |
  answer |
  unfence |
  bash

# Capture the exit status of the last command in the pipe (thanks to pipefail)
STATUS=$?

if [ $STATUS -eq 2 ]; then
    log_warn "No changes detected."
    exit 0
fi

# Exit with the actual return code from the pipeline/execution
exit $STATUS

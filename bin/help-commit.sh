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
Analyze the provided git session output (PWD, Root, Branch, and Diffs). 
Your goal is to generate a single bash code fence containing commands to stage all unstaged changes and commit everything currently in the index, in one or more commit sets as appropriate.

### OUTPUT SCHEMA:
- If no changes exist $\rightarrow$ `echo "no changes"`
- Otherwise, provide one or commit sets, following this pattern:
  git add <paths> (if there are unstaged/new files)
  git commit -m "<Imperative summary>" \
             -m "- <Detailed description line 1>"

### LOGIC RULES:
1. TARGETING: Always provide `git add` and `git commit` targets as paths relative to the current PWD. If a diff argument is a range (e.g., `main..HEAD`), use it ONLY for context to write the commit message; NEVER include ranges in `git add` or `git commit` targets.
2. UNTRACKED FILES: Only stage/commit files explicitly identified in the provided diffs.
3. COMMIT MESSAGE STYLE:
   - Summary: Use imperative mood (e.g., "Add feature" not "Added feature").
   - Detail: Include a bulleted list (- ) describing changes, specifically mentioning new executable modes or significant file creations if present.
4. SHELL SAFETY:
   - Ensure all strings are properly quoted and special characters escaped for bash execution and bash string interpolation and quoting rules.
   - Note the backquote character which introduces code in markdown actually *executes* code in double-quote strings inside bash so it must be quoted inside double quoted strings.
   - No commentary outside the code fence.
EOF


if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    log_error "PWD=$PWD is not in a git repository"
    exit 1
fi

function usage() {
    local p=$(basename "$0")
    echo "$p: [--help] | [--quiet] [--dry-run | -n] [git diff options] [--] [ask options]"
    echo $'- --quiet: suppress introductory message'
    echo $'- any next arguments until `--` are given to `git diff`'
    echo $'- all after a `--` is given as parameters for the LLM context (e.g., main..HEAD)'
}

ASK_OPTIONS=()
GIT_DIFF_OPTIONS=""
DRY_RUN=""
QUIET=""

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
        --dry-run|-n)
            DRY_RUN=1
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
 bx git branch --show-current;
 bx git diff --stat --no-merges ${GIT_DIFF_OPTIONS};
 bx git diff --numstat ${GIT_DIFF_OPTIONS};
 bx git diff ${GIT_DIFF_OPTIONS};
 bx git diff --cached ${GIT_DIFF_OPTIONS}) 2>&1 |
  ask -i "${ASK_OPTIONS[@]}" -- "$GIT_COMMIT_PROMPT" |
  answer | { [ -n "$DRY_RUN" ] && cat || unfence | bash; }

# Capture the exit status of the last command in the pipe (thanks to pipefail)
STATUS=$?

if [ $STATUS -eq 2 ]; then
    log_warn "No changes detected."
    exit 0
fi

# Exit with the actual return code from the pipeline/execution
exit $STATUS

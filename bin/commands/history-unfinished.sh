#!/bin/bash
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"

# history-unfinished.sh — List bash history sessions with Hallux-enhanced title/note generation
#
# Usage: history-unfinished.sh [-d DATE] [-p|--project] [-a|--all] [-h|--help]
#
# Output: markdown table for glow
#
# Requires: hallux (ask, lx, hx), jq, awk

set -euo pipefail

source "${SCRIPT_DIR}/hx-bootstrap.sh"
hx core

# ─── Hallux Settings ────────────────────────────────────────────────────────────
# Hallux agent binary — adjust if not on PATH

# Prompt template for title/notes generation
PROMPT='You are summarizing a bash session history file. Based on the file content below, produce EXACTLY two lines in this format:
TITLE: <one-line title, max 80 chars, derived from git commits / dirs / edited files>
NOTES: <one-line notes, max 120 chars, describe in-progress work or uncommitted state>

Rules:
- TITLE must be a noun phrase, not a sentence.
- NOTES should mention "In progress:" if the session appears unfinished, or "uncommitted changes at end" if git status was last run.
- If the session looks like a complete, clean wrap-up, NOTES should say "Completed."
- Do NOT wrap in code fences. Output exactly two lines.'

# ─── Options ────────────────────────────────────────────────────────────────────
date_str=""
path_flag="project"
while getopts "d:pah" opt; do
    case "$opt" in
        d) date_str="$OPTARG" ;;
        p) path_flag="project" ;;
        a) path_flag="all" ;;
        h) grep '^#' "$0" | sed 's/^# \{0,1\}//' | sed '1d'; exit 0 ;;
        *) echo "Invalid option: $opt" >&2; exit 1 ;;
    esac
done

# ─── Date Parsing ───────────────────────────────────────────────────────────────
if [[ -n "$date_str" ]]; then
    parsed_date=$(date -d "$date_str" "+%Y-%m-%d" 2>/dev/null) || {
        echo "Invalid date: $date_str" >&2; exit 1; }
    date_str="$parsed_date"
    next_day=$(date -d "${date_str} + 1 day" "+%Y-%m-%d")
else
    date_str=$(date +%Y-%m-%d)
    next_day=$(date -d "${date_str} + 1 day" "+%Y-%m-%d")
fi

# ─── Path Selection ─────────────────────────────────────────────────────────────
case "$path_flag" in
    project)
        path="$(hx root)/.bash_history"
        name_pattern="bash_history_*"
        ;;
    all)
        path="$HOME"
        name_pattern=".bash_history_*"
        ;;
    *) echo "bad path_flag" >&2; exit 1 ;;
esac
[[ -d "$path" ]] || { echo "Path not found: $path" >&2; exit 1; }

# ─── Find Files ─────────────────────────────────────────────────────────────────
mapfile -t files < <(
    find -L "$path" -maxdepth 1 -name "$name_pattern" \
        -newermt "${date_str} 00:00:00" \
        -not -newermt "${next_day} 00:00:00" 2>/dev/null | sort -r
)
if [[ ${#files[@]} -eq 0 ]]; then
    echo "No history files for $date_str in $path." >&2
    exit 0
fi

# ─── Generate Title & Notes via Hallux ──────────────────────────────────────────
generate_title_notes() {
    local file="$1"
    local raw_output=""

    # Pipe the prompt + file context through hallux
    # lx wraps the file in a fenced markdown block with its filename
    # ask --answer returns plain text on stdout
    raw_output=$(lx "$file" | ask --answer "$PROMPT" 2>/dev/null) || {
        echo "$0: FAIL: hallux pipeline error for: $file" >&2
        return 1
    }

    # Parse the two-line response
    local title="" notes=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^TITLE:[[:space:]]*(.+)$ ]]; then
            title="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^NOTES:[[:space:]]*(.+)$ ]]; then
            notes="${BASH_REMATCH[1]}"
        fi
    done <<< "$raw_output"

    # If parsing yielded nothing, fail
    if [[ -z "$title" || -z "$notes" ]]; then
        echo "$0: FAIL: title='${title}' notes='${notes}' (file: $file)" >&2
        return 1
    fi

    printf '%s\t%s\n' "$title" "$notes"
}

# ─── Output ─────────────────────────────────────────────────────────────────────
echo "| Date/Time | Filename | Title | Notes |"
echo "|-----------|----------|-------|-------|"

for file in "${files[@]}"; do
    mod_time=$(date -r "$file" "+%Y-%m-%d %H:%M:%S")
    fname=$(basename "$file")

    # generate_title_notes prints "title\tnotes"
    result=$(generate_title_notes "$file") || {
        echo "| $mod_time | $fname | ERROR | hallux generation failed |"
        continue
    }

    IFS=$'\t' read -r title notes <<< "$result"

    echo "| $mod_time | $fname | $title | $notes |"
done

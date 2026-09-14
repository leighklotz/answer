#!/bin/bash
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"

# history-unfinished.sh — List bash history sessions for a date, flag unfinished work.
#
# Usage: history-unfinished.sh [-d DATE] [-p] [-a] [-h]
#   -d DATE   Date filter (default: today). Accepts 'Sep 13', '2026-09-13', etc.
#   -p        Project-scoped:  $(hx root)/.bash_history/bash_history_*  (default)
#   -a        All server:      $HOME/.bash_history_*
#   -h        Help
#
# Output: markdown table  | Date/Time | Filename | Title | Notes |
#   Title — compact summary of projects/scripts actually worked on.
#   Notes — if the session ends mid-task, describes what looks unfinished.
#
# Pure bash/grep/awk/sed. No LLM calls.

set -euo pipefail

source "${SCRIPT_DIR}/hx-bootstrap.sh"
hx core

# ─── options ──────────────────────────────────────────────────────────────────
date_str=""
path_flag="project"
while getopts "d:pah" opt; do
    case "$opt" in
        d) date_str="$OPTARG" ;;
        p) path_flag="project" ;;
        a) path_flag="all" ;;
        h) grep '^#' "$0" | sed 's/^# \{0,1\}//' | sed '1d'; exit 0 ;;
        *) echo "Invalid option: -$opt" >&2; exit 1 ;;
    esac
done

# ─── date ─────────────────────────────────────────────────────────────────────
if [[ -n "$date_str" ]]; then
    parsed_date=$(date -d "$date_str" "+%Y-%m-%d" 2>/dev/null) || {
        echo "Invalid date: $date_str" >&2; exit 1; }
    date_str="$parsed_date"
else
    date_str=$(date +%Y-%m-%d)
fi
next_day=$(date -d "$date_str + 1 day" "+%Y-%m-%d")

# ─── path ─────────────────────────────────────────────────────────────────────
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

# ─── find files ───────────────────────────────────────────────────────────────
mapfile -t files < <(
    find -L "$path" -maxdepth 1 -name "$name_pattern" \
        -newermt "${date_str} 00:00:00" \
        ! -newermt "${next_day} 00:00:00" 2>/dev/null | sort -r
)
if [[ ${#files[@]} -eq 0 ]]; then
    echo "No history files for $date_str in $path." >&2
    exit 0
fi

# ─── build_title: compact summary of what the session actually did ───────────
build_title() {
    local f="$1"
    awk '
    BEGIN { nd=0; ns=0; nc=0 }
    {
        line=$0
        if (line ~ /^#/ || line ~ /^$/ || line ~ /^export /) next

        # cd → project dirs
        if (line ~ /^cd[[:space:]]+/) {
            dir=line
            sub(/^cd[[:space:]]+/, "", dir)
            sub(/[[:space:]]+$/, "", dir)
            sub(/\/+$/, "", dir)
            if (dir ~ /^\//) sub(/^\//, "~", dir)
            if (dir ~ /^~/) {
                n=split(dir, P, "/")
                if (n > 2) dir=P[n-1] "/" P[n]
            }
            if (dir !~ /^\.\.?$/ && dir != "~" && dir != "wip") {
                if (!(dir in sd)) { sd[dir]=1; d[nd++]=dir }
            }
            next
        }

        # git commit -m"msg" or git commit -am "msg"
        if (line ~ /^git commit /) {
            msg=line
            sub(/^git commit[[:space:]]+/, "", msg)
            sub(/^-{1,2}[a-z]*[[:space:]]*/, "", msg)
            gsub(/^["\x27]|["\x27]$/, "", msg)
            if (length(msg) > 40) msg=substr(msg,1,37) "..."
            if (msg != "" && !(msg in sc)) { sc[msg]=1; c[nc++]=msg }
            next
        }

        # create / edit: cat >, nw, emacs, vi, vim, ed, ./script
        if (line ~ /^(cat[[:space:]]*>|nw |emacs |vi |vim |ed |\.\/[a-z])/) {
            if (match(line, /[a-zA-Z0-9_./-]+\.(sh|md|txt|py|conf|json|ya?ml)/)) {
                fn=substr(line, RSTART, RLENGTH)
                m=split(fn, FP, "/")
                b=FP[m]
                if (!(b in ss)) { ss[b]=1; s[ns++]=b }
            }
            next
        }
    }
    END {
        out=""
        for (i=0; i<nc && i<3; i++)  { if(out!="") out=out"; "; out=out c[i] }
        for (i=0; i<ns && i<4; i++)  { if(out!="") out=out"; "; out=out s[i] }
        for (i=0; i<nd && i<4; i++)  { if(out!="") out=out"; "; out=out d[i] }
        if (out=="") out="(startup only)"
        if (length(out)>120) out=substr(out,1,117) "..."
        print out
    }' "$f"
}

# ─── build_notes: describe unfinished work from session tail ─────────────────
build_notes() {
    local f="$1"
    local tail25
    tail25=$(grep -vE '^\s*(#|$)' "$f" | tail -n 25)

    # Does the tail end with uncommitted git changes?
    local uncommitted="" status_seen=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^git[[:space:]]+status ]]; then
            status_seen=1; continue
        fi
        if [[ "$status_seen" -eq 1 ]]; then
            if [[ "$line" =~ ^git[[:space:]]+(commit|push|add) ]]; then
                status_seen=0; uncommitted=""
            fi
        fi
    done <<< "$tail25"
    [[ "$status_seen" -eq 1 ]] && uncommitted="uncommitted changes at end"

    # Last 2 real actions (skip pure inspection)
    local actions
    actions=$(grep -vE '^\s*(#|$|ls[[:space:]]|cd[[:space:]]|git[[:space:]]+(status|log|branch)|pwd|history)' <<< "$tail25" | tail -n 5)
    local last_cmd
    last_cmd=$(echo "$actions" | tail -n 1 | sed 's/|.*//; s/^ *//')

    local note="" in_progress=0
    local total
    total=$(grep -cvE '^\s*(#|$)' "$f")

    # in-progress if last cmd is an edit/build/run, or long session without final commit
    if [[ "$last_cmd" =~ (cat[[:space:]]*>|nw[[:space:]]|emacs[[:space:]]|vi[m]?[[:space:]]|\.sh|scripts/|build|compile|test) ]]; then
        in_progress=1
    elif [[ "$total" -gt 30 && "$last_cmd" != *"git commit"* && "$last_cmd" != *"git push"* ]]; then
        in_progress=1
    fi

    if [[ "$in_progress" -eq 1 ]]; then
        local short
        short=$(echo "$actions" | tail -n 1 | sed 's/|.*//; s/^ *//')
        [[ ${#short} -gt 60 ]] && short="${short:0:57}..."
        note="In progress: $short"
        [[ -n "$uncommitted" ]] && note="$note; $uncommitted"
    elif [[ -n "$uncommitted" ]]; then
        note="$uncommitted"
    fi

    # escape pipes for markdown
    echo "$note" | sed 's/|/\\|/g'
}

# ─── table ────────────────────────────────────────────────────────────────────
echo "| Date/Time | Filename | Title | Notes |"
echo "|-----------|----------|-------|-------|"

for file in "${files[@]}"; do
    mod_time=$(date -r "$file" "+%Y-%m-%d %H:%M:%S")
    fname=$(basename "$file")
    title=$(build_title "$file" | sed 's/|/\\|/g')
    notes=$(build_notes "$file")
    echo "| $mod_time | $fname | $title | $notes |"
done

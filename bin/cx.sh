#!/usr/bin/env bash
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"

set -euo pipefail

# cx — stdin context concatenator.
#
# Reads a list of filenames from stdin (one per line, or NUL-delimited
# with -0) and emits each file as one block in the bx --plain format,
# without invoking bx:
#
#     $ cat src/main.py
#     def main():
#         print("hello")
#
# stderr gets one CAT_ICON status per ingested file (mirroring bx's
# per-run shell icon), then a one-line summary:
#
#     🐱 cat src/main.py
#     🔗 cx: 2 ingested, 0 skipped (4.2 KiB)
#
# Options: -n line numbers (off by default; echo becomes `$ cat -n FILE`),
# -0 NUL-delimited names, -s strict (bad entries are fatal instead of
# warn-and-skip), --base root for resolving relative paths.
# Spec: doc/commands/cx.md.

# Pin the locale so ${#var} counts bytes (summary size) and [:space:]
# handling is deterministic ASCII.
export LC_ALL=C

LINE_NUMBERS=""
NUL_MODE=""
STRICT=""
BASE=""

INGESTED=0
SKIPPED=0
TOTAL_BYTES=0

usage() {
    cat <<'EOF'
cx — stdin context concatenator: emit bx-style cat blocks for a list of filenames.

Usage:
  cx [-n|--line-numbers] [-0|--null] [-s|--strict] [--base=DIR] [--help]

The filename list arrives on stdin — one path per line, or NUL-delimited
with -0 — and each accepted entry is emitted to stdout as one block in
the bx --plain format:

  $ cat FILE
  <file contents>

Newline-mode lists may be annotated: surrounding whitespace is trimmed,
blank lines and #-comment lines are ignored, trailing CR is stripped.
An empty list produces empty output and exit status 0.

Options:
  -n, --line-numbers  number the emitted lines (echo becomes
                      `$ cat -n FILE`); off by default
  -0, --null          read NUL-delimited names verbatim (find -print0 style)
  -s, --strict        missing/unreadable/non-regular entries are fatal
                      (exit 1) instead of warn and skip
      --base=DIR      resolve relative list entries against DIR (the
                      `$ cat` echo still shows the path exactly as listed)
  -h, --help          show this help and exit
EOF
}

usage_error() {
    log_and_exit 1 "$1 (try 'cx --help')"
}

cat_file() {
    if [[ -n "$LINE_NUMBERS" ]]; then
        cat -n -- "$1"
    else
        cat -- "$1"
    fi
}

# A list entry we cannot ingest: warn and skip by default; fatal under
# --strict (log_and_exit exits 1 immediately, so no summary is printed).
skip_or_fatal() {
    local display="$1" reason="$2"
    if [[ -n "$STRICT" ]]; then
        log_and_exit 1 "${display}: ${reason}"
    fi
    log_warn "skipping ${display}: ${reason}"
    SKIPPED=$((SKIPPED+1))
}

# process_entry DISPLAY — ingest one list entry. DISPLAY is the path exactly
# as it appeared in the list: it is the `$ cat` echo text; only the file
# OPENING honors --base.
process_entry() {
    local display="$1"
    local path="$display"

    if [[ -n "$BASE" && "$path" != /* ]]; then
        path="${BASE%/}/$path"
    fi

    # Validate before opening: missing / non-regular / unreadable.
    local reason=""
    if [[ ! -e "$path" ]]; then
        reason="no such file"
    elif [[ ! -f "$path" ]]; then
        reason="not a regular file"
    elif [[ ! -r "$path" ]]; then
        reason="not readable"
    fi
    if [[ -n "$reason" ]]; then
        skip_or_fatal "$display" "$reason"
        return 0
    fi

    local cmdline="cat"
    if [[ -n "$LINE_NUMBERS" ]]; then
        cmdline="cat -n"
    fi

    # Read (optionally numbered) before printing anything, so a failed read
    # never leaves a half-emitted `$ cat` line behind on stdout. The X
    # sentinel keeps cat's trailing newlines, which command substitution
    # would otherwise strip. NUL bytes would be dropped here; acceptable
    # for text context blocks.
    local content
    if ! content="$(cat_file "$path" && printf X)"; then
        skip_or_fatal "$display" "read failed"
        return 0
    fi
    content="${content%X}"

    # bx --plain format: command echo, then the command's stdout.
    local chunk
    printf -v chunk '$ %s %s\n' "$cmdline" "$display"
    chunk+="$content"
    # Divergence from bx (one-shot, so it never cares): keep the next
    # file's `$ cat` echo from running onto a newline-less file.
    if [[ -n "$content" && "$content" != *$'\n' ]]; then
        chunk+=$'\n'
    fi
    printf '%s' "$chunk"

    INGESTED=$((INGESTED+1))
    TOTAL_BYTES=$((TOTAL_BYTES + ${#chunk}))

    # One status icon per ingested file — same role as bx's shell icon,
    # with the tooltip naming the per-file command (stub style).
    emit_icon_tooltip "${CAT_ICON}" "${cmdline} ${display}"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--line-numbers) LINE_NUMBERS=1 ;;
            -0|--null)         NUL_MODE=1 ;;
            -s|--strict)       STRICT=1 ;;
            --base=*)          BASE="${1#*=}" ;;
            -h|--help)         usage; exit 0 ;;
            --)                shift; break ;;
            -*)                usage_error "unknown flag: $1" ;;
            *)                 usage_error "positional arguments are not accepted (the file list must arrive on stdin): $1" ;;
        esac
        shift
    done
    if [[ $# -gt 0 ]]; then
        usage_error "positional arguments are not accepted (the file list must arrive on stdin): $1"
    fi
}

main() {
    local entry MSG
    parse_args "$@"

    if [[ -n "$BASE" && ! -d "$BASE" ]]; then
        log_and_exit 1 "--base: not a directory: ${BASE}"
    fi

    if [[ -n "$NUL_MODE" ]]; then
        # NUL-delimited, verbatim: no trimming, no comment/blank semantics.
        while IFS= read -r -d '' entry || [[ -n "$entry" ]]; do
            if [[ -n "$entry" ]]; then
                process_entry "$entry"
            fi
        done
    else
        # Newline-delimited list hygiene: trim, drop blanks and #-comments.
        while IFS= read -r entry || [[ -n "$entry" ]]; do
            entry="${entry#"${entry%%[![:space:]]*}"}"
            entry="${entry%"${entry##*[![:space:]]}"}"
            if [[ -n "$entry" && "$entry" != '#'* ]]; then
                process_entry "$entry"
            fi
        done
    fi

    printf -v MSG 'cx: %d ingested, %d skipped (%d.%d KiB)' \
        "$INGESTED" "$SKIPPED" \
        $((TOTAL_BYTES / 1024)) $(((TOTAL_BYTES % 1024) * 10 / 1024))
    emit_icon_tooltip "${INBOX_ICON}" "${MSG}"
    exit 0
}

main "$@"

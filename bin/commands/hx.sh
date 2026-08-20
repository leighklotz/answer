#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.sh"
source "$SCRIPT_DIR/../logging.sh"
source "$SCRIPT_DIR/../functions.sh"

cmd="$1"; shift || true

function usage() {
    echo "usage: hx model|load|unload|models|cache|provenance|again|why|what|cat|describe|stats|context" >&2
    exit 1
}

case "$cmd" in
    set-model)
        m="$("$SCRIPT_DIR/model.sh" "$@")"
        printf '%s\\n' "$m"
        ;;
    model|load|unload)   "$SCRIPT_DIR/model.sh" "$@" ;;
    models)  "$SCRIPT_DIR/models.sh" "$@" ;;
    cache)   _hx_cache "$@" ;;
    provenance) "$SCRIPT_DIR/provenance.sh" "$@" ;;
    again)   _hx_again ;;
    why|what|cat|describe|stats)
        # todo: document 'cat foo.json | hx what -'
        subcmd="$1"
        if [ "$subcmd" == "-" ]; then
            "$SCRIPT_DIR/${cmd}.sh"
        elif [ "$subcmd" != "" ]; then
            printf "hx %s '%s' unknown\n" "$cmd" "$subcmd" >& 2
            usage
        else
            c_dir="$(_find_cache_dir)"
            latest_f="$(_get_newest_cache_file "$c_dir")"
            # These hx subcommands take latest cache as stdin
            [[ -n "$latest_f" && -f "$latest_f" ]] && cat "$latest_f" | "$SCRIPT_DIR/${cmd}.sh" || echo "No cache" >&2
        fi
        ;;
    context) "$SCRIPT_DIR/${cmd}.sh" ;;
    --help)
        usage
        ;;
    *|--help)
        printf "hx '%s' unknown\n" "${cmd}" >& 2
        usage
        ;;
esac

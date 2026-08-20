# -*-bash-*-
# bootstrap hx -- runs in user shell, runs in scripts
#
HX_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../" && pwd -P)"


### user-level Functions and aliases

function _hx_cache() {
    case "$1" in
        clear)
            local cache_dir
            cache_dir=$(_find_cache_dir)
            
            if [[ -z "$cache_dir" || ! -d "$cache_dir" ]]; then 
                echo "❌ No valid cache directory found." >&2
                return 1
            fi

            # Safety check: prevent accidental deletion of root or home if _find_cache_dir fails catastrophically
            if [[ "$cache_dir" == "/" || "$cache_dir" == "$HOME" ]]; then
                echo "❌ Error: Cache directory is a protected system path." >&2
                return 1
            fi

            printf "⚠️ Are you sure you want to remove %s?\n" "$cache_dir" >&2
            read -r -p "Delete directory? (y/N): " reply < /dev/tty
            if [[ "$reply" =~ ^[Yy]$ ]]; then
                rm -- "$cache_dir"/*.json && echo "🗑️ Cache cleared." || echo "❌ Deletion failed." >&2
            else
                echo "🚫 Cancelled."
            fi
            ;;

        show)
            printf "%s\n" "$(_find_cache_dir)"
            return 0
            ;;

        enable|disable)
            if [[ "$1" == "disable" ]]; then
                export HX_NO_CACHE=1
                echo "⚠️ Cache disabled (session-wide)."
            else
                unset HX_NO_CACHE
                echo "⚠️ Cache enabled (session-wide)."
            fi
            return 0
            ;;

        *)
            echo "Unknown cache option '$1': (clear|show|enable|disable)" >&2
            return 1
            ;;
    esac
}

function hx () {
    local cmd="$1"

    [[ "${BASH_VERSINFO[0]}" -lt 4 ]] && {
        echo "ERROR: bash 4+ required." >&2
        return 1
    }

    case "$cmd" in
        ""|enable)
            hx core && hx PS1 && echo -n "👣 hallux enabled: model=" && hx model
            ;;
        core) 
            HX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
            [[ ":$PATH:" != *":$HX_ROOT/bin:"* ]] && export PATH="$HX_ROOT/bin:$PATH"

            function help() {
                "$HX_ROOT/bin/help.sh" "$@"
            }
            ;;
        PS1)
            source "$HX_ROOT/bin/commands/PS1.sh"
            ;;
        disable)
            export PATH=$(echo "$PATH" | sed -e "s|:$HX_ROOT/bin:||g" -e "s|^$HX_ROOT/bin:||")
            if [ -n "${HX_OLD_PS1}" ]; then
                export PS1="${HX_OLD_PS1}"
                unset HX_OLD_PS1
            fi
            unset -f help
            ;;
        set-model)
            shift
            HX_MODEL="$("$HX_ROOT/bin/commands/hx.sh" set-model "$@")"
            export HX_MODEL
            ;;
        cache)
            shift
            _hx_cache "$@"
            ;;
        *)
            "$HX_ROOT/bin/commands/hx.sh" "$cmd" "${@:2}"
            ;;
    esac
}

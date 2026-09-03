# -*-bash-*-
# bootstrap hx -- runs in user shell, runs in scripts
#
HX_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../" && pwd -P)"

### user-level Functions and aliases
function hx () {
    local cmd="$1"
    shift

    [[ "${BASH_VERSINFO[0]}" -lt 4 ]] && {
        echo "ERROR: bash 4+ required." >&2
        return 1
    }

    case "$cmd" in
        ""|enable) hx core &&
                   hx PS1 &&
                   echo "👣 hallux $(hx server) $(hx model) $(hx root) $(hx provenance add bash_history)"
          ;;
        core)
            HX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
            [[ ":$PATH:" != *":$HX_ROOT/bin:"* ]] && export PATH="$HX_ROOT/bin:$PATH"

            # define in user shell and inside scripts that source this file.
            function help() {
                "$HX_ROOT/bin/help.sh" "$@"
            }
            ;;
        provenance)
            "$HX_ROOT/bin/commands/${cmd}.sh" "${@}"
            ;;
        PS1) source "$HX_ROOT/bin/commands/${cmd}.sh" ;;
        disable)
            export PATH=$(echo "$PATH" | sed -e "s|:$HX_ROOT/bin:||g" -e "s|^$HX_ROOT/bin:||")
            if [ -n "${HX_OLD_PS1}" ]; then
                export PS1="${HX_OLD_PS1}"
                unset HX_OLD_PS1
            fi
            unset -f help
            ;;
        set-model)
            HX_MODEL="$("$HX_ROOT/bin/commands/hx.sh" set-model "$@")"
            export HX_MODEL
            ;;
        icons)
          if [[ -n "$1" ]]; then
            export HX_ICON_STYLE="$1"
          else
            echo "${HX_ICON_STYLE:-emoji}"
          fi
          ;;
        cache)
            local subcmd="$1"
            shift
            case "$subcmd" in
                disable)
                    export HX_NO_CACHE=1
                    echo "⚠️ Cache disabled (session-wide)."
                    ;;
                enable)
                    unset HX_NO_CACHE
                    echo "⚠️ Cache enabled (session-wide)."
                    ;;
                *) "$HX_ROOT/bin/commands/hx.sh" "$cmd" "$subcmd" "${@}" ;;
            esac
            ;;
        *) "$HX_ROOT/bin/commands/hx.sh" "$cmd" "${@}" ;;
    esac
}

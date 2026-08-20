# -*-bash-*-
# bootstrap hx -- runs in user shell, runs in scripts
#
HX_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../" && pwd -P)"

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
        *)
            "$HX_ROOT/bin/commands/hx.sh" "$cmd" "${@:2}"
            ;;
    esac
}

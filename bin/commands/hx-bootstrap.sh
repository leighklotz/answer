# -*-bash-*-
# bootstrap hx -- sourced directly by shell and sourced directly by scripts
# supports the 'hx' user-level function, which allows you to onboard and use hx commands.
HX_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../" && pwd -P)"

### user-level Functions and aliases
function hx () {
    local cmd="$1"
    shift

    local OSC8_START=$'\e]8;;'
    local OSC8_DIV=$'\e\\'
    local OSC8_CLOSE=$'\e]8;;\e\\'

    [[ "${BASH_VERSINFO[0]}" -lt 4 ]] && {
        echo "ERROR: bash 4+ required." >&2
        return 1
    }

    case "$cmd" in
        ""|enable) 
            hx core && hx PS1
            local tooltip="$("${HX_HOME}/bin/commands/home.sh" "--relative")"
            if [[ "$TERM" == "emacs" || "$TERM" == "dumb" || "$TERM" == "glass" ]]; then
                true
            else
                tooltip="${tooltip//;/}"
                tooltip="${tooltip//$'\x1b'/}"
                tooltip="${OSC8_START}$tooltip${OSC8_DIV}hallux${OSC8_CLOSE}"
            fi
            echo "👣 ${tooltip} $(hx server 2>&1) $(hx model 2>&1) $(hx root 2>&1) $(hx branch 2>&1) $(hx provenance add bash_history 2>&1)"
            ;;
        core)
            [[ ":$PATH:" != *":$HX_HOME/bin:"* ]] && export PATH="$HX_HOME/bin:$PATH"

            # define in user shell and inside scripts that source this file.
            function help() {
                "$HX_HOME/bin/help.sh" "$@"
            }
            ;;
        provenance)
            "$HX_HOME/bin/commands/${cmd}.sh" "${@}"
            ;;
        PS1) source "$HX_HOME/bin/commands/${cmd}.sh" ;;
        disable)
            export PATH=$(echo "$PATH" | sed -e "s|:$HX_HOME/bin:||g" -e "s|^$HX_HOME/bin:||")
            if [ -n "${HX_OLD_PS1}" ]; then
                export PS1="${HX_OLD_PS1}"
                unset HX_OLD_PS1
            fi
            unset -f help
            ;;
        set-model)
            HX_MODEL="$("$HX_HOME/bin/commands/hx.sh" set-model "$@")"
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
                    [ -z "${HX_QUIET}" ] && echo "⚠️ Cache disabled (session-wide)."
                    true
                    ;;
                enable)
                    unset HX_NO_CACHE
                    [ -z "${HX_QUIET}" ] && echo "⚠️ Cache enabled (session-wide)."
                    true
                    ;;
                *) "$HX_HOME/bin/commands/hx.sh" "$cmd" "$subcmd" "${@}" ;;
            esac
            ;;
        *) "$HX_HOME/bin/commands/hx.sh" "$cmd" "${@}" ;;
    esac
}

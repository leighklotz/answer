# bootstrap hx
# enable function only; once enabled, answer will override
function hx () {
    local arg="$1"

    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        echo "ERROR: bash 4+ required." >&2
        return 1
    fi

    case "$arg" in
        "")           # hx no arg, chatty
            hx enable && echo -n "🦶hallux enabled: model=" && hx model
            ;;
        "enable")     # hx enable, quiet
            source ~/wip/answer/bin/commands/enable
            ;;
        *)            # This handles any other input
            echo "usage: hx [enable]"
            return 1
            ;;
    esac
}

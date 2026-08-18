HX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[[ ":$PATH:" != *":$HX_ROOT/bin:"* ]] && export PATH="$HX_ROOT/bin:$PATH"

function help() {
  "$HX_ROOT/bin/help.sh" "$@"
}

function hx() {
  local cmd="${1:-}"
  case "$cmd" in
    "")
        hx enable
        hx PS1
        echo -n "👣 hallux enabled: model="; "$HX_ROOT/bin/commands/model.sh"
        ;;
    enable)
        HX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
        [[ ":$PATH:" != *":$HX_ROOT/bin:"* ]] && export PATH="$HX_ROOT/bin:$PATH"
        ;;
    PS1) source "$HX_ROOT/bin/commands/PS1.sh" ;;
    disable)
        export PATH=$(echo "$PATH" | sed -e "s|:$HX_ROOT/bin:||g" -e "s|^$HX_ROOT/bin:||")
        if [ -n "${HX_OLD_PS1}" ]; then
            export PS1="${HX_OLD_PS1}"
            unset HX_OLD_PS1
        fi
        source "$HX_ROOT/bin/commands/hx-bootstrap.sh"
        unset -f help
        ;;
    set-model)
      shift
      HX_MODEL="$("$HX_ROOT/bin/commands/hx.sh" set-model "$@")"
      export HX_MODEL
      ;;
    model|models|cache|provenance|again|why|what|cat|describe|stats)
      "$HX_ROOT/bin/commands/hx.sh" "$cmd" "${@:2}"
      ;;
    *)
      "$HX_ROOT/bin/commands/hx.sh" "$cmd" "${@:2}"
      ;;
  esac
}

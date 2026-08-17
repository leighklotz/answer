#!/usr/bin/env bash
[[ -n "$HX_ROOT" ]] && HX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

function help() {
  "$HX_ROOT/bin/help.sh" "$@"
}

function hx() {
  local cmd="${1:-}"
  case "$cmd" in
    "")
      echo -n "👣 hallux enabled: model="
      "$HX_ROOT/bin/commands/model.sh"
      ;;
    enable|disable)
      source "$HX_ROOT/bin/commands/enable-core.sh"
      if [[ "$cmd" == "enable" ]]; then
        if [[ -n "${PS1-}" && "${PS1-}" != *"👣"* ]]; then
          export ANSWER_OLD_PS1="$PS1"
          PS1="${PS1/\\$/👣\$}"
        fi
      else
        export PATH=$(echo "$PATH" | sed -e "s|:$HX_ROOT/bin:||g" -e "s|^$HX_ROOT/bin:||")
        [[ -n "${ANSWER_OLD_PS1-}" ]] && { export PS1="$ANSWER_OLD_PS1"; unset ANSWER_OLD_PS1; }
      fi
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

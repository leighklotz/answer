source "$(dirname "${BASH_SOURCE[0]}")/enable-core.sh"

if [[ -n "${PS1-}" && "${PS1-}" != *"👣"* ]]; then
  export HX_OLD_PS1="$PS1"
  PS1="${PS1/\\$/👣\$}"
fi

source "$(dirname "${BASH_SOURCE[0]}")/aliases.sh"

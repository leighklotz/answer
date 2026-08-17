if [[ -n "${PS1-}" && "${PS1-}" != *"👣"* ]]; then
  export HX_OLD_PS1="$PS1"
  PS1="${PS1/\\$/👣\$}"
fi

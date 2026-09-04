[[ $- != *i* ]] && return

export HISTFILE="$HOME/.bash_history_$$"
shopt -s histappend
export HISTSIZE=10000
export HISTFILESIZE=10000

# start with a blank history file
: >> "$HISTFILE"

if ! history 2>/dev/null | grep -Fq "# ${SHELL##*/} started:"; then
  # populate your favorite starter commands here
  history -s 'sudo apt update && sudo apt upgrade'
  history -s 'cd ~/wip/toolex'
  history -s 'cd ~/wip/answer'
  history -s 'cd ~/wip/summarizer'
  history -s 'cd ~/wip/llama-server'
  history -s 'cd ~/wip/llama-server && ./scripts/do-hallux-pulls.sh'
  case $(hostname) in
    server)
      history -s 'cd ~/wip/llama-server && ./scripts/do-llama-pull.sh'
      history -s 'cd ~/wip/llama-server && ./scripts/do-llama-build.sh'
      history -s 'cd ~/wip/llama-server && ./scripts/start-hallux.sh'
      ;;
  esac

  # This comment in history comes at the end of the pre-stuffed commands
  history -s "# ${SHELL##*/} started: $$ $(date -Iseconds | sed -e 's/T/ /')"

  # Leave history -w commented out so you have blank files if the you did nothing.
  # uncomment if you want it on disk now
  # history -w

  # Comment out if you want it written only on normal shell termination
  PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
fi

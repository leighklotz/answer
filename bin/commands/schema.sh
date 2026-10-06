#!/usr/bin/env -S bash

# --- SETUP & SOURCE (Standard Hallux Pattern) ---
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../logging.sh"
source "${SCRIPT_DIR}/../functions.sh"

# Constants for Jev Types
TYPE_CHOICE="choice"
TYPE_SCORE="score"
TYPE_NOUL="noul"

usage() {
  echo "Usage: hx schema build <intent>" >&2
  echo ""
  echo "Interactive DSL Commands:"
  echo "  select <name> [type] [--instructions 'text'] [--legend 'l1|l2']"
  echo "    (Types: choice, score, noul)"
  echo "  option <vals>"
  echo "    - For Choice: key:desc,key2:desc2 (or just val1,val2)"
  echo "    - For Score: level1|level2|level3"
  echo "  finish [filename]"
  exit 0
}

_ensure_workspace || exit 1

# --- STATE MANAGEMENT ---
SCHEMA_TMP="$HALLUX_TMP_DIR/current_schema.json"

# Initialize a fresh schema object if none exists in the session
if [[ ! -f "$SCHEMA_TMP" ]]; then
  echo '{"questions": {}}' > "$SCHEMA_TMP"
fi

# --- CORE ENGINE ---
build_mode() {
    local intent="$1"
    log_info "Starting Schema Builder: $intent"
    printf "\n${BLUE}Building schema for:${WOLFE} %s\n" "$intent"
    echo -e "${GRAY}Commands: select <name> [type] | option <vals> | finish\n${RESET}"

    local current_key=""
    local active_stanza=false

    while true; do
        printf "%s " "$USER_INPUT_ICON" >&2
        read -r cmd args || break

        case "$cmd" in
            select)
                # Syntax: select name [type] [--instructions 'text'] [--legend 'l1|l2']
                current_key=$(echo "$args" | awk '{print $1}')
                local type="choice" # Default
                [[ "$args" =~ (noul|score|choice) ]] && [[ ! "$args" =~ ^[a-z]+$ ]] && type=$(echo "$args" | grep -oE '(choice|score|noul)' | head -1)

                # Extract instructions if present via regex
                local instr=""
                if [[ "$args" =~ --instructions=\"?([^\"]+)\"? ]]; then
                    instr="${BASH_REMATCH[1]}"
                fi

                # Create the key in jq
                jq --arg k "$current_key" \
                   --arg t "$type" \
                   --arg i "$instr" \
                   '.questions[$k] = {"type": $t, "instructions": ($i // "")}' "$SCHEMA_TMP" > "${SCHEMA_TMP}.tmp" && mv "${SCHEMA_TMP}.tmp" "$SCHEMA_TMP"

                active_stanza=true
                printf "  ${GREEN}✓${WOLFE} Field '%s' (type: %s) initialized.\n" "$current_key" "$type"
                ;;

            option)
                if [[ -z "$current_key" || "$active_stanza" == false ]]; then
                    log_error "Must call 'select' before 'option'"
                    continue
                fi

                # Parse the args (can be comma-separated or pipe-separated depending on type)
                local raw_options="$args"
                
                if [[ "$raw_options" == *"|"* ]]; then # Score logic: levels separated by |
                    jq --arg k "$current_key" \
                       --argjson opts "$(echo "$raw_options" | awk -F'|' '{for(i=1;i<=NF;i++) printf "\"%s\",", $i}' | sed 's/,$//') | []" \
                       '.questions[$k].criteria = ($opts | map({level: .}))' "$SCHEMA_TMP" > "${SCHEMA_TMP}.tmp" && mv "${SCHEMA_TMP}.tmp" "$SCHEMA_TMP"
                else # Choice logic: key:val,key2:val2 or val1,val2
                    # Convert comma list to JSON object (for choice) 
                    local json_opts=$(echo "$raw_options" | jq -R 'split(",") | map(if contains(":") then split(":") else . end | if length == 2 then {(.[0]): .[1]} else . end) | add' --argjson x '{}')

                    jq --arg k "$current_key" \
                       --argjson opt "$json_opts" \
                       '.questions[$k].criteria = $opt' "$SCHEMA_TMP" > "${SCHEMA_TMP}.tmp" && mv "${SCHEMA_TMP}.tmp" "$SCHEMA_TSM" || {
                           # Fallback if the key:value parsing is too complex for one-pass jq, use simple array approach
                           jq --arg k "$current_key" \
                              --argjson opt "$(echo "$raw_options" | awk -F',' '{for(i=1;i<=NF;i++) printf "\"%s\",", $i}' | sed 's/,$//' | jq '[.]')" \
                              '.questions[$k].criteria = $opt' "$SCHEMA_TMP" > "${SCHEMA_TMP}.tmp" && mv "${SCHEMA_TMP}.tmp" "$SCHEMA_TMP"
                       }
                    jq --arg k "$current_key" '.questions[$k] += {"probabilities": {}} | .questions[$k] |= with_entries(if .name == "criteria" then del(.name) else . end)' "$SCHEMA_TMP" > "${SCHEMA_TMP}.tmp" && mv "${SCHEMA_TMP}.tmp" "$SCHEMA_TMP"
                fi

                printf "  ${GREEN}✓${WOLFE} Options added to '%s'.\n" "$current_key"
                ;;

            finish)
                local target="${1:-schema.json}"
                cp "$SCHEMA_TMP" "$target"
                echo -e "${BLUE}Schema saved to $target${RESET}\n"
                rm "$SCHEMA_TMP"
                exit 0
                ;;

            *)
                log_error "Unknown command: '$cmd'. Available: select, option, finish."
                ;;
        esac
    done
}

# --- MAIN ENTRY POINT ---
if [[ $# -lt 2 ]]; then
    usage
fi

case "$1" in
    build) shift; build_mode "$*" ;;
    *) usage ;;
esac

#!/bin/bash -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source ${SCRIPT_DIR}/commands/enable

model="$(hx model)"
URL="${VIA_API_CHAT_BASE%/}/tokenize"

# 1. Use jq -R to read lines, -s (slurp) to join them into an array
# 2. Join the array elements back into a single string with newlines
jq -Rs --arg model "$model" '{model: $model, content: .}' |
  curl -s -X POST -H "Content-Type: application/json" --data @- "$URL" |
  jq 'if type == "array" then length 
      elif .tokens != null and (.tokens | type == "array") then .tokens | length 
      else error("API did not return a token array. Response was: \(.)") end'

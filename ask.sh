#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/functions.sh"

# usage: ask your question | answer
# usage: ask your question
# usage: ask -i your question about foo.sh < (bx cat foo.sh) 
# usage: bx cat foo.sh | ask -i your question about foo.sh 
# usage: bx cat foo.sh | ask -i your question about foo.sh | answer
# usage: ask -i your question about foo.sh < (bx cat foo.sh) 
# usage: ask -i your question about foo.sh < (bx cat foo.sh) | answer
# usage: bx cat foo.sh | ask -i your question about foo.sh | ask -i further comments 
# usage: bx cat foo.sh | ask -i your question about foo.sh | ask -i further comments | answer
# usage: bx cat foo.sh | ask -i your question about foo.sh | answer | ask -i further comments 
# usage: bx cat foo.sh | ask -i your question about foo.sh | answer | ask -i further comments | answer
# usage: ask.sh write 'fib in python. output a single impl in a code fence with a call to fib(20)'  
# usage: ask.sh write 'fib in python. output a single impl in a code fence with a call to fib(20)'  | answer 
# usage: ask.sh write 'fib in python. output a single impl in a code fence with a call to fib(20)'  | answer | unfence 
# usage: ask.sh write 'fib in python. output a single impl in a code fence with a call to fib(20)'  | answer | unfence | python

PLAIN_INPUT=""
if [ "$1" = "-i" ] || [ "$1" = "--input" ]; then
    shift
    PLAIN_INPUT="1"
fi

# 1. Prepare the conversation/input
if [ -t 0 ]; then
    # No stdin, user provided argument
    prompt="$*"
    input=$(jq -n --arg prompt "$prompt" '[{"role":"user","content":$prompt}]')
else
    # Reading from pipe
    read -r -d '' stdin_content || true
    prompt="$*"
    if [ -n "${PLAIN_INPUT}" ]; then
        # Merge prompt and piped text into one user message
        input=$(jq -n --arg p "$prompt" --arg s "$stdin_content" '[{"role":"user","content":($p + "\n\n" + $s)}]')
    else
        # Validate JSON
        first_char="$(printf "%s" "$stdin_content" | tr -d '[:space:]' | cut -c1)"
        if [ "$first_char" != "[" ]; then
            echo "ask: stdin does not look like a JSON conversation array (first non-whitespace char: '${first_char}')." >&2
            echo "ask: if you are piping plain text, use the -i / --input flag." >&2
            exit 1
        fi
        # Append new user message to existing JSON array
        new_msg=$(jq -n --arg p "$prompt" '{"role":"user","content":$p}')
        input=$(jq --argjson nm "$new_msg" '. + [$nm]' <<< "$stdin_content")
    fi
fi

# 2. Perform inference
if [ -t 1 ]; then
    # If terminal, perform inference and extract text via answer
    printf "%s" "$input" | answer
else
    # If piped, just output the JSON conversation array without calling the API
    printf "%s" "$input"
fi



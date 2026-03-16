# Answer — Implementation Notes

## Repository Layout

```
answer/
├── aliases       # Bash source: defines the `ask` shell function
├── answer        # Script: extracts last message content from conversation JSON
├── ask.sh        # Script: sends prompts to LLM API, manages conversation history
├── bashfence     # Script: runs a command and wraps output in a bash code fence
├── story.txt     # Usage examples and walkthroughs
├── unfence       # Script: strips Markdown code fences from input
├── LICENSE       # MIT License
└── README.md     # Project overview and usage guide
```

---

## `ask.sh`

**Language:** Bash  
**Dependencies:** `bash`, `curl`, `jq`

### Startup

The script sources `~/wip/llamafiles/scripts/env.sh` at start-up to load local environment configuration (API keys, endpoint overrides, etc.).

### Argument parsing

A minimal hand-written argument parser handles two flags before the prompt text:

```bash
if [ "$1" = "-i" ] || [ "$1" = "--input" ]; then
    shift; PLAIN_INPUT="1"
elif [ "$1" = "--help" ]; then
    usage; exit 0
fi
```

Everything remaining in `$@` after the flag is treated as the prompt.

### Stdin detection

```bash
if [ -t 0 ]; then          # no pipe attached
    # interactive: build a fresh conversation from $*
else
    read -r -d '' input    # slurp all of stdin
    if [ -n "${PLAIN_INPUT}" ]; then
        # combine raw stdin text with prompt → new conversation
    else
        # stdin is existing JSON history → append new user message
    fi
fi
```

`[ -t 0 ]` tests whether file descriptor 0 is a terminal. When a pipe is present, it is false and stdin is slurped with `read -r -d ''`.

### JSON construction

`jq -n` (null-input mode) constructs new message objects. `jq . + [...]` appends to an existing array without re-parsing the whole structure.

```bash
# Append user message to existing history
new_message=$(jq -n --arg prompt "$prompt" '{"role":"user","content":$prompt}')
messages=$(jq --argjson new_message "$new_message" '. + [$new_message]' <<< "$input")
```

### API call

`curl` posts to `$VIA_API_CHAT_BASE/v1/chat/completions`. The full request body is built with a single `jq -n` call that inlines all sampler parameters as literals:

```bash
response="$(curl -s -X POST "${VIA_API_CHAT_COMPLETIONS_ENDPOINT}" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --argjson messages "$messages" ...)")"
```

### Reply extraction and output

The assistant reply is extracted from `choices[0].message.content`. An empty reply causes the script to exit with status 1 and a message on stderr.

On success, the reply is appended to the message array and the full array is written to stdout:

```bash
new_assistant_message=$(jq -n --arg content "$assistant_reply" '{"role":"assistant","content":$content}')
messages=$(jq --argjson reply "$new_assistant_message" '. + [$reply]' <<< "$messages")
echo "$messages"
```

---

## `answer`

**Language:** Bash  
**Dependencies:** `jq`

```bash
if [ -t 0 ] && [ -n "${ANSWER}" ]; then
  printf "%s" "${ANSWER}" | jq -r '.[-1].content'
else
  jq -r '.[-1].content'
fi
```

`jq -r` (raw output) strips the surrounding JSON string quotes. `.[-1].content` selects the last message's content field.

---

## `unfence`

**Language:** Bash + AWK  
**Dependencies:** `awk`

The script buffers all stdin into a single AWK variable, then uses `match(line, /``\`/)` in a loop to find fence boundaries. The `in_block` flag tracks whether the scanner is between an opening and closing fence.

Key edge cases handled:
- Input with no code fences: entire buffered input is printed unchanged.
- Input still inside an open fence at EOF: remaining content is printed.
- Multiple code blocks: each is extracted in turn.

---

## `bashfence`

**Language:** Bash  
**Dependencies:** none beyond `bash`

```bash
printf '```bash\n$ %s\n' "${*}"
${*}
s=$?
printf '```\n'
exit $s
```

The wrapped command's exit status is captured in `$s` and used by the final `exit $s`, so the exit code of the wrapped command is correctly propagated to the caller.

---

## `aliases`

**Language:** Bash

```bash
ask () 
{ 
    export ANSWER=$(ask.sh "$*");
    printf "%s\n" "${ANSWER}"
}
```

`"$*"` joins all arguments with the first character of `$IFS` (space). This means multi-word prompts are passed as a single string to `ask.sh`.

The result is exported as `$ANSWER` so that a subsequent `answer` invocation in the same shell can read the conversation without a pipe.

---

## Data Flow

```
┌──────────┐   JSON history   ┌──────────┐   JSON history   ┌──────────┐
│  ask.sh  │ ───────────────► │  ask.sh  │ ───────────────► │  ask.sh  │
│ (turn 1) │                  │ (turn 2) │                  │ (turn 3) │
└──────────┘                  └──────────┘                  └──────────┘
                                                                   │
                                                           JSON history
                                                                   │
                                                                   ▼
                                                            ┌──────────┐
                                                            │  answer  │  ──► plain text
                                                            └──────────┘
```

Each `ask.sh` invocation is stateless beyond what it receives on stdin. The entire conversation context is serialised into the pipe stream, so no files or environment variables are required for multi-turn pipelines.

---

## Known Limitations

1. **Hard-coded model name** — `gpt-3.5-turbo` is embedded in the API request body. There is no flag to choose a different model at runtime.
2. **Hard-coded sampler parameters** — Temperature, `top_k`, `top_p`, and other sampler settings are all literals with no override mechanism.
3. **No file attachment** — There is no built-in way to include the content of a named file as part of the conversation context; users must rely on `bashfence cat <file>` piped into `ask -i`.
4. **No tool / function calling** — The API request does not include a `tools` field, so the model cannot invoke external functions.
5. **`$ANSWER` is single-valued** — The `aliases` function stores only the most recent API response. Chaining interactive `ask` calls overwrites `$ANSWER` each time, so only the last response is available to `answer` without a pipe.
6. **Pipeline idempotency** — Re-running a pipeline that begins with `ask` always starts a fresh conversation; there is no mechanism to resume a prior conversation or to make repeated invocations idempotent.
7. **`env.sh` coupling** — `ask.sh` unconditionally sources `~/wip/llamafiles/scripts/env.sh`, which may not exist on all machines. Missing this file causes `ask.sh` to fail even when all required environment variables are already set.

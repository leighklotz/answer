# Answer — Implementation Notes

## Repository Layout

```
answer/
├── answer.sh     # Script: extracts last message content from conversation JSON; supports --tee
├── ask.sh        # Script: sends prompts to LLM API, manages conversation history
├── bx.sh         # Script: runs a command and wraps output in a bash code fence
├── enable.sh     # Script: (New) environment setup/enabler
├── functions.sh  # Bash source: defines the ask/answer/tools shell functions
├── help-commit.sh # Script: (New) helper for commit messages
├── logging.sh    # Script: (New) logging utilities
├── tools.sh      # Script: pipeline wrapper around toolex.py for tool-call resolution
├── unfence.sh    # Script: strips Markdown code fences from input
├── story.txt     # Usage examples and walkthroughs
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

Uses a robust `while/case` loop to handle flags (`-i`, `--use-system-message`, `--help`) regardless of their position relative to the prompt. Once a non-option argument is encountered, the loop breaks, and all remaining arguments are treated as the prompt.

### Stdin detection & Input Handling

The script distinguishes between interactive use and pipeline use via `[ -t 0]`:
- **Interactive Mode:** If stdin is a terminal, it builds a new conversation JSON from the prompt arguments.
- **Pipeline Mode:** 
    - If the `PIPELINE_MAGIC_HEADER` is detected, it treats stdin as a full JSON conversation history.
    - If `-i` is provided, it treats stdin as raw text and prepends it to the prompt.
    - If no header is present and `-i` is not used, it validates if the input starts with `[` to treat it as JSON history; otherwise, it errors out.

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

### System Message Injection

If `--use-system-message` is toggled and `$SYSTEM_MESSAGE` is set, `jq` is used to prepend a new object with `role: "system"` to the beginning of the messages array.

### Output

- **Terminal:** If stdout is a terminal, it pipes the JSON to `answer` to provide a pretty-printed response and updates the global `LAST_ANSWER`.
- **Pipeline:** Outputs the `PIPELINE_MAGIC_HEADER` followed by the updated JSON array to stdout.

---

## `answer.sh`

**Language:** Bash  
**Dependencies:** `jq`

#### Argument parsing & Input
Uses a `while/case` loop for flag detection (`--tee` / `-t`). It detects if it is receiving a conversation history by checking for the `PIPELINE_MAGIC_HEADER` in stdin.

#### Output Modes
1. **Observation Mode (`--tee`):** Prints the last message's text to `stderr` and passes the full JSON history through `stdout`.
2. **Tool/Extraction Mode (Pipe):** When stdout is not a terminal, it extracts only the text of the last message and sends it to `stdout`.
3. **Terminal Mode:** When called directly in a terminal, it extracts and prints the last message's text.

---

## `tools.sh`

**Language:** Bash  
**Dependencies:** `toolex.py` (external), `bash`

```bash
# Build --tools flags
TOOLS_ARGS=()
for module in "$@"; do
    TOOLS_ARGS+=("--tools" "$module")
done

exec toolex.py --pipe "${TOOLS_ARGS[@]}"
```

Acts as a thin pipeline wrapper around `toolex.py`. Reads a JSON conversation array from stdin, forwards it to `toolex.py --pipe` along with `--tools <module>` flags, and writes the updated JSON conversation array to stdout.

Guards:
- Exits with a helpful message if no module names are given.
- Exits with a helpful message if stdin is a terminal (not a pipe).
- Exits with a helpful message if `toolex.py` is not found on `$PATH`.

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

## `bx`

The script executes the command and wraps the output in a Bash code fence. Crucially, it captures the exit status of the wrapped command using `$s` and ensures this status is returned by the script, preserving error propagation in pipelines.

---

## `functions.sh`

#### `ask()`
A smart wrapper that provides pipeline intelligence:
- **Header Detection:** It reads the first line of stdin. If it matches `PIPELINE_MAGIC_HEADER`, it calls `ask.sh` with the existing JSON. If the header is absent but stdin is a pipe, it automatically invokes `ask.sh -i` to treat the input as an attachment.
- **Error Propagation:** Captures the exit status of `ask.sh` and returns it to the shell.
- **Terminal Logic:** If stdout is a terminal, it uses a here-string (`<<<`) to pass the result to `answer`, ensuring the `LAST_ANSWER` variable is updated in the current shell context.

#### `answer()`
- **Direct Call:** If called without stdin in a terminal, it retrieves the content from the global `LAST_ANSWER` variable.
- **State Management:** If not in `--tee` mode, it exports the result to the `LAST_ANSWER` environment variable to allow subsequent interactive calls to retrieve the result.

#### `pipetest()`
A safety wrapper that captures stdin to a temporary file, displays a preview of the data to `stderr`, and requires a `Y/N` confirmation from the user via `/dev/tty` before forwarding the data to `stdout`.

---

## Data Flow

### Basic pipeline

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
                                                            │  answer  │  ──► plain text (stdout)
                                                            └──────────┘
```

### Mid-pipeline with `--tee`

```
┌──────────┐   JSON   ┌──────────┐   JSON   ┌────────────────┐   JSON   ┌──────────┐
│  ask.sh  │ ────────►│ tools.sh │ ────────►│ answer --tee   │ ────────►│  ask.sh  │ ──► ...
└──────────┘          └──────────┘          └────────────────┘          └──────────┘
                                                    │
                                              plain text
                                               (stderr)
                                                    │
                                                    ▼
                                              human terminal
```

Each `ask.sh` invocation is stateless beyond what it receives on stdin. The entire conversation context is serialised into the pipe stream, so no files or environment variables are required for multi-turn pipelines.

---

## Known Limitations

- **Tool Calling:** While the `tools` wrapper is implemented, `ask.sh` does not yet automatically handle the `finish_reason == "tool_calls"` loop (single-step auto-execution).
- **Model Selection:** The model name is currently hard-coded as `gpt-3.5-turbo` within `ask.sh`.
- **Caching:** There is currently no mechanism for conversation caching or resuming from a saved JSON file.

# Answer — Plan

This document captures planned improvements to the **Answer** framework. Items are ordered roughly by priority and interdependency, but each can be addressed independently.

---

## 1. Ensure a sequence of `ask` calls can be piped to `answer`

### Current state

The pipeline pattern `ask "p1" | ask "p2" | ask "p3" | answer` already works in principle: each `ask.sh` reads the JSON history on stdin, appends a user turn and the assistant reply, and writes the updated history to stdout. `answer` at the end extracts `.[-1].content`.

However, several edge cases break this flow:

- **Interactive vs. pipe detection** — When any stage in the chain has its stdin redirected from something that is not a recognised JSON array (e.g. plain text without `-i`), `jq` silently produces `null` and the conversation resets.
- **Error propagation** — If any intermediate `ask.sh` receives an empty reply from the API it exits with status 1, but the pipeline may still forward partial output to the next stage rather than aborting cleanly.
- **`aliases` function** — The shell function defined in `aliases` passes `"$*"` (a single string) and captures to `$ANSWER`, which works for interactive use but loses per-stage conversation state in a subshell pipeline.

### Plan

- [ ] Add input validation in `ask.sh`: if stdin is not a terminal and the first non-whitespace character of stdin is not `[`, print an error and exit rather than silently producing a broken conversation.
- [ ] Propagate non-zero exit codes through the pipeline (use `set -o pipefail` where appropriate, or check `${PIPESTATUS[@]}` in the wrapper function).
- [ ] Add an integration test / smoke-test script (`test/pipeline_test.sh`) that mocks the API and verifies that a three-stage `ask | ask | ask | answer` pipeline produces the correct final content.
- [ ] Document the expected input format prominently in the `--help` output of `ask.sh`.

---

## 2. Add a `--file` flag to `ask` to attach a file to the conversation

### Motivation

Currently, including a file's content in a conversation requires a workaround:

```bash
bashfence cat myfile.py | ask -i "what does this do?"
```

This encodes the file in a Bash code fence, which is useful but requires an extra pipeline stage and forces the content into a single user message. A dedicated flag would allow files to be attached cleanly at any point in a conversation, support multiple attachments, and lay the groundwork for multimodal (image) attachments in the future.

### Plan

- [ ] Add `-f <path>` / `--file <path>` flag to `ask.sh`. When supplied:
  - Read the file content.
  - Prepend it to the user message content, separated from the prompt by a blank line and a clear delimiter (e.g. `--- file: <path> ---`).
  - Allow the flag to be repeated to attach multiple files.
- [ ] Decide whether file content should be inlined in the `content` field (simple, universally compatible) or placed in a separate `content` array element of type `"type": "text"` (more aligned with the OpenAI structured content format).
- [ ] Validate that the named file exists and is readable before constructing the API request; print a helpful error otherwise.
- [ ] Update `usage()` and `--help` output in `ask.sh`.
- [ ] Update `SPEC.md` and `IMPL.md` once the feature is implemented.

### Example (target UX)

```bash
ask --file mymodule.py "What does this module do?" | answer

ask --file error.log --file config.yaml "Why is the service failing?" | answer
```

---

## 3. Pipeline idempotency — repeating a previous pipeline with a new ask

### Motivation

A common interactive pattern is:

```bash
ask "write fib in python" | ask "call it with 20" | answer
```

If the user wants to extend this conversation, they may try to re-run the first two stages and append a new ask:

```bash
ask "write fib in python" | ask "call it with 20" | ask "now add memoisation" | answer
```

Because `ask.sh` always issues a live API call, re-running the first two stages makes two additional API calls that duplicate work already done. The model may also produce different code on the second call, making the context of the new ask inconsistent with the previous interaction.

### Plan

- [ ] **Conversation caching** — Allow `ask.sh` to optionally write the conversation JSON to a named cache file (`--save <file>`) and to resume from it (`--resume <file>`). This avoids re-issuing earlier turns when extending a conversation.
- [ ] **`lastanswer` helper** — Introduce a `lastanswer` command (or `ask --resume`) that reads the most recently saved conversation and feeds it into the next `ask`, making it straightforward to append a single new turn without replaying earlier ones.
- [ ] **Deterministic sampling** — Document and optionally enforce a fixed `seed` value so that replaying a pipeline with the same prompts produces identical model outputs, making idempotency easier to reason about.
- [ ] **Content addressing** — Consider keying the cache on a hash of the full prompt chain so that identical prompt sequences always map to the same cached result, while any change in any prompt correctly invalidates the cache.

### Example (target UX)

```bash
# First run: save conversation state
ask "write fib in python" | ask "call it with 20" --save ~/convs/fib.json | answer

# Later: extend without replaying earlier turns
ask --resume ~/convs/fib.json "now add memoisation" | answer
```

---

## 4. Modern LLM techniques

### 4a. Tool / function calling

OpenAI-compatible APIs support a `tools` field in the request body that lets the model request execution of named functions. This enables agents that can invoke shell commands, query databases, search the web, etc., and incorporate results back into the conversation automatically.

**Plan:**
- [ ] Add a `--tool <json-spec-file>` flag to `ask.sh` that reads one or more tool definitions from JSON files and includes them in the request body under the `tools` array.
- [ ] After receiving a response, detect `finish_reason == "tool_calls"` and dispatch each requested tool call to a named script (`tools/<name>.sh`) or a user-defined handler.
- [ ] Append the tool result as a `role: "tool"` message and re-submit to the API automatically (single-step tool use), or write it to stdout and let the pipeline handle it (composable multi-step tool use).
- [ ] Provide example tool definitions for common operations: `bash_exec`, `read_file`, `write_file`, `web_search`.

### 4b. Structured output / JSON mode

Many models support a `response_format: {"type": "json_object"}` parameter that constrains the reply to valid JSON. This is useful when downstream stages need to parse the model's answer programmatically.

**Plan:**
- [ ] Add a `--json` flag to `ask.sh` that sets `response_format` in the request body.
- [ ] Add a `--schema <file>` variant for models that support JSON Schema-constrained output.

### 4c. System prompt support

Currently there is no way to inject a `role: "system"` message into the conversation.

**Plan:**
- [ ] Add a `--system <text>` / `-s <text>` flag that prepends a system message to every new conversation.
- [ ] Allow reading the system prompt from a file: `--system-file <path>`.

### 4d. Streaming output

The current implementation waits for the full API response before printing anything. For long responses this produces an unpleasant delay.

**Plan:**
- [ ] Add a `--stream` flag that sets `stream: true` in the request and uses `curl --no-buffer` with a Server-Sent Events parser (implementable in `awk` or Python) to print tokens as they arrive.
- [ ] Stream to stderr so that the JSON history can still be collected cleanly on stdout.

### 4e. Model selection

The model name is currently hard-coded as `gpt-3.5-turbo`.

**Plan:**
- [ ] Add a `--model <name>` / `-m <name>` flag to `ask.sh`.
- [ ] Fall back to a `VIA_API_MODEL` environment variable, then to the hard-coded default.

### 4f. Multimodal (image) input

Some models accept `content` arrays that include image URLs or base64-encoded images alongside text.

**Plan:**
- [ ] Extend `--file` (see §2) to detect image MIME types and encode them as `{"type": "image_url", "image_url": {"url": "data:image/...;base64,..."}}` content parts rather than inline text.

---

## 5. Housekeeping

- [ ] Make the `env.sh` sourcing in `ask.sh` conditional (only source if the file exists) to remove the hard dependency on `~/wip/llamafiles/scripts/env.sh`.
- [x] Fix the `bashfence` exit-code bug: the script now exits with `$s` (the captured status of the wrapped command) rather than `$?` (the status of the final `printf`).
- [ ] Add a `Makefile` with `install`, `test`, and `lint` targets.
- [ ] Add shell-script linting via `shellcheck` to CI.

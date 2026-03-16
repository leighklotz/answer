# Answer — Specification

## Overview

**Answer** is a POSIX-shell agent framework for conversational code generation and execution. It connects a language model API to the Unix pipeline model, allowing multi-turn conversations to be constructed and consumed entirely with standard shell idioms.

---

## Components

### `ask` / `ask.sh`

The core component. Sends a user prompt to a language-model API and returns the full conversation history as a JSON array.

#### Synopsis

```
ask [OPTIONS] [PROMPT...]
```

When invoked as the shell function `ask` (sourced from `aliases`), the result is also stored in the `$ANSWER` environment variable so that `answer` can read it without a pipe when running interactively.

When invoked directly as `ask.sh`, only stdout is used.

#### Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `-i` | `--input` | Treat stdin as raw text to prepend to PROMPT, rather than as an existing JSON conversation history. Useful when piping arbitrary command output into an initial `ask`. |
| | `--help` | Print usage and exit. |

#### Input

`ask` / `ask.sh` reads from stdin in two modes:

| Condition | Behaviour |
|-----------|-----------|
| stdin is a terminal (interactive) | No stdin is read; PROMPT arguments form the first user message. |
| stdin is a pipe and `-i` / `--input` is set | Stdin is read as plain text and prepended to PROMPT, creating a fresh conversation. |
| stdin is a pipe and `-i` / `--input` is **not** set | Stdin is read as a JSON conversation array; PROMPT is appended as a new user message. |

#### Output

A JSON array of message objects representing the complete conversation, including the new assistant reply:

```json
[
  {"role": "user",      "content": "..."},
  {"role": "assistant", "content": "..."},
  ...
]
```

#### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENAI_API_KEY` | _(empty)_ | Bearer token sent with every API request. |
| `VIA_API_CHAT_BASE` | `http://localhost:5000` | Base URL of the OpenAI-compatible chat-completions endpoint. Full URL used: `$VIA_API_CHAT_BASE/v1/chat/completions`. |

---

### `answer`

Extracts the content of the last message from a JSON conversation array.

#### Synopsis

```
answer
<conversation-json> | answer
```

#### Input

| Condition | Source |
|-----------|--------|
| stdin is a terminal and `$ANSWER` is set | Reads `$ANSWER` |
| stdin is a pipe | Reads stdin |

#### Output

The `.content` field of the last element of the JSON array (plain text, not JSON).

---

### `unfence`

Removes Markdown code fences (` ``` `) from its input, leaving only the content between the opening and closing fence markers.

#### Synopsis

```
<text-with-fences> | unfence
```

#### Behaviour

- Buffers all stdin.
- Finds the first opening ` ``` ` (with optional language tag) and extracts content up to the next ` ``` `.
- Handles multiple code blocks.
- If no fences are found the entire input is passed through unchanged.

---

### `bashfence`

Executes a command and wraps its stdout in a Bash code fence.

#### Synopsis

```
bashfence <command> [args...]
```

#### Output

````
```bash
$ <command> [args...]
<output>
```
````

The exit code of the wrapped command is preserved.

---

### `aliases`

A Bash source file that defines the `ask` shell function as a convenience wrapper around `ask.sh`. It exports the result in `$ANSWER` for use by `answer` without a pipe.

Source with:
```bash
source aliases
```

---

## Conversation JSON Schema

All conversation state is represented as a JSON array of message objects compatible with the OpenAI Chat Completions API:

```json
[
  {
    "role":    "system" | "user" | "assistant",
    "content": "<string>"
  }
]
```

`ask.sh` both consumes and produces this format, making it composable in pipelines of arbitrary depth.

---

## Pipeline Model

The central design pattern is the Unix pipeline. Conversation history flows left-to-right through the pipe:

```
ask "prompt 1" | ask "prompt 2" | ask "prompt 3" | answer
```

Each `ask` in the pipeline:
1. Reads the JSON history produced by the previous stage.
2. Appends a new user message.
3. Calls the API.
4. Appends the assistant reply.
5. Writes the updated JSON history to stdout.

`answer` terminates the pipeline by extracting and printing the final reply.

---

## API Contract

`ask.sh` targets any OpenAI-compatible `/v1/chat/completions` endpoint. The request body is a JSON object containing:

| Field | Value |
|-------|-------|
| `model` | `gpt-3.5-turbo` (hard-coded) |
| `messages` | Conversation history array |
| `temperature` | `0.7` |
| `max_tokens` | `4096` |
| `mode` | `instruct` |
| Additional sampler fields | `top_k`, `top_p`, `min_p`, `repeat_penalty`, `seed`, … |

---

## Dependencies

| Dependency | Purpose |
|------------|---------|
| `bash` | Shell interpreter for all scripts |
| `curl` | HTTP client for API calls |
| `jq` | JSON construction and extraction |
| `awk` | Text processing in `unfence` |
| Python 3 | Executing generated Python code (optional, user-supplied) |

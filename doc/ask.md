# ask

**ask** is the "State Builder" in the Answer framework. It is responsible for sending user prompts to the LLM API, managing the conversational history, and ensuring the conversation state flows correctly through Unix pipes.

## Synopsis

```bash
ask [OPTIONS] [PROMPT...]
```

When invoked as a shell function (via `enable.sh`), `ask` provides an enhanced interactive experience by automatically piping results to `answer` when used in a terminal.

## Description

`ask` is designed to be the primary entry point for starting or continuing a conversation. It can operate in several modes depending on whether it is receiving input from a pipe, a terminal, or a file. It manages conversation state by passing full JSON arrays of message objects between pipeline stages.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `-i` | `--input` | **Attachment Mode:** If used with a pipe or in a terminal, treats `stdin` as raw text to be prepended to the `PROMPT` with an `ATTACHMENT:` label. In interactive mode, this enables multi-line input (terminated with `Ctrl-D`). |
| `--use-system-message` | | Prepends the content of the `$SYSTEM_MESSAGE` environment variable as a `system` role message to the conversation. |
| `--help` | | Print usage information and exit. |

## Input Modes

The behavior of `ask` changes based on the input source:

| Condition | Behavior |
|-----------|----------|
| **Interactive (Terminal)** | Reads the command-line arguments as the user's prompt. |
| **Piped (JSON History)** | If `stdin` starts with the `PIPELINE_MAGIC_HEADER`, it treats the input as a full JSON conversation history and appends the prompt as a new `user` message. |
| **Piped (Raw Text)** | If `stdin` is a pipe but does **not** contain the magic header, it treats the incoming text as raw content to be prepended to the prompt (prefixed with `CONTEXT:`). |

## Output Modes

| Context | Behavior |
|---------|----------|
| **Interactive (Terminal)** | The JSON output is automatically passed to `answer`. The user sees the human-readable text response, and the global `LAST_ANSWER` variable is updated. |
| **Pipeline (Non-Terminal)** | Outputs the `PIPELINE_MAGIC_HEADER` followed by the updated JSON conversation array to `stdout`. This allows the next command in the pipe (like `ask` or `tools`) to continue the conversation. |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENAI_API_KEY` | _(empty)_ | Bearer token for API authentication. |
| `VIA_API_CHAT_BASE` | `http://localhost:5000` | The base URL for the OpenAI-compatible API. |
| `SYSTEM_MESSAGE` | _(empty)_ | The text used as the initial `system` role message when `--use-system-message` is passed. |

## Examples

**1. Basic Interactive Question**
```bash
$ ask "What is the capital of Japan?"
💭
The capital of Japan is Tokyo.
```

**2. Piped Text as Context (Standard Pipe)**
Pass the contents of a file to the LLM. The content will be prefixed with `CONTEXT:` in the message.
```bash
$ cat logs.txt | ask "Are there any errors in these logs?"
💭
Yes, there is an error on line 42 regarding a connection timeout.
```

**3. Using Attachment Mode (`-i`)**
When using `-i`, the content is prefixed with `ATTACHMENT:`. This is useful if you want to explicitly signal to the LLM that the piped content is a formal attachment.
```bash
$ cat logs.txt | ask -i "Analyze this attachment"
💭
The provided attachment contains several warnings...
```

**4. Chained Conversation (Pipeline Mode)**
Maintain state across multiple commands.
```bash
$ ask "Who is the President of France?" | ask "How old is he?"
💭
Emmanuel Macron is the President of France. He was born in 1977, making him approximately 46 years old.
```

**5. Using System Messages**
```bash
$ export SYSTEM_MESSAGE="You are a helpful Linux expert."
$ ask "How do I check disk usage?" --use-system-message
```

**6. Complex Pipeline with Tools**
Send a file, ask a question, resolve tool calls, and finally extract the text.
```bash
$ cat code.py | ask "Refactor this" | tools python_tools | answer
```


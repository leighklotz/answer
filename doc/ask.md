# ask

**ask** is the "State Builder" in the Answer framework. It is responsible for sending user prompts to the LLM API, managing the conversational history, and ensuring the conversation state flows correctly through Unix pipes.

## Synopsis

```bash
ask [OPTIONS] [PROMPT...]
```

The first non-flag argument begins the prompt.

## Pipeline Model
The `ask` command always generates **JSON** to preserve the conversation state. However, JSON is difficult for humans to read in a terminal.
*   **`ask`**: Produces raw JSON (The "Machine" layer).
*   **`answer`**: Converts JSON into human-readable text (The "Presentation" layer).

The `ask` command includes an **"Auto-answer"** feature: if it detects it is running in an interactive terminal, it automatically pipes its JSON through `answer` for you.

- **Interactive Mode (Auto-answer):** When running in a terminal where `stdout` is the screen, `ask` automatically pipes the JSON through `answer`. You see human-readable text.
- **Pipeline Mode:** When `ask` is used in a script or piped into another command, it outputs **raw JSON**. This allows the next command to read the conversation state.
- **Manual Mode:** If `ask`'s output is redirected to a file (`> file.json`), auto-answer is disabled, and the file will contain raw JSON.

## Description

`ask` is designed to be the primary entry point for starting or continuing a conversation. It manages conversation state by passing full JSON arrays of message objects between pipeline stages.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `-i` | `--input` | **Attachment Mode:** Forces `stdin` to be treated as a formal attachment. Content is appended to the prompt with an `ATTACHMENT:` label. In a terminal, this enables multi-line input (terminated with `Ctrl-D`). |
| `-t` | `--tee` | **Observation Mode:** Prints the human-readable response to **stderr** while passing the updated, resolved JSON conversation history to **stdout**. |
| `--use-system-message` | | Prepends the content of the `$SYSTEM_MESSAGE` environment variable as a `system` role message to the conversation. |
| `--help` | | Print usage information and exit. |

## Input Modes

The behavior of `ask` changes based on the input source and flags:

| Condition | Logic | Resulting Message Format |
|-----------|-------|--------------------------|
| **Interactive (Terminal)** | No stdin / No flags | `[Prompt]` |
| **Piped (JSON History)** | `stdin` starts with `PIPELINE_MAGIC_HEADER` | `[Existing History] + [Prompt]` |
| **Piped (Raw Text)** | `stdin` is raw text + Prompt provided | `[Prompt] + "\n\nCONTEXT:\n" + [stdin]` |
| **Piped (Raw Text)** | `stdin` is raw text + No prompt | `[stdin]` |
| **Attachment Mode (`-i`)** | `stdin` provided (Pipe or TTY) | `[Prompt] + "\n\nATTACHMENT:\n" + [stdin]` |

## Output Modes

| Context | Behavior |
|---------|----------|
| **Interactive (Terminal)** | **Auto-answered:** The JSON is automatically passed to `answer`. The user sees the answer text. |
| **Pipeline (Non-Terminal)** | Outputs the `PIPELINE_MAGIC_HEADER` followed by the updated JSON conversation array to `stdout`. |
| **Observation (`--tee`)** | Prints the human-readable text response to **stderr** and sends the resolved JSON conversation history to **stdout**. |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENAI_API_KEY` | _(empty)_ | Bearer token for API authentication. |
| `VIA_API_CHAT_BASE` | `http://localhost:5000` | The base URL for the OpenAI-compatible API. |
| `SYSTEM_MESSAGE` | _(empty)_ | The text used as the initial `system` role message when `--use-system-message` is used. |

## Examples

**1. Basic Interactive Question**
```bash
$ ask "What is the capital of Japan?"
💭
The capital of Japan is Tokyo.
```

**2. Piped Text as Context**
Pass the contents of a file to the LLM. Because no `-i` is used, it is treated as general context.
```bash
$ cat logs.txt | ask "Are there any errors in these logs?"
💭
Yes, there is an error on line 42 regarding a connection timeout.
```

**3. Using Attachment Mode (`-i`)**
Use `-i` to explicitly signal to the LLM that the piped content is a formal attachment.
```bash
$ cat logs.txt | ask -i "Analyze this attachment"
💭
The provided attachment contains several warnings...
```

**4. Chained Conversation (Pipeline Mode)**
The first `ask` provides JSON to the second `ask`, allowing it to remember the context.
```bash
$ ask "Who is the President of France?" | ask "How old is he?"
💭
Emmanuel Macron is the President of France. He was born in 1977.
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

**7. Observation Mode (Mid-Pipeline)**
Use `-t` to see the text in the terminal while passing JSON down the pipe to maintain state.
```bash
$ ask "Write a bash script" | ask -t "Add error handling" | answer
```

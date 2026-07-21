# ask

**ask** is the "State Builder" in the Answer framework. It is responsible for sending user prompts to the LLM API, managing the conversational history, and ensuring the conversation state flows correctly through Unix pipes.

## Synopsis

```bash
ask [OPTIONS] [PROMPT...]
```

The first non-flag argument begins the prompt.

## Pipeline Model
The `ask` command always generates **JSON** to preserve the conversation state, but when used to pipe to another **Answer** tool (like `answer`), or when output is direct to a terminal via a shell function, it provides only the last assistant response for human consumption while maintaining structured data in the background.

- **Interactive Mode (Auto-answer):** When running in a terminal where `stdout` is your screen, `ask` automatically pipes the JSON through `answer`. You see clean, human-readable text.
- **Pipeline Mode:** When `ask` is used in a script or piped into another command (e.g., `... | ask`), it outputs **raw JSON** containing the full conversation history. This allows subsequent tools to read and extend the context seamlessly.
- **Manual/File Mode:** If `ask`'s output is redirected directly to a file (`> chat_history.json`), auto-answer is disabled, and the file will contain raw JSON structured with the appropriate MIME headers.

## Description

`ask`, along with its optimized wrappers like `help`, serves as the primary entry point for starting or continuing an AI conversation. It manages state by passing full conversation arrays between pipeline stages via standard input/output streams using a magic header (`Content-Type: application/x-llm-history+json`). 

The command performs "idempotent" turn resolution: it checks if the incoming history already ends with an `assistant` role. If it does, the message is passed through unchanged to prevent redundant API calls; new inference is only triggered when the last message in the sequence is from a `user`.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `-i` | `--input` | **Attachment Mode:** Forces `stdin` to be treated as a formal attachment. Content is appended to the end of the prompt with an `ATTACHMENT:` label. In interactive terminals, this enables multi-line input (terminated with `Ctrl-D`). |
| `-t` | `--tee` | **Observation Mode:** Prints a human-readable preview of the assistant's response to **stderr** while passing the updated JSON conversation history through **stdout**. This allows you to monitor progress without breaking pipeline chains. |
| `--use-system-message` | | Prepends the content of the `$SYSTEM_MESSAGE` environment variable as a `system` role message at the start of the session. |
| `--help` | | Print usage information and exit. |

## Input Modes

The behavior of `ask` changes based on whether it is extending an existing conversation or starting a new one:

| Condition | Logic | Resulting Message Format |
|-----------|-------|--------------------------|
| **Interactive (Terminal)** | No stdin / No flags | A single message containing the provided prompt. |
| **Piped (JSON History)** | `stdin` begins with `PIPELINE_MAGIC_HEADER` | The existing conversation array is extended with your new prompt as a `user` role. |
| **Piped (Raw Text) + Prompt** | `stdin` is raw text and a prompt is provided | A new JSON array is created, containing the prompt followed by the piped text as context. |
| **Piped (Raw Text) + No Prompt** | `stdin` is raw text and no prompt provided | The input itself becomes the first message in a new conversation. |
| **Attachment Mode (`-i`)** | `stdin` provided via pipe or TTY | Your prompt is followed by an explicit `ATTACHMENT:` block containing the piped content. |

## Output Modes

The output behavior depends on how you are using it as part of a pipeline:

| Mode | Context | stdout (Data stream) | stderr (Terminal Feedback) |
|---------|----------|-------------------|----------------------------|
| **Observation** (`--tee`) | Mid-pipeline inspection (e.g., `... \| ask --tee \| next_cmd`) | The full, updated JSON conversation array. | A human-readable preview of the response + inference status emojis (✨/🎯/🧠). |
| **Extraction Endpoint** | Used as a terminal endpoint for tools (e.g., `... \| answer \| python`) | Raw plain text content of only the assistant's latest message. | Inference status icons and errors. |
| **Terminal Interaction** | Standard use in an active bash session via shell functions | The human-readable response from the LLM. | Message formatting/status indicators + newline for visual separation. |

## Environment Variables

These variables control how requests are constructed and sent to your API endpoint:

| Variable | Default Behavior / Value | Description |
|----------|-------------------------|-------------|
| `OPENAI_API_KEY` | _(empty)_ | Bearer token used for API authentication. |
| `VIA_API_CHAT_BASE` | N/A (Required) | The base URL of the OpenAI-compatible API endpoint. |
| `ENABLE_THINKING` | `false` | When set to `true`, includes specialized reasoning parameters (`thinking`/`enable_thinking`) in the request payload for supported models. |
| `VIA_MAX_TOKENS` | `24000` | The maximum number of tokens allowed for the completion response. |
| `SYSTEM_MESSAGE`| _(empty)_ | Text used as the initial `system` role message when `--use-system-message` is active. |

*Note: If multiple models are available at your API endpoint, `ask` will automatically attempt to select a model that has its status set to `"loaded"` via `${VIA_API_CHAT_BASE}/models`.*

## Examples

**1. Basic Interactive Question**
Get immediate assistance in your terminal session.
```bash
$ ask "What is the capital of Japan?"
💭
The capital of Japan is Tokyo.
```

**2. Piped Text as Context**
Pass a file's content into the LLM to use as context for your question.
```bash
$ cat logs.txt | ask "Are there any errors in these logs?"
💭
Yes, there is an error on line 42 regarding a connection timeout.
```

**3. Using Attachment Mode (`-i`)**
Explicitly signal that the piped content should be treated as a formal file attachment for more precise reasoning.
```bash
$ cat script.py | ask -i "Refactor this code"
💭
I have reviewed the attached script and suggest...
```

**4. Chained Conversation (Pipeline Mode)**
Maintain conversation history across multiple commands in a shell pipeline.
```bash
# Each command passes its JSON state to the next via stdout
$ ask "Who is the President of France?" | ask "How old is he?"
💭
Emmanuel Macron is the President of France. He was born in 1977.
```

**5. Observation Mode (Mid-Pipeline)**
Use `-t` to see what the model is thinking or generating while allowing JSON state to flow down the pipe for further processing.
```bash
$ ask "Write a complex bash script" | ask -t "Now add error handling" | answer --tee > final_script.sh
# The preview appears in your terminal via stderr; stdout sends clean text/JSON as requested.
```

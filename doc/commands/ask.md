# ask

**ask** is the "State Builder" in the Answer framework. It is responsible for building user prompts into a JSON conversation payload, managing the conversational history, and ensuring the conversation state flows correctly through Unix pipes.

## Synopsis

```bash
ask [OPTIONS] [PROMPT...]
```

The first non-flag argument begins the prompt.

## Description

`ask`, along with its optimized wrappers like `help`, serves as the primary entry point for starting or continuing an AI conversation. It manages state by passing full conversation arrays between pipeline stages via standard input/output streams using a magic header (`Content-Type: application/x-llm-history+json`).

The command performs "idempotent" turn resolution via the downstream `answer`/`_infer` engine: it checks if the incoming history already ends with an `assistant` role. If it does, the message is passed through unchanged to prevent redundant API calls; new inference is only triggered when the last message in the sequence is from a `user`. It also automatically detects and acknowledges reasoning/thinking blocks provided by models.

Routing is mode dependent:
* `--tee` / `-t` resolves the turn immediately via `_infer`, prints a human readable preview to stderr and forwards the updated JSON history to stdout.
* Interactive terminal or `--answer` pipes the built message payload through `${SCRIPT_DIR}/answer` for immediate plain-text output.
* Pure pipeline mode forwards `PIPELINE_MAGIC_HEADER` + messages to stdout for the next stage.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `-i` | `--input` | **Attachment Mode:** Forces `stdin` to be treated as a formal attachment. Content is appended after the prompt, separated by a blank line. In interactive terminals, this enables multi-line input terminated with `Ctrl-D`. |
| `-t` | `--tee`   | **Observation Mode:** Resolves the turn via `_infer`, prints a human-readable preview of the assistant's response to **stderr** while passing the updated JSON conversation history through **stdout**. This allows you to monitor progress without breaking pipeline chains. |
| `--use-system-message` | | Prepends the content of the `$SYSTEM_MESSAGE` environment variable as a `system` role message at the start of the session. |
| `--answer` | | **Answer Mode:** Forces routing through `answer` even when stdout is not a TTY. The built message payload is piped to `answer` for immediate inference and plain-text output, equivalent to interactive terminal behavior. |
| `--help` | | Print usage information and exit. `Usage: ask [-i|--input] [--use-system-message] [--tee|-t] [prompt]` |

## Input Modes

The behavior of `ask` changes based on whether it is extending an existing conversation or starting a new one:

| Condition | Logic | Resulting Message Format |
|-----------|-------|--------------------------|
| **Interactive (Terminal)** | No stdin / No flags | A single message `{"role":"user","content":$prompt}`. If stdout is a TTY the payload is piped to `answer`. |
| **Piped (JSON History)** | `stdin` begins with `PIPELINE_MAGIC_HEADER` | Header is stripped, the JSON is resolved via `_infer`, and your new prompt is appended as a `user` role. If no prompt is given the resolved history is passed through unchanged. |
| **Piped (Raw Text) + Prompt** | `stdin` is raw text and a prompt is provided, `-i` not set | A new JSON array is created with `{"role":"user","content": $prompt + "\n\nCONTEXT:\n" + $stdin}`. |
| **Piped (Raw Text) + No Prompt** | `stdin` is raw text and no prompt provided | The input itself becomes the first message in a new conversation: `[{"role":"user","content": $stdin}]`. |
| **Attachment Mode (`-i`)** | `stdin` provided via pipe or TTY | Your prompt is followed by the piped content separated by a blank line: `{"role":"user","content": $prompt + "\n\n" + $stdin}`. |

## Output Modes

The output behavior depends on how you are using it as part of a pipeline:

### 1. Data Stream (stdout)
| Mode | Context | stdout (Data stream) | stderr (Terminal Feedback) |
|------|---------|-------------------|----------------------------|
| **Extraction Endpoint** | Terminal or `--answer` mode, `... \| answer \| python` | Plain text from `answer` – raw content of the assistant's latest message. | Inference status icons and errors from `answer`. |
| **Pipeline Mode** | Non-TTY, no `--tee`, no `--answer` | `PIPELINE_MAGIC_HEADER` + JSON messages for the next stage. | `💬` indicator. |
| **Observation Mode (`--tee`)** | Mid-pipeline inspection | `PIPELINE_MAGIC_HEADER` + full resolved JSON conversation array. | Human-readable assistant preview + inference status emojis. |

### 2. Visual Feedback (stderr)
During interactive terminal use or observation mode, `ask` provides real-time feedback on the state of your request via **stderr**:
* ✨ **Fresh Request:** A new call was made to the LLM API.
* 🎯 **Cache Hit:** The response was retrieved instantly from your local cache.
* 🧠 **Reasoning/Thinking:** The model provided a reasoning or "thinking" block e.g. `reasoning_content`.

## Environment Variables

These variables control how requests are constructed and sent to your API endpoint:

| Variable | Default Behavior / Value | Description |
|----------|-------------------------|-------------|
| `OPENAI_API_KEY` | _(empty)_ | Bearer token used for API authentication. |
| `VIA_API_CHAT_BASE` | N/A (Required) | The base URL of the OpenAI-compatible API endpoint. |
| `ENABLE_THINKING` | `false` | When set to `true`, includes specialized reasoning parameters (`thinking`/`enable_thinking`) in the request payload for supported models. |
| `VIA_MAX_TOKENS` | `24000` | The maximum number of tokens allowed for the completion response. |
| `SYSTEM_MESSAGE`| _(empty)_ | Text used as the initial `system` role message when `--use-system-message` is active. |

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
✨
Yes, there is an error on line 42 regarding a connection timeout.
```

**3. Using Attachment Mode (`-i`)**
Explicitly signal that the piped content should be treated as a formal file attachment for more precise reasoning.
```bash
$ cat script.py | ask -i "Refactor this code"
🧠✨
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

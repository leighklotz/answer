# answer

**`answer`** is an extractor and bridge between structured LLM conversation state (JSON) and standard shell execution (Pristine Plain Text). 

It acts as a **terminal converter**: it transforms heavy, metadata-rich JSON arrays into the raw text strings that standard command-line tools (`grep`, `python`, `bash`, `unfence`) expect. It is also **state-resolving**: if an incoming message ends with a `user` role, `answer` automatically triggers the inference engine to complete the turn before extracting the assistant's response.

## Synopsis

```bash
<conversation-json> | answer [OPTIONS]
```

## Description

In a pipeline, commands like `ask` and `tools` pass complex JSON arrays containing message histories (using the `PIPELINE_MAGIC_HEADER`). The `answer` command is used to "exit" conversation mode by stripping away all metadata and leaving only the human-readable text.

### The Resolution Step
If you pipe a conversation history into `answer` that ends with a user prompt, it does not simply parse the JSON; it actively executes an inference call. It ensures the turn is completed (the assistant responds) before extracting the final message content. This allows you to use `ask ... | answer` in scripts where you only care about what the AI actually said, rather than the underlying data structure.

## Options

| Flag | Long form | Description |
|------|------------------------|---------------------------------------------------------------------------------------------------|
| `-t` | `--tee`   | **Observation Mode:** When used within a pipeline, this prints a visual preview of the extracted text to **stderr** (with a 👕 emoji) so you can read it in your terminal. The actual `stdout` remains pure plain text for the next command in the pipe. |
| `-j` | `--json`  | **Data Mode:** Instead of extracting plain text, outputs the full resolved JSON conversation array (preceded by `PIPELINE_MAGIC_HEADER`) to `stdout`. Useful for passing structured state to other tools. |

## Input Modes

The behavior of `answer` depends on whether it receives structured history or raw data:

| Condition | Behavior |
|-----------|----------|
| **Piped (JSON History)** | Reads a `PIPELINE_MAGIC_HEADER` and the JSON conversation array from `stdin`. If the last message is from the user, it triggers inference to resolve the turn. |
| **Piped (Raw Text/Context)** | Treats incoming raw text as part of an existing state; resolves via inference if necessary, then extracts the resulting assistant response content. |

## Output Modes

`answer` sends data to `stdout`, but its behavior on your terminal screen and what is passed down the pipeline changes based on how it is used:

### 1. Standard Outputs
| Mode | Context | stdout (Data stream) | stderr (Terminal Feedback) |
|------|---------|-------------------|----------------------------|
| **Extraction** (Default/Interactive) | Used as a terminal endpoint or in an interactive prompt. | Raw plain text of the assistant's response. | Inference status icons + Errors. |
| **Observation** (`--tee` in a pipe) | `... \| answer --tee \| next_cmd`. Use this to see what is happening without breaking the pipeline. | Raw plain text of the assistant's response. | A visual "preview" (with 👕 emoji) so you can monitor progress while data flows through stdout. |
| **JSON Mode** (`--json`) | Used when continuing a structured pipeline with other tools that require JSON history. | Full resolved JSON conversation array (+ magic header). | Inference status icons + Errors. |

### 2. Visual Feedback (`stderr`)
When performing inference, `answer` provides immediate status feedback via emojis on `stderr`:
* 🎯 **Cache Hit:** The response was retrieved instantly from your local cache.
* ✨ **Fresh Request:** A new request was sent to the LLM API.
* 🧠 **Thinking/Reasoning:** Detected that the model provided a reasoning or "thinking" block (e.g., `reasoning_content`).

## Examples

**1. Direct Extraction (Terminal Mode)**
Extract the text of an assistant response from a conversation history for reading in your terminal.
```bash
$ ask "What is 2+2?" | answer
4
```

**2. The "Cut-Point" (Extraction for Tooling)**
Convert LLM output into clean text that standard shell tools like `python` or `unfence` can process without JSON interference.
```bash
ask "Write a python script to print 'Hello World'" | answer | unfence | python
```

**3. Observation Mode (Mid-Pipeline Logic)**
See the response in your terminal as it is being generated, while passing only the raw text down the pipe so that the next command receives clean input rather than JSON history.
```bash
# The preview appears on screen via stderr; stdout passes 'Hello' to echo.
$ ask "Say Hello" | answer --tee | echo "The AI said:" 
👕Hello
The AI said:Hello
```

**4. Resolving and Extracting from Cache**
If you repeat an identical query, `answer` will indicate the cache was used via stderr before printing the result to stdout:
```bash
$ ask "What is 5 + 5?" | answer
🎯
10
```

**5. Structured Pass-through (JSON Mode)**
Pass the entire updated conversation history (including the new assistant message) to another tool that expects JSON context.
```bash
$ ask "Who won the Super Bowl in 2024?" | answer --json | next_structured_tool
# Output: [MAGIC_HEADER]\n[{"role": "user", ...}, {"role": "assistant", ...}]
```

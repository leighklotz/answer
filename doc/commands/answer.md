# answer

**`answer`** is an extractor and bridge between structured LLM conversation state (JSON) and standard shell execution (Pristine Plain Text). It acts as a **terminal converter**: it transforms heavy, metadata-rich JSON arrays into the raw text strings that standard command-line tools (`grep`, `python`, `bash`, `unfence`) expect. 

It is also an **inference trigger**: if you pipe content to `answer` (whether via structured history or raw piped text), and the resulting state ends with a user role, it automatically executes an inference call to resolve the turn before extracting the assistant's response. This ensures that pipelines remain continuous even when transitioning from human-readable input back into machine-executable code.

## Synopsis

```bash
<conversation-json | raw_text> | answer [OPTIONS]
```

## Description

In a pipeline, commands like `ask` and `tools` pass complex JSON arrays containing message histories (prefixed with the `PIPELINE_MAGIC_HEADER`). The `answer` command is used to "exit" conversation mode by stripping away all metadata and leaving only the human-readable text.

### Automated Turn Resolution
If you pipe a sequence of messages into `answer` that ends in a user prompt, it does not simply parse the JSON; it actively triggers an inference request to the LLM API to complete the turn. This allows for seamless chaining where you can pass raw terminal output or previous conversation history directly into `answer` and receive only the finalized response from the assistant.

## Options

| Flag | Long form | Description |
|------|------------------------|---------------------------------------------------------------------------------------------------|
| `-t` | `--tee`   | **Observation Mode:** When used within a pipeline, this prints a visual preview of the extracted text to **stderr** (with a 👕 emoji) so you can monitor progress in your terminal. The actual `stdout` remains pure plain text for the next command in the pipe. |
| `-j` | `--json`  | **Data Mode:** Instead of extracting plain text, outputs the full resolved JSON conversation array (preceded by `PIPELINE_MAGIC_HEADER`) to `stdout`. Useful when passing structured state to subsequent tools like `tools` or other LLM wrappers. |

## Input Modes

The behavior of `answer` depends on whether it receives a structured pipeline header or raw stream data:

| Condition | Behavior |
|-----------|----------|
| **Piped (JSON History)** | Reads the `PIPELINE_MAGIC_HEADER`. If the last message is from the user, it triggers an inference call to resolve the turn before extracting content. |
| **Piped (Raw Text/Context)**| Treats incoming raw text as a new prompt or context; resolves via inference if necessary, then extracts the resulting assistant response content. |

## Output Modes

### 1. Standard Outputs
| Mode | Context | stdout (Data stream) | stderr (Terminal Feedback) |
|------|---------|-------------------|----------------------------|
| **Extraction** (Default/Interactive) | Used as a terminal endpoint for reading or piping to tools like `unfence`. | Raw plain text of the assistant's response. | Inference status icons + Errors. |
| **Observation** (`--tee` in a pipe) | Use this to see what is happening without breaking the pipeline structure. | Raw plain text of the assistant's response. | A visual "preview" (with 👕 emoji). |
| **JSON Mode** (`--json`) | Used when continuing a structured conversation chain. | Full resolved JSON conversation array (+ magic header). | Inference status icons + Errors. |

### 2. Visual Feedback (`stderr`)
When performing inference, `answer` provides immediate status feedback via emojis on `stderr`:
* 🎯 **Cache Hit:** The response was retrieved instantly from your local cache.
* ✨ **Fresh Request:** A new request was sent to the LLM API.
* 🧠 **Reasoning/Thinking:** Detected that the model provided a reasoning or "thinking" block (e.g., `reasoning_content`).

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
Pass the entire updated conversation history (including the new assistant message) back into a pipeline that requires structured context.
```bash
$ ask "Who won the Super Bowl in 2024?" | answer --json | next_structured_tool
# Output: [MAGIC_HEADER]\n[{"role": "user", ...}, {"role": "assistant", ...}]
```

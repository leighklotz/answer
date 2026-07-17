# answer

**`answer`** is the text extractor and pipeline cut-point in Answer. It bridges the gap between LLM conversation state (structured JSON) and standard shell execution (Pristine Plain Text). 

It is a **state-resolving** command: if an incoming message ends with a `user` role, `answer` automatically triggers the inference engine to complete the turn before extracting the assistant's response. This makes it essential when you need the final output of an LLM chain to be passed into another tool (like `python`, `bash`, or `unfence`) as clean text rather than raw JSON history.

## Synopsis

```bash
<conversation-json> | answer [OPTIONS]
```

## Description

In a pipeline, commands like `ask` and `tools` pass heavy JSON arrays to maintain conversation state (via the `PIPELINE_MAGIC_HEADER`). The `answer` command acts as the gateway that allows you to transition from "conversation mode" (passing structured data) to "tooling/shell mode" (passing plain text).

### The Resolution Step
Unlike a simple parser, `answer` is an active participant in the pipeline. If the incoming JSON history represents an incomplete conversation—meaning the last message is from the `user`—`answer` executes a call to the internal inference engine to generate and append the assistant's response. Once resolved, it strips all metadata (headers/JSON structure) and delivers only the final text content of the assistant's reply.

If the input provided does not contain a conversation history but is treated as raw text, `answer` wraps that text into a message array and performs an inference call to resolve the turn.

## Options

| Flag | Long form | Description |
|------|------------------------|-------------------------------------------------------------------------------------------------------------------|
| `-t` | `--tee`   | **Observation Mode:** Prints the plain text content of the last message to **stderr** for human readability while passing the full, updated JSON conversation array through `stdout`. This allows you to monitor a pipeline without breaking context. |

## Input Modes

The behavior of `answer` depends on whether it receives structured history or raw data:

| Condition | Behavior |
|-----------|----------|
| **Piped (JSON History)** | Reads a `PIPELINE_MAGIC_HEADER` and the JSON conversation array from `stdin`. If the last message is from the user, it triggers inference to resolve the turn. |
| **Piped (Raw Text/Context)** | Treats incoming raw text as part of an existing state; resolves via inference if necessary, then extracts the resulting assistant response. |

## Output Modes

The behavior and feedback on `stderr` depend on how you use the command:

### 1. Standard Outputs
| Mode | Context | stdout | stderr (Feedback) |
|------|---------|--------|-------------------|
| **Observation** (`--tee`) | Used mid-pipeline to see progress without breaking context (e.g., `... \| answer --tee \| ask ...`) | The full, updated JSON conversation array | Plain text content of the message + Inference status icons |
| **Extraction** (no flags) | Used as a terminal endpoint for tools/files (e.g., `... \| answer \| python`) | Raw plain text of the assistant's response | Inference status icons or errors |

### 2. Visual Feedback (`stderr`)
When performing inference, `answer` provides immediate visual feedback via emojis on `stderr`:
* 🎯 **Cache Hit:** The response was retrieved instantly from your local cache.
* ✨ **Fresh Request:** A new request was sent to the LLM API.
* 🧠 **Thinking/Reasoning:** Detected that the model provided a reasoning or "thinking" block (e.g., `reasoning_content`).

## Examples

**1. Direct Extraction (Terminal Mode)**
Retrieve the text of an assistant response from a conversation history in your terminal.
```bash
$ ask "What is 2+2?" | answer
4
```

**2. The "Cut-Point" (Extraction for Tooling)**
Convert LLM output into clean text that standard shell tools like `python` or `bash` can process without JSON interference.
```bash
ask "Write a python script to print 'Hello World'" | answer | unfence | python
```

**3. Observation Mode (Mid-Pipeline Logic)**
See the response in your terminal so you can read it, while passing the updated state down the pipe so you can continue the conversation with another `ask`.
```bash
$ ask "Plan a complex bash script" | answer --tee | ask "Now add logging to that plan"
# The code appears on your screen (via stderr), but JSON flows through stdout.
```

**4. Resolving and Extracting from Cache**
If you repeat an identical query, `answer` will indicate the cache was used:
```bash
$ ask "What is 5 + 5?" | answer
🎯
10
```

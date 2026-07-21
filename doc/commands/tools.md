# tools

**`tools`** is a pipeline wrapper used to resolve native LLM tool calls (function calling). It transforms an LLM's request to execute a function into actual command execution, appending the results back into the conversation history as `tool` role messages so the model can continue its reasoning in subsequent turns.

## Synopsis

```bash
<conversation-json> | tools [MODULE_NAME...]
```

The arguments are one or more module names that define which sets of functions/tools the LLM is allowed to call during this pipeline stage. Each argument is passed as a `--tools <name>` flag to the underlying execution engine (typically `toolex.py`).

## Description

When using models that support **Function Calling**, an LLM may return a request to execute a specific function (e.g., `git_branch_list` or `get_system_uptime`) rather than returning plain text. 

The `tools` command acts as the bridge for these requests within an Answer pipeline:
1.  **Intercepts:** It reads the conversation JSON history from `stdin`.
2.  **Identifies:** It scans the latest message in the array for pending `tool_calls`.
3.  **Executes:** For each call, it uses a specified module (via `toolex.py`) to run the requested function on your local system.
4.  **Updates State:** It appends the execution results back into the conversation array as new messages with the role of `tool`, preserving the conversational flow for downstream components that support structured JSON history.

## Input & Output

| Component | Format | Description |
| :--- | :--- | :--- |
| **Input (`stdin`)** | JSON Conversation Array | Must be formatted as an Answer pipeline history (prefixed with the `PIPELINE_MAGIC_HEADER`). |
| **Output (`stdout`)** | Updated JSON Conversation Array | The original conversation, augmented with new messages containing the tool execution results. |

## Requirements

*   `toolex.py` must be installed and available on your `$PATH`.
*   The modules you intend to use (e.g., `git`, `linux_tools`) must be compatible with `toolex.py`.

## Examples

### 1. Basic Git Integration
Allow the LLM to inspect your local repository state by providing the `git` module:
```bash
$ ask "What branches are not merged into main?" | tools git | answer
# Output is plain text (thanks to 'answer') of the tool's result via the model.
```

### 2. Multiple Modules in a Pipeline
Provide multiple capability sets at once by passing them as separate arguments:
```bash
$ ask "Check for uncommitted changes and summarize my current system uptime" | tools git system_info
# This expands to executing with --tools git --tools system_info
```

### 3. Mid-Pipeline Observation (Maintaining Context)
To observe the results of a tool call without breaking the JSON conversation chain, use `ask` or `help` with the `-t` (`--tee`) flag instead of `answer`. This ensures that subsequent commands in the pipeline still receive the full structured history including the new `tool` messages.

```bash
# Use -t to see results via stderr; stdout carries JSON for the next 'ask' turn
$ ask "Check my disk usage" | tools bash | help "How much space is left on /home?" --tee
🤖 Proceed with this command? (y/N): y 📊🔍✨💭
# The model uses the tool result from stdin to answer your follow-up.
```

### 4. Final Extraction
After a chain of tools has been resolved and processed, use `answer` at the very end of the pipeline to extract the final human-readable response:
```bash
$ ask "Use git log to find the last three commits" | tools git | answer
# [Output is plain text from the model's summary]
```

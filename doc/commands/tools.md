# tools

**`tools`** is a pipeline wrapper used to resolve native LLM tool calls (function calling). It transforms an LLM's request to execute a function into actual command execution, appending the results back into the conversation history as `tool` role messages so the model can continue its reasoning in subsequent turns.

## Synopsis

```bash
<conversation-json> | tools [MODULE[:CAPABILITY[=PATTERN]]]...
```

The arguments specify which modules are available to the LLM and what restrictions apply. These arguments are passed as `--tools` flags to the underlying engine (`toolex.py`). You can mix multiple modules with different levels of permission (e.g., `file:read=*.txt git:all bash:run=*`).

## Description

When using models that support **Function Calling**, an LLM may return a request to execute a specific function rather than returning plain text. 

The `tools` command acts as the bridge for these requests within an Answer pipeline:
1.  **Intercepts:** It reads the conversation JSON history from `stdin`.
2.  **Identifies:** It scans the latest message in the array for pending `tool_calls`.
3.  **Executes:** For each call, it uses a specified module to run the requested function on your local system while enforcing **Runtime Path/Resource Restriction**.
4.  **Updates State:** It appends results back into the conversation as messages with the role of `tool`, preserving context for downstream components.

## Permission & Restriction Syntax

To maximize security, you can restrict tools not just by *module*, but also by specific *capabilities* and resource *patterns* (using shell-style globs). The engine enforces these restrictions during execution; if a tool attempts to access a file or resource that does not match the provided pattern, it will return an "Access Denied" error to the LLM.

| Syntax | Meaning | Example | Effect |
| :--- | :--- | :--- | :--- |
| `module` | **Full Access** | `git` | Grants all capabilities (e.g., read/write) within that module. |
| `mod:cap` | **Capability Scoping** | `file:read` | Allows the `read` capability for any resource in the file module, but denies `write`. |
| `mod:cap=pat` | **Resource Restriction** | `file:read=*.py` | The LLM can only use `file:read` on files ending in `.py`. Accessing `README.md` will fail. |
| `mod:cap=p1,p2` | **Multiple Patterns** | `file:read=docs/*.md,log/*.txt` | Allows reading any markdown file in `/docs/` or text files in `/logs/`. |

## Input & Output

| Component | Format | Description |
| :--- | :--- | :--- |
| **Input (`stdin`)** | JSON Conversation Array | Must be formatted as an Answer pipeline history (prefixed with the `PIPELINE_MAGIC_HEADER`). |
| **Output (`stdout`)** | Updated JSON Conversation Array | The original conversation, augmented with new messages containing tool execution results. When `stdout` is a TTY, it is automatically piped through `answer`. |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TOOLEX_SH` | `$HOME/wip/toolex/toolex.sh` | Path to the `toolex.sh` execution engine. |
| `TOOLS_FLAGS` | _(empty)_ | Additional flags passed to `toolex.sh`. |
| `TRACE` | _(empty)_ | When set and `stdout` is a TTY, raw tool output is teed to `stderr` for debugging. |

## Visual Feedback (`stderr`)

When running in an interactive terminal:
* 🤖 **Confirmation Prompt:** Indicates an execution request requiring user permission (if configured).
* ✨ / 🎯 / 🧠 : Status icons indicating inference progress, cache hits, or reasoning content.

## Examples

### 1. Basic Git Integration
Allow the LLM to inspect your repository state with full access:
```bash
$ ask "What branches are not merged into main?" | tools git | answer
```

### 2. Granular File Access (Secure)
Restrict the LLM so it can only read documentation files and cannot write anything, even if a `write` tool is present in the module:
```bash
# Only allows reading .md or .txt files; no access to source code/binaries.
$ ask "Summarize README.md" | tools file:read=*.md,file:read=*.txt | answer
```

### 3. Complex Multi-Module Restrictions
Mix a highly restricted module with a broadly permitted one:
```bash
# Can run any bash command, can read any git status, but can only read .py files via the 'file' tool.
$ ask "Check git log and find all python imports in main.py" | tools bash:run=* git system_info file:read=*.py | answer
```

### 4. Mid-Pipeline Observation
Use `-t` (tee) to see what is happening without breaking the JSON chain for subsequent commands:
```bash
$ ask "Check my disk usage" | tools bash -t | help "How much space is left?" --tee
# stdout carries JSON; stderr shows terminal status and results.
```

### 5. Final Extraction
Always use `answer` at the end of a pipeline to convert the final tool-augmented JSON into human-readable text:
```bash
$ ask "Read config.json" | tools file:read=config.json | answer
# [Plain text summary from the LLM]
```


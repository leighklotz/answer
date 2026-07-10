# bx

**bx** is a context-wrapping utility that executes a shell command and wraps its output within a Markdown bash code fence. It is primarily used to prepare command-line output (including error messages) for consumption by LLMs, ensuring that an agent can clearly distinguish between the intended command and the data or errors produced by that command.

## Synopsis

```bash
bx <command> [args...]
```

## Description

When a command is executed via `bx`, it transforms the raw console output into a structured Markdown block. This "LLM-ready" format prevents the model from confusing the command's intent with its resulting data or error messages.

### Execution Sequence
1.  **Fence Opening:** A Markdown code fence starting with ` ```bash ` is printed to `stdout`.
2.  **Command Echo:** The exact command and arguments passed to `bx` are printed on a new line, prefixed with a shell prompt (`$ `).
3.  **Execution:** The specified command is executed in the current environment.
4.  **Output Capture (including stderr):** Both standard output (**stdout**) and standard error (**stderr**) of the wrapped command are captured and streamed into the code fence. This ensures that LLMs can see both successful results and diagnostic error messages.
5.  **Fence Closing:** The Markdown code fence is closed with ` ``` `.

## Pipeline Role

In the Answer framework, `bx` serves as a **Context Provider**. While `ask` manages the conversation state, `bx` provides the ground-truth system state from your terminal. 

**Typical Pattern:**
`bx <system-command> | ask "Analyze this"`

This pattern allows the LLM to see exactly what command was run and how it responded (including errors), which is critical for automated debugging, log analysis, or verifying hardware status within a pipeline.

## Exit Code

`bx` is transparent regarding execution success. It captures the exit status of the wrapped command and returns it as its own exit code. This ensures that error propagation remains intact when `bx` is used within larger shell pipelines or scripts (e.g., `bx command || handle_error`).

## Examples

**1. Basic Command Execution**
Transforming a standard directory listing into a structured Markdown block:
```bash
$ bx ls -la
```
**Output:**
```bash
$ ls -la
total 16
drwxr-xr-x  3 user user 4096 Oct 25 10:00 .
drwxr-xr-x  2 user user 4096 Oct 25 09:00 ..
```

**2. Capturing Errors for LLM Analysis**
If a command fails, the error message is captured within the fence so an LLM can diagnose it in a pipeline:
```bash
$ bx non_existent_command
```
**Output:**
```bash
$ non_existent_command
/bin/bash: line 1: non_existent_command: command not found
```

**3. Preparing Input for an LLM Pipeline**
Using `bx` to provide structured system context to a subsequent `ask` query:
```bash
# The output is injected into the pipeline as part of the prompt's context
bx dmesg | ask "Are there any critical hardware errors in these logs?" | answer
```

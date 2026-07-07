# bx

**bx** is a context-wrapping utility that executes a shell command and wraps its output within a Markdown bash code fence. It is primarily used to prepare command-line output for consumption by LLMs, ensuring that the agent can clearly distinguish between the command being executed and the data produced by that command.

## Synopsis

```bash
bx <command> [args...]
```

## Description

When a command is executed via `bx`, it transforms the raw console output into a structured Markdown block. This "LLM-ready" format prevents the model from confusing the command's intent with its resulting data.

### Execution Sequence
1.  **Fence Opening:** A Markdown code fence starting with ` ```bash ` is printed to `stdout`.
2.  **Command Echo:** The exact command and arguments passed to `bx` are printed on a new line, prefixed with a shell prompt (`$ `).
3.  **Execution:** The specified command is executed in the current environment.
4.  **Output Capture:** The command's standard output is streamed directly into the code fence.
5.  **Fence Closing:** The Markdown code fence is closed with ` ``` `.

## Pipeline Role

In the Answer framework, `bx` serves as the **Context Provider**. While `ask` manages the conversation state, `bx` provides the ground-truth system state. 

**Typical Pattern:**
`bx <system-command> | ask "Analyze this" | answer`

This pattern allows the LLM to see exactly what command was run to produce the context, which is critical for debugging and verification.

## Exit Code

`bx` is transparent regarding execution success. It captures the exit status of the wrapped command and returns it as its own exit code. This ensures that error propagation remains intact when `bx` is used within larger shell pipelines or scripts (e.g., `bx command || handle_error`).

## Examples

**1. Basic command execution**
Transforming a standard command into a structured Markdown block for documentation or logs:
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

**2. Preparing input for an LLM pipeline**
Using `bx` to provide structured system context to an `ask` query:
```bash
bx dmesg | ask "Are there any hardware errors?" | answer
```

**3. Error propagation**
If the wrapped command fails, `bx` returns the non-zero exit status:
```bash
$ bx non_existent_command
```
**Output:**
```bash
$ non_existent_command
/bin/bash: line 1: non_existent_command: command not found
```


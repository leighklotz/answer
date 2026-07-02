# bx

**bx** is a utility that executes a shell command and wraps its output within a Markdown bash code fence. It is designed to prepare command-line output for consumption by LLMs (to provide structured context) or for clean visual documentation.

## Synopsis

```bash
bx <command> [args...]
```

## Description

When a command is executed via `bx`, the following sequence occurs:
1.  A Markdown code fence starting with ` ```bash ` is opened.
2.  A "prompt" line containing the command you called, prefixed with `$ `, is printed inside the fence.
3.  The specified command is executed.
4.  The command's standard output is printed inside the code fence.
5.  The Markdown code fence is closed with ` ``` `.

This makes the output "LLM-ready," allowing agents to clearly distinguish between the command being run and the data produced by that command.

## Exit Code

`bx` preserves the exit status of the wrapped command. If the executed command fails (returns a non-zero exit code), `bx` will exit with that same code. This ensures that error propagation remains intact when `bx` is used within a larger shell pipeline.

## Examples

**1. Basic command execution**
Transforming a standard command into a structured Markdown block:
```bash
$ bx ls -la
```
**Output:**
```bash
$ ls -la
total 16
drwxr-xr-x  3 user user 4096 Oct 25 10:00 .
drwxr-xr-x  2 user user 4096 Oct 25 09:00 ..
...
```

**2. Preparing input for an LLM pipeline**
Using `bx` to format the output of a system command before passing it to `ask`:
```bash
bx dmesg | ask "Are there any hardware errors?" | answer
```

**3. Error propagation**
If the command fails, the exit code is preserved:
```bash
$ bx non_existent_command
```
**Output:**
```bash
$ non_existent_command
/bin/bash: line 1: non_existent_command: command not found
```
*(The exit status of this command will be non-zero)*



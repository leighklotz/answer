# Agent Capabilities: Hallux Toolchain Assistant

## 1. BEING Hallux
*This section defines the identity, internal logic, and operational constraints of the Hallux agent.*

You are an instance of the **Hallux** assistant, a shell-based agent designed to operate as part of a Unix pipeline. Your primary mode of interaction is through standard input (`stdin`) and standard output (`stdout`), using conversation JSON for conversation history or plain text for human/tool consumption.

### Interaction Paradigms
*   **Interactive Mode:** When running in a TTY, you respond with human-readable plain text and provide real-time status via `stderr` emojis (✨ for inference, 🔯 for cache hits).
*   **Pipeline Mode (JSON History):** If the input starts with a "magic header" (`Content-Type: application/x-llm-history+json`), you receive a full JSON array of previous turns. You should append your response as a new `assistant` message and return the updated history in JSON format to maintain context for subsequent commands.
*   **Observation Mode:** When `--tee` (or `-t`) is used, you provide human-readable previews on `stderr`, but pass pristine structured data through `stdout`.

### Specialized Capabilities & Patterns
**Code Extraction & Execution (`unfence`)**
Users frequently use `| unfence | [interpreter]` to execute code you generate. To facilitate this:
*   **Use Markdown Fences:** Always wrap code in appropriate language blocks (e.g., \`\`\`python, \`\`\`bash). 
*   **Precision is Key:** If requested for a specific script, include a preamble if necessary to communicate something important, but avoid boilerplate such as "Here is your code..."; ensure `unfence` can clearly identify the code fence.

**Data Classification and Scoring (`decide`)**
You have access to the `/systemone` API capability (via `decide schema.json`) to transform unstructured CLI output into decisions results as structured JSON objects based on a schema provided by the user. This is used to obtain binary and multi-label classifications with confidence scores based on inputs.

### Knowledge Grounding & Provenance
*   **Workspace Context:** You are typically operating within an environment where `.hallux/.bash_history` and `.hallux/.cache/` store your request/ response history locally, the latter to ensure speed and consistency in multi-turn pipelines.
*   **Provenance Tracking:** The `hx provenance add [mode]` command allows users to "bookmark" successful terminal interactions into Git metadata, creating a permanent record of the context that led to a specific answer.

Important: Do not use tools to read or write the contents of the `.hallux/` directory unless explicitly prompted to do so.

---

## 2. USING Hallux
*This section serves as the user manual for installation, command reference, and pipeline integration.*

### Command Reference

| Command | Primary Purpose | Main Args | Input Type | Output Type (stdout) |
| :--- | :--- | :--- | :--- | :--- |
| `ask` | Starts or continues conversation with history and context. | Everything after flags is start of prompt. | JSON History, or context appended to prompt | **JSON** (in a pipe); **Auto-Answer Text** (if stdout is terminal or `--answer`) |
| `help` | Quick single-shot technical Q&A; brevity-focused system message | Same as `ask` | Same as `ask` | Same as `ask` |
| `decide` | Decision model; answers structured questions via schema | A schema | Same as `ask` | JSON result or markdown report |
| `answer` | Resolves the response for `ask` | `-t`, `-m` | Output of `ask` | JSON result or markdown report |
| `unfence` | Code fence content extractor | Fence type (bash, python, etc.) | Conversation JSON OR Raw Text containing fences | **Raw Code Content** only (stripped of all explanations) |
| `hx <args>` | Meta-tool for managing Hallux and session data | `what`, `why`, `provenance`, `model`, etc. | Clear cache, change model, list responses, etc. | — |

For further documentation on both bash CLI commands and and bash `hx ...` management commmands, see [doc/commands](doc/commands/*.md).

### Context Ingestion & Data Tools
You can be provided with complex system or file contexts using the following utilities:
*   **`lx <files>`: ** Streams multiple files into your input, wrapping them in Markdown code blocks with language tags and filenames. This is how the user gives you context documents in a pipeline. LX format has a simple '# file <filename>' header followed by quad-backquoted content and ending with a triple dash.
*   **`bx <command>`** Executes a shell command and outputs a structured Markdown block containing both the original prompt (`$ cmd`) and the stdout/stderr. This is for adding command output as context.
*   **`systype`:** Provides metadata about the current operating system, kernel, and hardware specs (CPU/RAM) in a machine-readable format for grounding your reasoning.

### Sourcing & Script Integration
The Hallux toolchain is **not** a set of installed binaries. All commands are **shell functions and wrapper scripts** that must be loaded into your current shell's namespace. The single entry point for this is:

```
bin/commands/hx-bootstrap.sh
```
This file **must be sourced**, never executed.

#### CLI (Interactive Shell)
Add one line to your `~/.bashrc` (or `~/.profile`):
```bash
source /path/to/hallux/bin/commands/hx-bootstrap.sh
```
First time only: restart the terminal (or `source ~/.bashrc`). 

From then on, activate the session per-project with `hx` (a shortcut for `hx enable`).

```bash
$ hx enable
👣 hallux: model=gemma-4-26b-qat-batch root=~/proj/.hallux hist=…/bash_history
$ ask "briefly, how do I strip a file extension in bash?"
✨
Use parameter expansion: `${var%.*}` removes the shortest `.*` suffix.
```
`hx enable` does three things in one call:
1. Prepends the toolchain's `bin/commands/` directory to `$PATH`.
2. Sources project-level env overrides (`bin/commands/env.sh`) so `$HX_MODEL`, `VIA_API_CHAT_BASE`, and `OPENAI_API_KEY` are set.
3. Sets `$PS1` to include the `👣` indicator so you can see the harness is active.

#### Script (Non-Interactive / CI)
Inside a `.sh` or Makefile target, source the bootstrap and enable the core environment with `hx core` **before** calling any Hallux command:

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Load the toolchain into this shell's namespace
source /path/to/hallux/bin/commands/hx-bootstrap.sh
hx core

# 2. Plain-text one-shot (non-TTY → ask emits JSON, so pipe through answer)
result="$(ask "Write a one-line awk to sum column 2 of a CSV" | answer)"

# 3. Multi-turn pipeline, terminated by answer for plain text
ask "Write a bash script that lists files over 10 MB" \
    | ask "Add error handling and a --verbose flag" \
    | unfence bash

# 4. File-ingestion context inside a script
# answer is needed because stdout is not a TTY
lx src/*.py | help "Find unused imports" | answer > report.txt
```

**Key script gotchas:**

| Situation | What to do |
|---|---|
| You need **plain text** from `ask`/`help` in a script (non-TTY, not output directly to TTY) | Pipe through `\| answer` before consuming results. Without `answer`, stdout is the full JSON conversation array if, stdout is not a tty. |
| You need the **JSON history** for further piping or storage | Do **not** pipe through `answer`. |
| Redirecting to a file | `ask "write code" \| answer > out.txt` — omitting `answer` writes the JSON blob instead. |
| Calling `hx core` in a script that already has a custom `PATH` | It is idempotent; it only prepends the commands directory if not already present. |

### Minimal Sourcing Checklist

| What to source / run | Why |
| -------------------- | --- |
|source …/hx-bootstrap.sh |      Defines the `hx` function + all command wrappers in the current shell. |
|hx core (scripts/CI) |Sets $PATH, loads env.sh. No PS1 in non-TTY. |
|hx enable (interactive) |Also configures PS1, bash history, git workdirs. |
|ask / help / answer / etc. |Now resolvable as shell functions. |

+### Environment Overrides
Project-level environment overrides are managed in config file `bin/commands/env.sh` (copied from `env.sh.sample`), where variables such as `$HX_MODEL`, `VIA_API_CHAT_BASE`, and `OPENAI_API_KEY` are defined.

---

## 3. EXTENDING Hallux
*This section describes the underlying architecture and source locations for developers and maintainers.*

### Source Locations
Most Hallux CLI commands are implemented directly in `bin/${cmd}.sh` but some are implemented in bash functions and scripts defined in:
*   `bin/commands/hx-bootstrap.sh`
*   `bin/commands/hx.sh`
*   `bin/commands/${hx_cmd}.sh`

See documentation in `doc/` and `doc/commands/*.md'.

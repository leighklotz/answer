# makedoc

**`makedoc`** is a documentation orchestration utility that uses an LLM-driven pipeline to generate or update Markdown usage documents for commands within this suite. It aggregates source code, project context, and existing documentation into a single bundle, then processes it through the Answer toolchain (`lx`, `ask`, `answer`) to produce human-readable guides in `doc/commands/`.

It is not a static parser; rather, it uses LLM reasoning to interpret implementation logic.

## Usage

Run the script from the project root:

```bash
# Generate or update documentation for all default commands
makedoc

# Process only specific selected commands
makedoc command_name1 command_name2 ...
```

### Default Commands
If no arguments are provided, `makedoc` processes the following set:
`answer`, `ask`, `bx`, `dreck`, `gx`, `help-commit`, `help`, `hx`, `lx`, `makedoc`, `systype`, `tools`, and `unfence`.

## How It Works

### 1. Source Discovery
For every requested command, the script locates its implementation file in this order:
1. `${SCRIPT_DIR}/${cmd}.sh`
2. `${SCRIPT_DIR}/commands/${cmd}.sh`

If no source file is found for a specified command, the process terminates with an error.

### 2. Context Construction & Logic Modes
The script builds a context bundle based on whether it is creating a new document or updating an existing one:

* **New Creation:** If `doc/commands/${cmd}.md` does **not** exist, the script uses a "Create Prompt" to instruct the LLM to write documentation from scratch using the source file and global project context.
* **Update Mode:** If `doc/commands/${cmd}.md` **already exists**, the script uses an "Update Prompt." This instructs the LLM to perform minimal, non-editorial changes focused strictly on aligning the docs with implementation updates in the source code.

**The Context Bundle includes:**
* Any files specified via the `$MAKEDOC_PREREADING` environment variable.
* The identified command's source file.
* **Global Project Context:** `README.md`, `tests/story-test.sh`, all existing documents in `doc/commands/*.md`, `bin/logging.sh`, `bin/commands/hx-bootstrap.sh`, `bin/commands/hx.sh`, and `bin/functions.sh`.

### 3. The AI Pipeline
The generation follows a specific data pipeline:  
`lx (Context Loader)` $\rightarrow$ `ask (Prompting Engine)` $\rightarrow$ `answer (Response Handler)` $\rightarrow$ `_strip_markdown_fence (Sanitization)`.

This ensures the output is raw Markdown, stripped of any conversational LLM "wrapper" text or markdown code fences. The pipeline executes: 
`lx ... | ask "..." | answer | _strip_markdown_fence`

### 4. Output and Verification
* **New Files:** Saved directly to `doc/commands/${cmd}.md`.
* **Updates:** Written to a temporary file: `doc/commands/${cmd}.md.new`. This allows for manual review before overwriting the original. Remove or rename the `.new` file to replace the published doc after verification.
* **Idempotency:** If no substantive changes are detected during an update, the script outputs `=` and leaves existing files untouched.
* **Diffing:** If `diffstat` is installed on your system, the script prints a summary of changes between old and new versions to `stdout`.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `MAKEDOC_PREREADING` | (Optional) A space-separated list of additional files to be prepended to the context bundle for every command. |

## Requirements & Environment
The following must be present in your shell environment:
* **Project Setup:** Valid `./bin/env.sh`, `logging.sh`, and `functions.sh`.
* **AI Toolchain:** Access to the `lx`, `ask`, and `answer` utilities.

## Examples

**Process the default set**
```bash
$ makedoc
CMDS=answer ask bx dreck help-commit help hx lx makedoc systype tools unfence
MAKEDOC_PREREADING=
cmd=answer->.../bin/answer.sh
...
```

**Add extra pre-reading context**
```bash
$ export MAKEDOC_PREREADING="doc/plan/overview.md"
$ makedoc help
```

## Errors
The script will exit with an error if:
* A required source `.sh` file cannot be located for a requested command.
* Any stage of the AI pipeline fails.
* The resulting documentation output is empty.

# hx

```bash
👣$ hx help
usage: hx model|server|load|unload|models|cache|provenance|again|why|what|cat|describe|stats|context
```

**`hx`** is the central management utility of the Answer framework. It serves as a control plane for managing your shell environment (via integration scripts), controlling data persistence through local caching, and providing rapid access to recent LLM interactions via specialized parsing utilities or Git-backed provenance tracking.

It operates in three distinct modes depending on how it is invoked: **Environment & Session Control** (top-level commands), **Interaction Provenance** (subcommands for recording history into Git metadata), or **Cache Management and Utilities** (subcommands for controlling local storage).

## Synopsis

```bash
# 1. Environment & Session/Model Commands (Top-Level)
hx [set-model | model | server | load | unload | models | cache | provenance | again]

# 2. Interaction Provenance Subcommand
hx provenance {add [mode] | show [hash] | refs | list}

# 3. Cache, Context & Server Management / Recent Interaction Utilities (why, what, etc.)
hx cache [args...]
hx context [args...]
hx server [args...]
hx [why | what | cat | describe | stats] [-]
```

---

## Description

### 1. Environment & Session Control (Top-Level)

These commands manage the active shell environment, LLM configurations, or replay recent interactions using `bx`.

| Command | Purpose | Implementation Note |
| :--- | :--- | :--- |
| **`hx enable / disable`** | **Activate/Deactivate Framework:** Integrates Answer into your current session (e.g., adding the `(👣)` icon to `$PS1`). *Note: Typically used via bootstrap.* | Sources integration scripts and modifies environment/path. |
| **`hx set-model [args]`** | **Set Session Model:** Quickly updates your current session's `$HX_MODEL` environment variable using a specific model string or configuration. | Calls `model.sh`, captures output, and prints it. |
| **`hx model / load / unload`** | **Model Management:** Configures API endpoints, switches models, or manages loaded LLM contexts. | Calls `model.sh`. |
| **`hx models [args]`** | **Model List/Management:** Lists and manages available AI model endpoints in the system configuration. | Calls `models.sh`. |
| **`hx again`** | **Replay Previous Command:** Re-runs your last command automatically wrapped with `bx`, allowing for immediate follow-up queries. | Executes `_hx_again`. |

### 2. Interaction Provenance (`hx provenance ...`)
Leveraging Git notes (using the `provenance/hallux` reference), this subcommand allows you to "bookmark" your terminal interactions, creating an auditable trail of command history and LLM responses directly within a repository's metadata without altering the actual git log itself.

| Subcommand | Description | Behavior / Output |
| :--- | :--- | :--- |
| **`add [mode]`** | **Capture State:** Captures your last executed shell command, its context (prompt/history), and response into Git notes. Modes define the emoji and MIME type used to tag the data. | Stores structured content as a Git note via specialized headers. |
| **`show [hash]`** | **View Note:** Instantly displays the full content of a specific provenance entry by its hash using standard Git notes output. | `git notes --ref=provenance/hallux show "$2"`. |
| **`refs`** | **List Hashes:** Scans your repository to list all available hashes associated with the `provenance/hallux` reference. | `git notes --ref=provenance/hallux list`. |
| **`list`** | **Chronological Timeline:** Provides a colorized, decorated history showing recent Git log lines paired with short text previews from stored responses. | Human-readable audit trail (Log line + Preview). |

#### `add` Subcommand Modes
When using `hx provenance add`, you can specify how the captured interaction is tagged:

| Mode | Emoji | Description / Use Case |
| :--- | :--- | :--- |
| **`what`** | 💭 | Captures as a standard text response. |
| **`why`** | 🧠 | Captures specifically as a reasoning/thinking trace. |
| **`response`** | `➡️` | Marks the interaction explicitly as an LLM/tool response JSON payload. |
| **`describe`** | 📜 | Records context as a plain-text descriptive note. |
| **`-`** (dash) | `\|` | Reads content directly from `stdin`. Use this to pipe raw text or manual input into the provenance log without running an automatic command capture. |

### 3. Cache & Context Management / Interaction Utilities (`hx cache`, `hx context`, etc.)
The framework uses local JSON files for caching and provides utilities to inspect these cached interactions immediately. It also provides access to specialized management scripts for servers, contexts, and caches.

**Management:**
* **`hx cache [args]`**: Manage storage settings (e.g., `clear`, `show`, `enable/disable`). Calls `cache.sh`.
* **`hx context [args]`**: Manage context via `context.sh`.
* **`hx server [args]`**: Interact with the specialized server implementation.

**Interaction Inspection (Operates on the most recent interaction or piped stdin):**
If a local cache exists, these commands extract specific components from your latest interaction. Alternatively, pass `-` as the sole argument to read from `stdin` instead of the latest [cache] via the sub-script defaults.

| Command | Description | Output Type |
| :--- | :--- | :--- |
| **`hx why`** | Extracts and displays model "thinking" or reasoning blocks (🧠) from your most recent cached interaction. | Reasoning text/trace. |
| **`hx what`** | Parses and formats the raw content of your most recent cached interaction for clean terminal viewing. | Formatted plain text response. |
| **`hx cat`** | Passes the structured JSON data of the latest cache entry directly to a processing script (e.g., `cat.sh`). | Raw/Processed JSON stream. |
| **`hx describe`** | Generates a formatted Markdown summary of the most recent interaction, including conversation and model metrics. | Formatted Markdown summary. |
| **`hx stats`** | Provides usage statistics focusing on metadata (tokens, latency) from the latest interaction. | Metadata/Statistics text. |

---

## Examples

### Session Control & Replay
```bash
# Update your session's active model to use a specific checkpoint or provider
$ hx set-model "gpt-4o"

# Run exactly what you just typed, but wrapped in 'bx' context for the LLM
$ hx again
```

### Recording and Auditing History (Provenance)
```bash
# Capture your last command and its AI response as a text note
$ hx provenance add what

# View your timeline of recorded interactions to find an old answer
$ hx provenance list

# Inspect the exact Git note for a specific interaction hash
$ hx provenance show 7a2f1b3...
```

### Extracting Recent Context (from Cache)
These commands are useful when you want to quickly re-examine or pipe your last AI response without re-running the prompt.
```bash
# See what your model was "thinking" in its last interaction
$ hx why

# Pipe the text of your last answer into a file
$ hx what > latest_answer.txt

# View performance metrics for your most recent query (tokens used, etc.)
$ hx stats

# Provide a specific cache file via stdin instead of the latest
$ cat some_cache.json | hx what -

# Note:
Some commands are provided by the `hx` function in `bin/commands/hx-bootstrap.sh`, while others call specialized scripts (like `model.sh`, `models.sh`, or `${cmd}.sh`) via the main `bin/commands/hx.sh` entry point.

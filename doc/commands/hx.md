# hx

**`hx`** is the central management utility of the Answer framework. It serves as a control plane for managing your shell environment (via integration scripts), controlling data persistence through local caching, and providing rapid access to recent LLM interactions via specialized parsing utilities or Git-backed provenance tracking.

It operates in three distinct modes depending on how it is invoked: **Environment Integration** (top-level commands), **Interaction Provenance** (subcommands for recording history into Git metadata), or **Cache Management** (subcommands for controlling local storage).

## Synopsis

```bash
# 1. Environment & Core Commands (Top-Level)
hx [enable | disable | again | why | what | cat | describe | stats | model | set-model | models]

# 2. Interaction Provenance Subcommand
hx provenance {add [what|why|response|describe|-] | show [hash] | refs | list}

# 3. Local Cache Management Subcommand
hx cache {clear | show | enable | disable}
```

---

## Description

### 1. Core Command Interface (Top-Level)

These commands manage the active shell environment or provide specialized extraction of your most recent AI interactions stored in the local cache by executing specific command scripts on the latest interaction file.

| Command | Purpose | Implementation Note |
| :--- | :--- | :--- |
| **`hx enable`** | **Activate Framework:** Integrates Answer into your current session, adding a `(🦶)` icon to your `$PS1`. | Sources `~/wip/answer/bin/commands/enable`. |
| **`hx disable`** | **Deactivate Framework:** Removes command aliases/environment changes for the current session. | Sources `~/wip/answer/bin/commands/disable`. |
| **`hx again`** | **Replay Previous Command:** Executes the previous bash command line again, but through bx with stderr redirected. | Calls `_hx_again`. |
| **`hx why`** | **Reasoning Analysis:** Extracts and displays model "thinking" or reasoning blocks (🧠) from your most recent cached interaction. | `cat "$latest" \| ~/wip/answer/bin/commands/why.sh`. |
| **`hx what`** | **Text Extraction:** Parses and formats the raw content of your most recent cached interaction for clean terminal viewing. | `cat "$latest" \| ~/wip/answer/bin/commands/what.sh`. |
| **`hx cat`** | **Raw Dump:** Passes the structured JSON data of the latest cache entry directly to a processing script for inspection. | `cat "$latest" \| ~/wip/answer/bin/commands/cat.sh`. |
| **`hx describe`** | **Summary Generation:** Generates a formatted Markdown summary of the most recent interaction, including conversation and model metrics. | `cat "$latest" \| ~/wip/answer/bin/commands/describe.sh`. |
| **`hx stats`** | **Usage Statistics:** Provides a streamlined view focusing exclusively on metadata and token usage statistics from the latest interaction. | `cat "$latest" \| ~/wip/answer/bin/commands/stats.sh`. |
| **`hx model [args]`** | **Model Config:** Launches the configuration interface for API endpoints and model preferences. | Calls `~/wip/answer/bin/commands/model.sh`. |
| **`hx set-model [args]`** | **Set Session Model:** Updates your current session's `$HX_MODEL` environment variable to a specific value. | Sets exported `HX_MODEL` via `model.sh`. |
| **`hx models [args]`** | **Model List:** Runs logic to list or manage available AI model endpoints. | Calls `~/wip/answer/bin/commands/models.sh`. |

### 2. Provenance (`hx provenance ...`)
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
| **`response`** |↩️️ | Marks the interaction explicitly as an LLM/tool response JSON payload. |
| **`describe`** | 📜 | Records context as a plain-text descriptive note. |
| **`-`** (dash) | ➡️ | Reads content directly from `stdin`. Use this to pipe raw text or manual input into the provenance log without running an automatic command capture. |

### 3. Cache Management (`hx cache ...`)
The framework uses local JSON files for caching to ensure speed and reduce API costs. Use these commands to manage your storage or toggle session behavior via environment variables.

| Subcommand | Description | Behavior / Output |
| :--- | :--- | :--- |
| **`clear`** | **Wipe Cache:** Deletes all `.json` files in the local cache directory (e.g., `~/.config/hallux/cache`). Includes an interactive confirmation prompt (`y/N`). | Interactive deletion of history. |
| **`show`** | **Locate Directory:** Prints the absolute filesystem path to your active, current workspace's cache folder. | Path string via `_find_cache_dir`. |
| **`disable`** | **Toggle Caching (OFF):** Sets `HX_NO_CACHE=1`, preventing new queries from being saved for this session. | Session-wide variable update. |
| **`enable`** | **Toggle Caching (ON):** Unsets `HX_NO_CACHE`, restoring automated caching functionality for the current shell session. | Session-wide variable update. |

---

## Examples

### Environment Setup & Session Control
```bash
# Activate framework integration in current shell
$ hx enable

# Set your active model for the current session (e.g., gpt-4o)
$ hx set-model "gpt-4o"

# Disable automated caching for this specific terminal window only
$ hx cache disable

# Replay previous command through bx
$ hx again
```

### Recording and Auditing History
```bash
# Capture the last command you ran and its AI response into git provenance/hallux notes (text mode)
$ hx provenance add what

# Capture the reasoning trace of the last interaction as a thinking block
$ hx provenance add why

# View a beautiful, colorized timeline of your past interactions in this repository
$ hx provenance list

# Inspect a specific interaction from that timeline using its hash
$ hx provenance show <hash>
```

### Extracting Recent Context
```bash
# Get a clean text version of the last thing you asked/received via 'what' logic
$ hx what > .hallux/last-interaction.md

# See what your model was "thinking" in its last response using reasoning extraction
$ hx why

# View usage statistics (tokens, latency) for your most recent query
$ hx stats

# Get a markdown description of the last chat interaction, including metadata and metrics
$ hx describe
```

# hx

**`hx`** is the central management utility of the Answer framework. It serves as a control plane for managing your shell environment (via integration scripts), controlling data persistence through local caching, and providing rapid access to recent LLM interactions via specialized parsing utilities or Git-backed provenance tracking.

It operates in three distinct modes depending on how it is invoked: **Environment Integration** (top-level commands), **Interaction Provenance** (subcommands for recording history into Git metadata), or **Cache Management** (subcommands for controlling local storage).

## Synopsis

```bash
# 1. Environment & Core Commands (Top-Level)
hx [enable | disable | why | what | cat | model | set-model | models]

# 2. Interaction Provenance Subcommand
hx provenance {add [what|why|cat|describe] | show [hash] | refs | list}

# 3. Local Cache Management Subcommand
hx cache {clear | show | enable | disable}
```

---

## Description

### 1. Core Command Interface (Top-Level)

These commands manage the active shell environment or provide specialized extraction of your most recent AI interactions stored in the local cache.

| Command | Purpose | Implementation Note |
| :--- | :--- | :--- |
| **`hx enable`** | **Activate Framework:** Integrates Answer into your current session by sourcing configuration scripts and adding the Hallux icon (🦶) to your `$PS1`. | Sources `~/wip/answer/bin/commands/enable` |
| **`hx disable`** | **Deactivate Framework:** Removes command aliases from your PATH for the current session. | Sources `~/wip/answer/bin/commands/disable` |
| **`hx why`** | **Reasoning Analysis:** Extracts and displays model "thinking" or reasoning blocks (🧠) from the latest cache entry via a processing script. | Uses `.../command/why.sh` on latest JSON |
| **`hx what`** | **Text Extraction:** Parses and formats the raw content of your most recent cached interaction for clean terminal viewing. | Uses `.../command/what.sh` on latest JSON |
| **`hx cat`** | **Raw Dump:** Passes the structured JSON data of the latest cache entry to a processing script for inspection. | Uses `.../command/cat.sh` on latest JSON |
| **`hx describe`** | **Summary Generation:** Generates a beautifully formatted Markdown summary of the most recent interaction, including conversation and model metrics. | Calls `describe.sh` on latest cache file |
| **`hx stats`** | **Usage Statistics:** Provides a streamlined view focusing exclusively on metadata and token usage statistics from the latest interaction. | Calls `stats.sh` on latest cache file |
| **`hx model [args]`** | **Model Config:** Launches the model management interface (configures endpoints and preferences). | Calls `model.sh` |
| **`hx set-model [args]`** | **Set Session Model:** Sets your current session's `$HX_MODEL` environment variable via a configuration script. | Exports `$HX_MODEL` for current shell |
| **`hx models [args]`** | **Model List:** Runs specialized logic to list, filter, or manage available AI models. | Calls `models.sh` |

### 2. Provenance (`hx provenance ...`)
Leveraging Git notes (using the `provenance/hallux` reference), this subcommand allows you to "bookmark" your terminal interactions, creating an auditable trail of command history and LLM responses directly within a repository's metadata without altering the git log itself.

| Subcommand | Description | Behavior / Output |
| :--- | :--- | :--- |
| **`add [mode]`** | **Capture State:** Captures your last executed shell command, its context, and the response into Git notes. Modes (`what`, `why`, etc.) define how data is tagged/categorized in history. | Stores structured content as a Git note using specialized MIME types. |
| **`show [hash]`** | **View Note:** Instantly displays the full content of a specific provenance entry by its hash or ref via standard Git notes output. | Standard Git notes output. |
| **`refs`** | **List Hashes:** Scans your repository to list all available hashes associated with the `provenance/hallux` reference. | List of unique Git note hashes. |
| **`list`** | **Chronological Timeline:** Provides a colorized, decorated history showing Git log lines paired with short text previews from the stored AI responses. | A human-readable audit trail (Log line + Preview). |

### 3. Cache Management (`hx cache ...`)
The framework uses local JSON files for caching to ensure speed and reduce API costs. Use these commands to manage your storage or toggle session behavior via environment variables.

| Subcommand | Description | Behavior / Output |
| :--- | :--- | :--- |
| **`clear`** | **Wipe Cache:** Deletes all `.json` files in the local cache directory (e.g., `~/.config/hallux/cache`). Includes an interactive confirmation prompt (`y/N`). | Interactive deletion of history. |
| **`show`** | **Locate Directory:** Prints the absolute filesystem path to your active cache folder. | Path string via `_find_cache_dir`. |
| **`disable`** | **Toggle Caching (OFF):** Sets `HX_NO_CACHE=1`, preventing new queries from being saved for this session. | Session-wide variable update. |
| **`enable`** | **Toggle Caching (ON):** Unsets `HX_NO_CACHE`, restoring automated caching functionality. | Session-wide variable update. |

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
```

### Recording and Auditing History
```bash
# Capture the last command you ran and its AI response into git provenance/hallux notes
$ hx provenance add what

# Capture the reasoning trace of the last command you ran and its AI response into git provenance/hallux notes
$ hx provenance add why

# Capture the conversation JSON of the last command you ran and its AI response into git provenance/hallux notes
$ hx provenance add cat

# View a beautiful, colorized timeline of your past interactions in this repository
$ hx provenance list

# Inspect a specific interaction from that timeline (using hash)
$ git log --show-signature # or use hx refs to find the hash first
$ hx provenance show <hash>
```

### Extracting Recent Context
```bash
# Get a clean text version of the last thing you asked/received
$ hx what > .hallux/bug-14-fix-1.md

# See what your model was "thinking" in its last response
$ hx why

# View usage statistics (tokens, latency) for your most recent query
$ hx stats

# See a markdown description of the last chat response, including `hx stats` and `hx why` and `hx what`
$ hx describe

```

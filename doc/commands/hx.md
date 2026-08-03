# hx

**`hx`** is the central management utility of the Answer framework. It serves as a control plane for managing your shell environment, controlling data persistence (caching), recovering historical interactions through Git-backed provenance, and providing rapid access to recent LLM outputs via specialized parsing utilities.

It operates in three distinct modes depending on the first argument provided: **Environment Integration** (top-level commands), **Interaction Provenance** (subcommands for recording history), or **Cache Management** (subcommands for controlling data storage).

## Synopsis

```bash
# 1. Environment & Core Commands
hx [enable | disable | why | what | cat | model | models]

# 2. Git-backed Interaction History
hx provenance {add | show [hash] | refs | list}

# 3. Local Cache Management
hx cache {clear | show | enable | disable | drop}
```

---

## Description

### 1. Core Command Interface (Top-Level)
These commands manage the active shell environment or provide specialized extraction of your most recent AI interactions.

| Command | Purpose | Implementation Detail |
| :--- | :--- | :--- |
| **`hx enable`** | **Activate Framework:** Integrates Answer into your current session by sourcing configuration scripts and adding the Hallux icon (🦶) to your `$PS1`. | Sources `/bin/commands/enable` |
| **`hx disable`** | **Deactivate Framework:** Removes command aliases from your `PATH` for the current session. | Sources `/bin/commands/disable` |
| **`hx why`** | **Reasoning Analysis:** Pipes the latest cache entry into a specialized script to display model "thinking" or reasoning blocks (🧠). | via `why.sh` |
| **`hx what`** | **Text Extraction:** Parses and formats the raw content of your most recent cached interaction for clean terminal viewing. | via `what.sh` |
| **`hx cat`** | **Raw Dump:** Passes the latest cache JSON through a script to output it in its structured format. | via `cat.sh` |
| **`hx model`** | **Model Config:** Launches the model management interface for configuring LLM endpoints and preferences. | `/bin/commands/model.sh` |
| **`hx models`** | **Model List:** Runs specialized logic to list or manage available AI models. | `/bin/commands/models.sh` |

### 2. Provenance (`hx provenance ...`)
Leveraging Git notes (using the `provenance/hallux` reference), this subcommand allows you to "bookmark" your terminal interactions, creating an auditable trail of command history and LLM responses directly within a repository's metadata.

| Subcommand | Description | Behavior / Output |
| :--- | :--- | :--- |
| **`add`** | **Capture State:** Automatically grabs the last executed shell command (`fc`) and current prompt context, then appends the resulting AI response as a structured Git note. | Captures `prompt + command + AI result`. |
| **`show [hash]`** | **View Note:** Instantly displays the content of a specific provenance entry by its hash or ref. | Standard Git notes output. |
| **`refs`** | **List Hashes:** Scans your repository to list all available hashes associated with the `provenance/hallux` reference. | List of unique Git note hashes. |
| **`list`** | **Chronological Timeline:** Provides a colorized, decorated history showing Git log lines paired with short text previews from the stored AI responses. | A human-readable audit trail. |

### 3. Cache Management (`hx cache ...`)
The framework uses local JSON files for caching to ensure speed and reduce API costs. Use these commands to manage your storage or toggle session behavior. Note that `enable/disable` here controls **automated** caching for the current shell session only via environment variables.

| Subcommand | Description | Behavior / Output |
| :--- | :--- | :--- |
| **`clear`** | **Wipe Cache:** Deletes all `.json` files in your local cache directory (e.g., `~/.config/hallux/cache`). Includes an interactive confirmation prompt (`y/N`). | Interactive deletion of history. |
| **`show`** | **Locate Directory:** Prints the absolute filesystem path to your active cache folder. | Path string via `_find_cache_dir`. |
| **`disable`** | **Toggle Caching (OFF):** Sets `NO_CACHE=1`, preventing new queries from being saved for this session. | Session-wide variable update. |
| **`enable`** | **Toggle Caching (ON):** Unsets `NO_CACHE`, restoring automated caching functionality. | Session-wide variable update. |
| **`drop`** | **Remove Latest:** Identifies only the most recent cache entry, shows a text preview of its content for safety, and asks to delete it. | Interactive single-entry removal. |

---

## Examples

### Environment Setup
```bash
# Set up your shell with aliases and prompt icons (🦶)
$ hx enable

# Check where your AI history is actually being stored on disk
$ hx cache show
```

### Bookmarking an Interaction
If you have just performed a complex refactor using `ask` or `help`, bookmark the result:
```bash
# This captures what you typed and exactly what the AI said into Git metadata
$ hx provenance add

# Later, see your beautiful timeline of changes
$ hx provenance list
[git log line] [AI Preview...]
```

### Inspecting History Without Re-running Prompts
Instead of re-typing a prompt to see if you liked an answer, use the extraction tools:
```bash
# Quickly view what the AI's latest thought process was (if it used reasoning)
$ hx why

# Extract only the plain text content from your last interaction
$ hx what
The model's response...
```

### Cleaning Up and Troubleshooting
If you want to start a fresh session without any history or caching:
```bash
# Disable automated saving for this specific terminal window
$ hx cache disable

# Delete only the very last thing that went into your cache (with preview)
$ hx cache drop
⚠️ Are you sure you want to delete this cache entry?
File: /home/user/.config/hallux/cache/...json
>Preview of content...
Deletion cache entry? (y/N): y
```

# hx

**`hx`** is the management utility for the Answer framework, serving as the control plane for workspace configuration, cache lifecycle management, interaction recovery (via Git provenance), and environment integration. 

It allows you to manage how the toolchain handles data persistence (caching) and provides rapid access to your most recent AI responses by targeting the latest entries in your local workspace history or via structured Git notes.

## Synopsis

```bash
hx [provenance | cache] <subcommand> | hx model | hx why | hx what | hx cat | hx enable | hx disable
```

## Description

The `hx` command is divided into four functional areas: **Provenance**, **Cache Management**, **Interaction Recovery**, and **Environment Configuration**.

### Provenance (`hx provenance ...`)
Leveraging Git notes, the `provenance` subcommand allows you to "bookmark" your terminal interactions. It captures your last shell command and current prompt context, attaching them as a structured note to your repository history via `git notes`. This creates an immutable audit trail of how specific commands or conversations relate to your commit/log state.

| Subcommand | Description | Behavior / Output |
| :--- | :--- | :--- |
| **`add`** | Captures context and saves it. | Grabs the last command from shell history (`fc`) and current prompt, then appends an LLM response as a `git note` under the `provenance/hallux` ref. |
| **`show [hash]`** | View specific notes. | Displays the content of a single provenance note (optionally by hash). |
| **`refs`** | List all references. | Lists hashes associated with the tool's provenance reference. |
| **`list`** | Decorated log view. | Provides a colorized, human-readable list showing Git logs, commit messages, and a preview of the note content (the prompt/response) for every stored interaction. |

### Cache Management (`hx cache ...`)
The framework stores conversation histories in a local directory (e.g., `.hallux/cache` or `~/.config/hallux/cache`). Use these subcommands to manage that storage:

| Subcommand | Description | Behavior / Output |
| :--- | :--- | :--- |
| **`clear`** | Deletes the local cache. | Prompted for confirmation (`y/N`). If confirmed, deletes the directory and outputs `🗑️ Cache cleared.` (includes safety checks to prevent deleting `$HOME` or `/`). |
| **`show`** | Displays active path. | Prints the absolute path of the currently used cache directory. |
| **`disable`** | Session-wide bypass. | Sets `NO_CACHE=1`, preventing new queries from being saved in your current shell session. Outputs: `⚠️ Cache disabled.` |
| **`enable`** | Restore caching. | Unsets `NO_CACHE`. Outputs: `⚠️ Cache enabled.` |

### Interaction Recovery ("Last Run" Shortcuts)
These commands identify the most recent entry in your local cache and pipe it through specialized processing scripts (`why.sh`, `what.sh`, etc.) to interpret or format the last interaction.

| Command | Description | Behavior / Output |
| :--- | :--- | :--- |
| **`hx why`** | Analyze reasoning. | Pipes the latest cache entry into a script designed to extract and display "thinking"/reasoning blocks (🧠). |
| **`hx what`** | Retrieve response. | Pipes the latest cache entry into a script that extracts and displays only the assistant's final content text. |
| **`hx cat`** | Raw data dump. | Passes the raw, unprocessed JSON of the last interaction through a formatting/extraction script for inspection. |

### Environment & Model Configuration
Top-level commands to manage your active environment or interact with model settings.

| Command | Description | Behavior / Output |
| :--- | :--- | :--- |
| **`hx enable`** | Activate framework. | Sources the necessary configuration scripts for the current session and adds the Hallux icon (🦶) to your `$PS1`. |
| **`hx disable`** | Deactivate framework. | Removes command aliases from the path; shell functions remain defined in the environment but are effectively dormant. |
| **`hx model`** | Model management. | Executes a specialized script (`model.sh`) for managing available LLM models and endpoints. |

## Examples

**1. Creating a Provenance Bookmark**
Capture exactly what you just ran in your terminal to review later:
```bash
$ hx provenance add
# This captures your last command, the current prompt context, 
# and an AI analysis into a Git note.
```

**2. Inspecting Recent Work (The "List" View)**
See a beautiful timeline of everything you've asked or executed via `hx`:
```bash
$ hx provenance list
```

**3. Checking the Last Response Without Re-running**
If an LLM provided a complex explanation, instantly retrieve just the text:
```bash
🦶$ ask "Write me a bash script to find large files" ✨
... (response) ...
🦶$ hx what
5  (The assistant's response content from your last call)
```

**4. Clearing Cache with Safety Check**
If you suspect the cache is corrupted or want to start fresh:
```bash
$ hx cache clear
⚠️ Are you sure you want to remove /home/user/.config/hallux/cache? (y/N)
Delete directory? (y/N): y
🗑️ Cache cleared.
```

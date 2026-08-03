# hx

**`hx`** is the management utility for the Answer framework, serving as the control plane for workspace configuration, cache lifecycle management, interaction recovery (via Git provenance), and environment integration. 

It allows you to manage how the toolchain handles data persistence (caching) and provides rapid access to your most recent AI responses by targeting the latest entries in your local workspace history or via structured Git notes attached as metadata.

## Synopsis

```bash
hx [enable | disable | why | what | cat | model] 
    [provenance {add | show [hash] | refs | list}] 
    [cache {clear | show | enable | disable | drop}]
```

## Description

The `hx` command is organized into three distinct functional layers: **Environment/Interaction Recovery**, **Provenance (Git-backed Bookmarks)**, and **Cache Management**.

### 1. Environment & Interaction Recovery
These top-level commands manage your active shell session or provide instant access to the most recent LLM outputs without re-running prompts.

| Command | Description | Behavior / Output |
| :--- | :--- | :--- |
| **`hx enable`** | Activate framework. | Sources configuration scripts for the current session and adds the Hallux icon (🦶) to your `$PS1`. |
| **`hx disable`** | Deactivate framework. | Removes command aliases from your path; shell functions remain defined in the environment but are effectively dormant. |
| **`hx model`** | Model management. | Executes a specialized script for managing available LLM models and endpoints. |
| **`hx why`** | Analyze reasoning. | Pipes the latest cache entry into a script designed to extract and display "thinking"/reasoning blocks (🧠). |
| **`hx what`** | Retrieve response. | Passes the latest cache entry through `what.sh` to extract only the assistant's final content text. |
| **`hx cat`** | Raw data dump. | Passes the raw, unprocessed JSON of the last interaction to a formatting script for inspection. |

### 2. Provenance (`hx provenance ...`)
Leveraging Git notes (specifically the `provenance/hallux` ref), this subcommand allows you to "bookmark" your terminal interactions. It captures your shell history and prompt context, attaching them as structured metadata so they can be audited or reviewed alongside your repository's timeline.

| Subcommand | Description | Behavior / Output |
| :--- | :--- | :--- |
| **`add`** | Bookmark current state. | Captures the last executed command (`fc`) and prompt context, then appends the resulting AI response as a `git note`. |
| **`show [hash]`** | View specific note. | Displays the content of a single provenance note (optionally by its Git hash). |
| **`refs`** | List hashes. | Lists all available hashes associated with your local provenance references. |
| **`list`** | Decorated history view. | Provides a colorized, human-readable timeline showing Git log lines paired with short previews of the stored AI responses. |

### 3. Cache Management (`hx cache ...`)
The framework stores conversation histories in a local directory (up-path to `.hallux/cache`, then to `$HOME/.config/hallux`). Use these subcommands to manage that storage and control session behavior.

N.B.: Tool output is not cached, however subsequent pipeline element outputs are, though cache hits are not guaranteed.

| Subcommand | Description | Behavior / Output |
| :--- | :--- | :--- |
| **`clear`** | Wipe cache contents. | Prompted for confirmation (`y/N`). Deletes all `.json` files within the cache directory. |
| **`show`** | Display active path. | Prints the absolute filesystem path of your current cache directory. |
| **`disable`** | Session-wide bypass. | Sets `NO_CACHE=1`, preventing new queries from being saved for the duration of this shell session. |
| **`enable`** | Restore caching. | Unsets `NO_CACHE`. Automated caching is restored for the current session. |
| **`drop`** | Delete latest entry. | Identifies the most recent cache file, previews its content using `hx what`, and asks for confirmation before deleting only that specific file. |

## Examples

**1. Enabling Environment Setup**
Set up your shell with all necessary aliases and prompt decorations:
```bash
$ hx enable
🦶$ 
```

**2. Quickly Reviewing the Last AI Response**
If you just ran a long `ask` command, instantly see what the assistant said without re-running it:
```bash
🦶$ hx what
The model's response text...
```

**3. Creating an Audit Trail (Provenance)**
After running a complex series of commands to refactor code, bookmark your progress:
```bash
# This captures your last command and the AI output into Git notes
$ hx provenance add
```

**4. Inspecting Your History Timeline**
See a beautiful chronological list of everything you've asked or executed via `hx`:
```bash
$ hx provenance list
[git log line] [Preview of prompt/response...]
```

**5. Safely Deleting the Last Interaction**
If an LLM provides a wrong answer and you want to remove it from your cache:
```bash
$ hx cache drop
⚠️ Are you sure you want to delete this cache entry?
File: /path/to/.hallux/cache/file_name.json
>Preview of content...
Deletion cache entry? (y/N): y
🗑️ Entry dropped.
```

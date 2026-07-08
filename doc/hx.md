# hx

**`hx`** is a management utility within the Answer framework used for workspace configuration, cache lifecycle management, and rapid interaction with recent AI responses stored in the local cache. 

It serves as the control plane for managing how the toolchain handles data persistence (caching) and allows you to "re-run" or "query" previous LLM interactions without re-prompting the model by targeting the most recent entries in your workspace history.

## Synopsis

```bash
hx <subcommand> [options]
```

## Description

`hx` provides several subcommands categorized into **Cache Management**, **Environment Configuration**, and **Interaction Recovery**. 

### Cache Management (`hx cache ...`)
The Answer framework uses a local cache (located in `.hallux/cache`, `~/.config/hallux/cache`, or the user home directory) to store JSON conversation histories. This allows for instant retrieval of identical queries without hitting the API and provides a history of your interactions.

| Subcommand | Description |
| :--- | :--- |
| **`hx cache clear`** | Deletes the entire local cache directory after a manual confirmation prompt (`y/N`). Use this to ensure no previous conversation state is being reused or to reclaim disk space. |
| **`hx cache show`** | Displays the absolute path of the current active cache directory used by the framework. Useful for debugging where your interaction history is stored. |
| **`hx cache disable`** | Disables automated caching for the *current shell session* by setting `NO_CACHE=1`. This forces all subsequent queries to perform fresh API calls without storing results. |
| **`hx cache enable`** | Re-enables the automated caching mechanism for the current session (unsets `NO_CACHE`). |

### Environment Configuration
These top-level commands allow you to toggle or source specialized environment configurations and pipeline states via external configuration scripts.

| Command | Description |
| :--- | :--- |
| **`hx disable`** | Sources a command/script that disables specific Answer framework behaviors (via `commands/disable`). |
| **`hx enable`** | Sources the enablement script to restore standard pipeline behavior. |

### Interaction Recovery ("Last Run" Shortcuts)
These commands provide rapid access to your most recent AI interaction without needing to re-type prompts or manually find cache files. They identify the latest `.json` entry in the active cache and pipe it into specialized processing tools.

| Subcommand | Description | Pipeline Operation (Logic) |
| :--- | :--- | :--- |
| **`hx answer`** | Re-extracts only the plain text content of your most recent LLM response from the cache. Useful if you need to grab a script or message again without re-running the model. | `cat <latest_cache> \| answer.sh` |
| **`hx why`** | Passes the context and history of your last interaction into a reasoning tool (`why.sh`) to explain the logic behind an LLM's response. | `cat <latest_cache> \| why.sh` |
| **`hx what`** | Summarizes or expands upon the latest conversation entry in the cache using the `what.sh` utility for deeper analysis of a previous turn. | `cat <latest_cache> \| what.sh` |

## Examples

**1. Managing Local Storage and Debugging**
```bash
# Find out where my AI history is stored
$ hx cache show

# Force a fresh query by disabling the cache in this session
$ hx cache disable
⚠️ Cache disabled.

# Completely wipe all cached LLM responses
$ hx cache clear
⚠️ Are you sure you want to remove /home/user/.config/hallux/cache? (y/N)
Delete directory? (y/N): y
🗑️  Cache cleared.
```

**2. Re-examining Previous Results**
If you just ran an `ask` command and want to perform more operations on that specific response without typing it again:
```bash
# Extract the text of the last interaction for easier reading or piping
$ hx answer

# Use a specialized 'why' tool on your previous conversation context 
# (e.g., "Why did it suggest this code structure?")
$ hx why

# Summarize/Expand upon the latest result in the cache
$ hx what
```


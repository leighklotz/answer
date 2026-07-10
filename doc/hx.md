# hx

**`hx`** is the management utility for the Answer framework, serving as the control plane for workspace configuration, cache lifecycle management, and interaction recovery. 

It allows you to manage how the toolchain handles data persistence (caching) and provides rapid access to your most recent AI responses by targeting the latest entries in your local workspace history.

## Synopsis

```bash
hx <subcommand> [options]
# or
hx cache <cache-subcommand>
```

## Description

The `hx` command is divided into three functional areas: **Cache Management**, **Pipeline Configuration**, and **Interaction Recovery**.

### Cache Management (`hx cache ...`)
To ensure predictable data loops, the framework stores conversation histories in a local cache (found in `.hallux/cache`, `~/.config/hallux/cache`, or your home directory). Use these subcommands to manage that storage:

| Subcommand | Description | Behavior / Output |
| :--- | :--- | :--- |
| **`hx cache clear`** | Deletes the entire local cache. | Prompted for confirmation (`y/N`). If confirmed, deletes the directory and outputs `🗑️ Cache cleared.` |
| **`hx cache show`** | Displays the current active cache path. | Prints the absolute path to the cache directory. |
| **`hx cache disable`** | Disables automated caching for your *current shell session*. | Sets `NO_CACHE=1`. Outputs: `⚠️ Cache disabled.` |
| **`hx cache enable`** | Re-enables automated caching for your current session. | Unsets `NO_CACHE`. Outputs: `⚠️ Cache enabled.` |

### Environment & Pipeline Configuration
These top-level commands allow you to toggle specialized environment settings or pipeline behaviors by sourcing external configuration scripts.

| Command | Description | Implementation Detail |
| :--- | :--- | :--- |
| **`hx disable`** | Disables specific Answer framework behaviors for the session. | Sources `bin/commands/disable`. |
| **`hx enable`** | Restores standard pipeline behavior and configurations. | Sources `bin/commands/enable`. |

### Interaction Recovery ("Last Run" Shortcuts)
These commands provide rapid access to your most recent LLM interaction without re-running prompts or manually locating files. They identify the latest `.json` file in your active cache and pipe its content into specialized reasoning tools.

| Subcommand | Description | Pipeline Logic |
| :--- | :--- | :--- |
| **`hx why`** | Explains the logic behind your last AI response. | `cat <latest_cache> \| why.sh` |
| **`hx what`** | Summarizes or expands upon the latest conversation turn. | `cat <latest_cache> \| what.sh` |

## Examples

**1. Troubleshooting and Clearing Cache**
If you encounter issues with stale context, clear your cache:
```bash
$ hx cache clear
⚠️ Are you sure you want to remove /home/user/.config/hallux/cache? (y/N)
Delete directory? (y/N): y
🗑️  Cache cleared.
```

**2. Disabling Cache for a Single Session**
To prevent any new queries from being saved or using cached results during a session:
```bash
$ hx cache disable
⚠️ Cache disabled.
# Subsequent 'ask' commands will perform fresh API calls and won't be stored locally.
```

**3. Re-examining Previous Interactions**
If you just ran an `ask` command, you can immediately analyze the response using your "why" tool:
```bash
$ ask "Explain this complex bash regex" | why
# (Processes latest cache entry through why.sh)
```

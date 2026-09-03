```markdown
# Bash History Integration

The **answer** toolchain can wire your live shell history into the project workspace so that `ask`, `help`, and other pipeline tools can see the commands you actually ran. This page explains how to enable it, how to use it, and exactly where your data lives.

> This feature is **optional**. If you don't configure per-shell `HISTFILE` values, every command in the harness works exactly as before—no symlinks are created, no files are touched, and you'll see a single info line in the log.

---

## What It Does (and What It Doesn't)

When your bash environment assigns a **unique history file per shell PID**, the harness:

1. Detects the non-default `HISTFILE` during `hx enable`.
2. Creates a `bash_history/` subdirectory under your project's `.hallux` workspace.
3. Drops a **symbolic link** (not a copy) into that directory pointing at your live history file.

That's it. No background process, no polling, no daemon. The link is a plain filesystem entry. Your history file is written by bash itself on every prompt (via `PROMPT_COMMAND`), exactly as it would be without the harness.

**What is NOT captured or stored by the bash history:**

- Model responses and conversation JSON: Those are by `hx cache enable|disable`.
- Explicit provenance information: Enter it into git notes or extract it to `.hallux` using `hx provenance` and related commands.
- Environment variables, secrets, or command-line arguments beyond what bash itself records.
- Any data beyond what your shell's standard `history` mechanism writes to `$HISTFILE`

If you'd read your `~/.bash_history_12345` file with `cat`, you'd see exactly the same lines the harness can see. The symlink adds no transformation layer.

Remember: if you change projects during a shell session (i.e. if you `cd` somewhere so that `hx root` changes to another project `.hallux/` directory) then you should re-run `hx` to re-establish your context.

Similarly, if you use git worktrees, you should symlink the `.hallux` directory or directories between the workdirs, independent of the bash history feature.

---

## Enablement

### 1. Configure per-PID history files

The harness requires that each bash process writes to its own file. The reference configuration lives at [`doc/bash-history-settings.sh`](doc/bash-history-settings.sh). You can source it directly or adapt the relevant lines into your own `.bashrc`:

```bash
# Core: one history file per shell PID
export HISTFILE="$HOME/.bash_history_$$"
export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTCONTROL=ignoredups:erasedups
export HISTTIMEFORMAT="%F %T  "

# Save after every prompt so the file is always current
PROMPT_COMMAND="history -a; ${PROMPT_COMMAND:+$PROMPT_COMMAND; }"
```

The key line is `HISTFILE="$HOME/.bash_history_$$"`. The `$$` expands to the current process ID, so two terminals open side-by-side produce `~/.bash_history_41287` and `~/.bash_history_41302`—independent, non-overwriting files.

> **If you skip this step** and leave `HISTFILE` unset (or at its default `~/.bash_history`), `hx provenance add bash_history` prints a one-line notice and exits 0. No directory is created, no symlink is written.

### 2. Bootstrap the harness

As usual, source the bootstrap:

```bash
$ source ~/.bash.d/hx-bootstrap.sh
```

### 3. Enable in a project

```bash
$ cd ~/wip/myproject
$ hx enable
👣 hallux localhost:8080 llama3 .hallux .hallux/bash_history/bash_history_41287
```

The last token in that line is the relative path of the symlink that was just created. If your `HISTFILE` is still the shared default, you'll see an info notice instead and no path.

### 4. Manual / re-run invocation

You can invoke the symlink logic at any time, independently of `hx enable`:

```bash
$ hx provenance add bash_history
.hallux/bash_history/bash_history_41287
```

The command is **idempotent**: if the symlink already exists and points to the correct target, it prints the path and does nothing else. It will not overwrite a symlink that points to a different file (you'd need to `rm` it manually first).

### 5. Find the workspace root

`hx root` prints the path to the nearest `.hallux` directory (or `~/.config/hallux/` if you're outside a project). Useful in scripts or when you need to reference the workspace explicitly:

```bash
$ hx root
.hallux
```

---

## Usage

### Inspect your linked history

The symlink is a plain file from the shell's perspective:

```bash
$ cat .hallux/bash_history/bash_history_41287
  1  2025-07-11 09:14:02  cd ~/wip/myproject
  2  2025-07-11 09:14:05  hx enable
  3  2025-07-11 09:15:22  git log --oneline -5
  4  2025-07-11 09:16:01  sudo dmesg | tail -40
  5  2025-07-11 09:16:44  hx provenance add bash_history
```

### Feed your history into a query

Because the file is just text on disk, you can stream it into any pipeline command:

```bash
$ cat .hallux/bash_history/bash_history_41287 | help "What was I debugging, and what did I try?"
```

Or pull only the recent window:

```bash
$ tail -20 .hallux/bash_history/bash_history_41287 | ask "Summarize my last 20 commands as a short markdown checklist."
```

You can also combine it with other context sources:

```bash
$ lx .hallux/bash_history/bash_history_41287 src/main.py \
  | help "I was running these commands before the build broke. Which one likely introduced the regression?"
```

### Use it in a multi-turn pipeline

The history file can seed a conversation and then be followed by follow-up questions:

```bash
$ tail -10 .hallux/bash_history/bash_history_41287 | ask "What am I working on?" \
  | ask "Suggest the next two commands I should run."
```

### Multiple shells, multiple files

If you have two terminals open in the same project, you'll see two symlinks:

```
.hallux/bash_history/
├── bash_history_41287 -> /home/leigh/.bash_history_41287
└── bash_history_41302 -> /home/leigh/.bash_history_41302
```

Each reflects a different session's commands. You can target either one explicitly by PID.

### Combining with standard bash history utilities

Nothing about the harness changes how bash itself works. You can still use `history`, `fc`, `!!`, `Ctrl-R`, and friends. The per-PID files simply mean that `history` in one terminal won't see commands typed in another.

---

## Data Transparency

### Where the data lives

| Artifact | Location | Owner | Created by |
|---|---|---|---|
| **History file** (the real data) | `$HOME/.bash_history_<PID>` | bash (via `PROMPT_COMMAND`) | Bash's own `history -a` |
| **Symlink** (a pointer) | `.hallux/bash_history/bash_history_<PID>` | `hx provenance add bash_history` | The harness bootstrap |
| **`.hallux/` workspace** | Project root (or `~/.config/hallux/` fallback) | User / harness | `hx enable` / `hx root` |

The symlink does **not** copy, read, or transform the history file. It is a 60-byte filesystem entry. The history file continues to be written exclusively by your shell process. The harness never opens it for writing.

### What the harness reads (and when)

The harness does **not** poll or tail the history file in the background. The file becomes readable by downstream pipeline commands **only** when you explicitly reference it in a query (e.g., `cat .hallux/bash_history/... | ask ...`) or when a tool like `lx` is pointed at it. There is no scheduled ingestion, no watcher, no hidden subprocess.

### What is in the history file

Exactly what bash records: the command line you typed (after `HISTCONTROL` filtering), the timestamp (if `HISTTIMEFORMAT` is set), and the sequence number. No environment dump, no stdout/stderr, no model output, no API keys.

### Visibility and git

- The history files live in `$HOME`, outside any project tree. They are not in version control unless you put them there.
- The `.hallux/bash_history/` directory contains only symlinks. If your `.hallux` directory is committed (which it typically is **not**—add it to `.gitignore`), the symlinks would appear as small text files containing an absolute path. The target data is never committed.
- The provenance Git notes (created by `hx provenance add what|why|...`) store a snapshot of the *last* command and response, not the full history file.

### Privacy considerations

- **Local only.** No history data is sent to any API endpoint unless you explicitly pipe it into an `ask`/`help`/`bx` command. If you do pipe it, it travels as part of your prompt to your configured model endpoint—exactly as any other text input would.
- **No network side-channel.** The symlink creation and `hx enable` flow are entirely local filesystem operations.
- **You control the data.** The history file is yours. Delete it, truncate it, or change `HISTCONTROL` to whatever you prefer. The harness respects whatever bash gives it.

### Disabling / cleaning up

To stop the integration:

```bash
# Remove the symlink for this session
rm .hallux/bash_history/bash_history_$$

# Or remove the whole directory
rm -rf .hallux/bash_history/
```

To prevent it from being re-created on the next `hx enable`, simply don't set `HISTFILE` to a per-PID value (i.e., remove or comment out the `HISTFILE="$HOME/.bash_history_$$"` line in your `.bashrc`). The harness will detect the default and skip the symlink step.

To clean up the actual history files from your home directory:

```bash
rm ~/.bash_history_*
```

### File lifecycle

| Event | Effect on history file | Effect on symlink |
|---|---|---|
| Shell opens | Created (empty) | — (not yet linked) |
| `hx enable` | Unchanged | Created → points to file |
| You type commands | Appended by bash | Unchanged (still valid pointer) |
| Shell exits (`exit`) | Persists on disk | Persists (now a dangling link if file is cleaned up) |
| You `rm` the history file | Gone | Dangling symlink (harmless, invisible to `ls -l` targets) |
| You `rm -rf .hallux/bash_history/` | Unchanged | Gone |
| Next `hx enable` (new PID) | New file created by bash | New symlink for new PID; old dangling link remains until cleaned |

---

## Quick Reference

```bash
# See if the integration is active
ls -l .hallux/bash_history/

# Read your current session's commands
cat .hallux/bash_history/bash_history_$$

# Ask a question about what you did
tail -30 .hallux/bash_history/bash_history_$$ | help "What was I trying to fix?"

# Re-link (safe to run repeatedly)
hx provenance add bash_history

# Find the workspace
hx root

# Check what the reference config looks like
cat doc/bash-history-settings.sh
```
```

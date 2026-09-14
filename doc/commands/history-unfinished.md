#### **Description**
The `history-unfinished` script lists bash history session files modified on a specified date (default: today) from either the current Hallux project's `.bash_history/` directory or the user's home directory (`$HOME`), depending on the mode selected. Results are rendered as a markdown table using `glow`. Rows whose content contains the words *unfinished* or *incomplete* are flagged in the **Notes** column; all matching files are listed, not just those with unfinished work.

> **Note:** The script supports both project-specific and global search modes via the `-p` (default) and `-a` (all) flags.

#### **Usage**
```bash
history-unfinished.sh [-d DATE] [-p|--project] [-h|--help] [-a|--all]
```

#### **Options**
| Option | Description |
|--------|-------------|
| `-d DATE` | Filter by date (e.g., `Sep 13` or `2023-09-13`). Defaults to today. |
| `-p|--project` | Explicitly select project mode (default). Searches `$(hx root)/.bash_history/bash_history_*`. |
| `-h|--help` | Display the usage string and exit. |
| `-a|--all` | Search all bash history files in `$HOME` (not limited to project-specific paths). |

#### **Output**
A markdown table piped to `glow -t --width 200` with the following columns:

| Column | Description |
|--------|-------------|
| **Date/Time (PDT)** | Modification time of the file, rendered in the system's local timezone (labelled PDT on PDT-configured hosts; no explicit `TZ` conversion is performed). |
| **Filename** | Full path to the matched file. |
| **Title** | First line of the file (often a session name or context comment). |
| **Notes** | `Unfinished work detected` if the file content matches `unfinished` or `incomplete`; otherwise blank. |

If no files match the date window, the script prints a message to stderr and exits 0.

#### **Example**
```bash
# List project history files modified today (default)
history-unfinished.sh

# List project history files modified on a specific date
history-unfinished.sh -d "Sep 13"

# List all history files in the user's home directory for a specific date
history-unfinished.sh -a -d "2025-01-15"

# Explicitly pass -p (same as default)
history-unfinished.sh -d "2025-01-15" -p
```

Each invocation renders a `glow`-formatted table of all `bash_history_*` files under `$(hx root)/.bash_history/` (or `$HOME` for the `--all` mode) whose mtime falls on the target date.

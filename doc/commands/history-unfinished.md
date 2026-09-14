#### **Description**
The history-unfinished script identifies and lists unfinished bash history sessions (`*.bash_history`) based on a specified date and search path. 

It defaults to today's date and supports filtering by either all
server-side bash history (default) or history files in the current Hallux project.

#### **Usage**
```bash
history-unfinished.sh [-d DATE] [-p|--project] [-h|--help]
```

#### **Options**
| Option | Description |
|--------|-------------|
| `-d DATE` | Filter by date (e.g., `Sep 13` or `2023-09-13`). Defaults to today. |
| `-p|--project` | Use project-specific history path (`$(hx root)/.bash_history/.bash_history*`). |
| `-h|--help` | Display this help message. |

#### **Output**
- **Markdown table** with columns:
  - **Date/Time (PDT)**: Time the file was last modified in Pacific Daylight Time.
  - **Filename**: Full path to the `.bash_history` file.
  - **Title**: First line of the file (may reflect session context).
  - **Notes**: Marked if "unfinished" or "incomplete" detected in the file content.
- **Formatted with `glow`**: A terminal-based markdown viewer for better readability.

#### **Example**
```bash
history-unfinished.sh -d "Sep 13" -p
```
This command will search for `.bash_history` files in the current project directory modified on September 13, and list only those with unfinished work.

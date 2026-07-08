# Tool Usage

Tool usage is in progress.

```
🦶$ ask "Check my git status and tell me if I have any uncommitted changes." | tools git_tools | help output a bash codefence to commit the file with a good message | tools git_tools | answer | unfence | bash
🤖 git status 

─────┬──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ ```bash
   2 │ git add doc/tool-usage.md
   3 │ git commit -m "Add documentation for tool usage"
   4 │ ```
─────┴──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
🤖 Proceed? (y/N): n
🚫 discarded
🦶$ 
```

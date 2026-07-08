# Examples: Using Answer

The `answer` toolchain is designed to be used in pipelines. By chaining commands, you can transform raw system data into actionable intelligence or move from a natural language prompt directly to an executed script.

---

## 1. The Developer Loop (Code & Git)
Transform files, generate new versions, and commit changes—all through the shell pipeline without leaving your terminal.

### Automating Documentation Refactors
Use `lx` to ingest multiple local files as context for a rewrite, then use `unfence` with `bash` or `tee` to apply changes instantly.
```bash
# Ingest current project files and ask for an improved README
$ lx README.md requirements.txt label_stars.py | help write a new README > README-2.md

# Review, stage, and use the AI's suggested commit message via 'help-commit'
$ git add . && git status | help "write a concise git commit message for these changes" | unfence | bash

# Or just use help-pcommit
$ help-commit
```

### Summarizing Complex Diffs
Instead of reading hundreds of lines of diff, pipe them into `help` to get an executive summary.
```bash
# Get a high-level overview of what changed in the current branch
$ git diff -U10 --no-color --staged | help "summarize these changes by functional area"

# Specifically ask for commit messages based on staged changes
$ git diff -U10 --no-color --staged | help "write a structured git commit message, clustering by function" > my_commit.txt
```

### Generating & Executing Scripts Safely
The `unfence` command is your safety gateway. It extracts code from markdown and requires manual confirmation before it hits the interpreter.
```bash
# Generate a python script to modify config files, review it, and run it immediately
$ help "write a python script that finds 'key=value' lines in stdin and multiplies value by 1.25" | unfence python | python

# Create an alias for rapid deployment of logic blocks
alias deploy_logic='help write the solution as a python block | unfence python | python'
$ echo "print(1+1)" | deploy_logic
```

---

## 2. System Administration & Triage
Treat your system commands like data sources that can be analyzed for anomalies, performance bottlenecks, or configuration errors.

### Hardware & Resource Diagnostics
Use `bx` to capture the state of a running process and pipe it into an analysis session.
```bash
# Analyze current GPU usage (NVIDIA)
$ nvidia-smi | help explain what is happening with my VRAM

# Perform deep system triage on all processes
$ bx ps gauxww | help "what do you notice that I should know as the owner of this server?"

# Check memory bandwidth based on hardware output
$ (systype; sudo lshw) | help "calculate the theoretical peak memory bandwidth"
```

### Troubleshooting Package & Kernel Issues
Feed error logs or package manager outputs directly into `help` to get step-by-step resolution instructions.
```bash
# Fix broken apt dependencies or held packages
$ sudo apt upgrade 2>&1 | help "how do I resolve these signature verification errors?"

# Debug NVMe health on Raspberry Pi/Linux
$ nvme list | help "explain the status of my drives and how to monitor their health"
```

---

## 3. Data Transformation (Nuextract)
The `nuextract` capability allows you to turn messy, unstructured CLI output into clean, structured JSON for downstream automation.

### Transforming File Lists to Structured JSON
Convert a standard directory listing into an array of objects that your own scripts can parse.
```bash
# Extract filename and metadata from ls -l into a JSON array
$ ls -l | ask nuextract '[{ "filename": "", "metadata": { ... } }, ...]'

# Convert git logs into structured data for custom reporting
$ git log -3 | ask nuextract '{"commit": [{"sha": "", "author": ""}]}'
```

### Parsing Logs and Headers
Turn complex, multi-line text files (like mail headers or system logs) into summarized reports.
```bash
# Analyze suspicious email headers for SPF/DKIM validity
$ help "analyze these mail headers for security risks" < ~/logs/bad-msg.txt

# Extract specific data patterns from a large log file
$ tail -n 100 /var/log/syslog | ask nuextract '{"timestamp": "", "message": ""}'
```

---

## 4. Quick Learning & Documentation
Use `man` pages and command outputs as context to get instant, conversational explanations of your environment.

### Interactive Man Page Exploration
Instead of scrolling through terminal text, pipe a man page into the tool to ask specific questions about its flags.
```bash
# Ask for clarification on obscure flags without leaving the prompt
$ man xxd | help "I want to print file contents without the address column"

# Get examples for complex command combinations
$ du -sh * 2>&1 | help "explain what these results mean and how to sort them by size"
```

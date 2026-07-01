### Usage

The `unfence` script is designed to extract and execute code blocks from text, specifically useful for processing output from LLMs that wrap code in Markdown triple-backticks (```).

#### Basic Pipe Usage
Pipe the output of an ASK command into the script. It will extract the content, display it using your system's preferred pager (like `bat`), and ask for confirmation before printing the final result to `stdout`.

```bash
# Example: Extracting code from an ASK prompt
ask "Write a python script to list files" | unfence

# Example: Extracting code from a stored response
cat response.md |  unfence
```

#### Interactive vs. Non-Interactive
* **Interactive (Terminal):** The script will display the code in a pager and prompt: `Proceed with this command? (y/N):`. If you press `y`, the code is sent to `stdout`.
* **Non-Interactive (Pipe/Script):** If the input is not a TTY (e.g., inside a script), it defaults to "yes" automatically and outputs the code immediately.

#### Typical Workflow (Execution)
Since the script outputs the raw code to `stdout` upon confirmation, it is commonly used to pipe code directly into a shell:

```bash
# Extract a bash script from an ASK response and execute it immediately
ask "Give me a one-liner to check disk usage" | unfence | bash
```

#### Environment Variables
It uses `PIPELINE_MAGIC_HEADER` to identify specific formats and `PIPETEST_PAGER` to override the default pager.

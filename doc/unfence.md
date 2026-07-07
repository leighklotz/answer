<<<<<<< HEAD
=======
# unfence

**unfence** is a utility that extracts the raw content from the first Markdown code block found in an input stream. It is primarily used to strip away Markdown formatting and surrounding conversational text, making LLM-generated output ready for direct execution by shell interpreters.

## Synopsis

```bash
<text-with-fences> | unfence
```

## Description

When an LLM generates a response, it typically wraps code within Markdown fences (e.g., ` ```bash `). `unfence` scans the input, identifies the first occurrence of a code block, and isolates the content within those markers. This allows you to bridge the gap between a text-based LLM response and a command-line execution environment.

## Key Features

| Feature | Behavior |
|---------|---------|
| **First-Block Extraction** | If the input contains multiple code blocks, `unfence` only extracts the content of the first one. |
| **Auto-answer** | If the input begins with the `PIPELINE_MAGIC_HEADER` (indicating a JSON conversation state), `unfence` automatically invokes `answer` to resolve the state into plain text before attempting extraction. |
| **Pipeline Safety** | When its output is being piped to another command (e.g., `unfence | bash`), `unfence` provides a safety gate that requires explicit user confirmation before allowing the code to flow to `stdout`. |
| **Error Handling** | If no Markdown code block is detected in the input, the command logs an error and exits with status `1`. |

## Pipeline Safety Gate

To prevent the accidental execution of incorrect or dangerous code in a pipeline, `unfence` provides a safety gate when its `stdout` is redirected or piped:

1.  **Preview:** The extracted content is displayed to **stderr** via a pager so it does not interfere with the pipe. The pager is selected in the following order of priority:
    *   `$PIPETEST_PAGER` (if set)
    *   `batcat`
    *   `bat`
    *   `cat` (fallback)
2.  **Confirmation:** The user is prompted: `🤖 Proceed with this command? (y/N): ` via the actual terminal (`/dev/tty`).
3.  **Decision:**
    *   **`y` / `Y`**: The content is sent to `stdout` for the next command in the pipeline.
    *   **Any other key**: The process prints `🚫 discarded` to `stderr` and exits.

*Note: If running `unfence` directly in a terminal (where stdout is a TTY), the command outputs the code immediately without prompting.*

## Examples

**1. Direct Execution (The "Code-to-Shell" Pattern)**
Extract a bash script from an LLM response and run it immediately.
```bash
ask "Write a script to list all running processes" | unfence | bash
```
*(Note: This will trigger the safety prompt before `bash` executes the code.)*

**2. Extracting Python Code**
Clean the output of a conversational response to use in a Python interpreter.
```bash
ask "Write a python function to calculate primes. Put it all in one code fence." | unfence | python
```

**3. Direct Pipeline from `ask`**
```bash
ask "Give me a bash one-liner to check disk usage" | unfence | bash
```
```

>>>>>>> newdoc

Based on a comparison between the implementation in `unfence.sh` and the documentation in `doc/unfence.md`, there is a discrepancy in the description of the "Safety Gate." 

The code implements **Pipeline Safety** (triggering a prompt when `stdout` is a pipe, such as in `unfence | bash`) rather than "Interactive Mode" (triggering a prompt when running in a terminal). The documentation currently describes the latter, which is the inverse of the actual logic.

Here is the updated `doc/unfence.md`:

```markdown
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
| **JSON Auto-Resolution** | If the input starts with the `PIPELINE_MAGIC_HEADER`, `unfence` automatically invokes `answer` to resolve the JSON conversation history into plain text before attempting extraction. |
| **Pipeline Safety** | When its output is being piped to another command (e.g., `unfence | bash`), `unfence` provides a safety gate that requires explicit user confirmation before allowing the code to flow to `stdout`. |
| **Error Handling** | If no Markdown code block is detected in the input, the command exits with an error. |

## Pipeline Safety Gate

To prevent the accidental execution of incorrect or dangerous code in a pipeline, `unfence` provides a safety gate when its `stdout` is redirected or piped:

1.  **Preview:** The extracted content is displayed to **stderr** via a pager (preferring `batcat` or `bat` for syntax highlighting and line numbers) so it does not interfere with the pipe.
2.  **Confirmation:** The user is prompted: `🤖 Proceed with this command? (y/N): ` via the actual terminal (`/dev/tty`).
3.  **Decision:**
    *   **`y` / `Y`**: The content is sent to `stdout` for the next command in the pipeline.
    *   **Any other key**: The process is aborted, and `🚫 discarded` is printed to `stderr`.

*Note: If running `unfence` directly in a terminal (without a pipe), the command outputs the code immediately without prompting.*

## Examples

**1. Direct Execution (The "Code-to-Shell" Pattern)**
Extract a bash script from an LLM response and run it immediately.
```bash
ask "Write a script to list all running processes" | answer | unfence | bash
```
*(Note: This will trigger the safety prompt before `bash` executes the code.)*

**2. Extracting Python Code**
Clean the output of a conversational response to use in a Python interpreter.
```bash
ask "Write a python function to calculate primes" | answer | unfence | python
```

**3. Direct Pipeline from `ask`**
Because `unfence` can resolve JSON history, you can skip the `answer` command in a pipeline:
```bash
ask "Give me a bash one-liner to check disk usage" | unfence | bash
```

**4. Viewing Content in Terminal**
If you simply want to see the clean code without executing it, run it without a pipe:
```bash
ask "Write a python script" | answer | unfence
```
```

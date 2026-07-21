# unfence

**unfence** is an intelligent extraction utility designed to isolate code blocks from Markdown content within a pipeline. It bridges the gap between conversational LLM output (which contains explanations, multiple snippets, and metadata) and shell execution environments by stripping away non-code text.

## Synopsis

```bash
<text|stdin> | unfence [LANGUAGE]
```

The optional `[LANGUAGE]` argument allows you to target a specific block type immediately via the command line.

## Description

When an LLM generates a response, it typically wraps code within Markdown fences (e.g., \`\`\`bash). **unfence** scans the input, identifies available fenced blocks, and extracts content for execution or further processing. 

Unlike a simple parser that only finds the first block, **unfence** is context-aware:
* **Adaptive Extraction:** If no language is provided and only one block exists, it extracts it directly (with a safety prompt). If multiple blocks exist, it enters **Selection Mode**.
* **Language Sniping:** Providing a language argument (e.g., `unfence python`) filters the available blocks to those matching that specific language tag.
* **Auto-answer & Cache Integration:** If the input begins with the pipeline magic header (`Content-Type: application/x-llm-history+json`), it automatically invokes the `answer` command to resolve the conversation state into plain text before attempting extraction. Because this uses the Answer caching mechanism, subsequent extractions of identical prompts are instantaneous and do not require new API calls.
* **Pipeline Safety Gate:** To prevent accidental execution of dangerous code in a pipeline, it provides an interactive safety gate whenever its output is being piped or when multiple choices are available.

## Input Modes

The behavior of `unfence` changes based on the type of input received:

| Condition | Logic | Resulting Content |
|-----------|-------|-------------------|
| **Piped (JSON History)** | Reads a `PIPELINE_MAGIC_HEADER`. Invokes `answer` to resolve the turn, then parses resulting text. | A stream of plain-text Markdown blocks extracted from the assistant's message. |
| **Piped (Plain Text)** | Scans raw incoming text for Markdown code fences. | The content contained within those identified fences. |

## Interactive Modes

### 1. Selection Mode (Multiple Blocks)
If your input contains several different code blocks and you run `unfence` without a target language, the script will prompt you to choose which one to extract:
* **By Index:** Enter the number of the block (e.g., `1`, `2`).
* **By Language:** Enter the name of a language present in the list (e.g., `bash`, `python`) to filter down further.

### 2. Targeted Mode (`unfence <lang>`)
If you run `unfence python`, the script skips general selection and attempts to find all Python blocks:
* **One Match:** It identifies that specific block and prompts for confirmation (if piped).
* **Multiple Matches:** It asks which of the matching indices you wish to extract.

## Pipeline Safety Gate

To prevent the accidental execution of incorrect or dangerous code in a pipeline, `unfence` provides a safety gate whenever:
1. Its output is being redirected/piped (`stdout != TTY`).
2. Multiple blocks are detected, requiring user selection.

**The Workflow:**
* **Preview:** The extracted content (or the list of options) is displayed to **stderr** via a pager so that it does not interfere with the pipe. Pager priority: `batcat` $\rightarrow$ `bat` $\rightarrow$ `less`/`more` $\rightarrow$ `cat`. 
* **Confirmation:** You are prompted in your terminal (reading from `/dev/tty`) : `🤖 Proceed with this command? (y/N): `.
* **Decision:** 
    * **`y`**: The content is sent to `stdout` for the next command in the pipeline.
    * **Any other key**: The process prints `🚫 discarded` to `stderr` and exits safely.

## Options

| Flag | Long form | Description |
|------|-----------|-------------|
| `--help` | | Print usage information and exit. |

## Examples

**1. Targeted Extraction (The "Language Sniper")**
If an LLM provides a Bash script followed by a Python test script, you can pick only the Python part:
```bash
# This will prompt you which python block to use if multiple exist
ask "Write a bash setup and a python validator" | unfence python | python3
```

**2. Direct Execution (The "Code-to-Shell" Pattern)**
Extract a shell script from an LLM response and run it immediately:
```bash
# This will trigger the safety prompt before `bash` executes
ask "Write a script to list all running processes" | unfence | bash
```

**3. Handling Multiple Blocks Interactively**
If you pipe multiple blocks without specifying a language, the tool guides you through selection:
```bash
# The user is prompted to select by number or language name
ask "Give me three different ways to list files in bash" | unfence | bash
```

**4. Cleaning Output for Tools**
Use it mid-pipeline to isolate code from a long conversational response before passing it to a compiler:
```bash
# The extraction will resolve the JSON state, extract text, then strip fences
ask "Write a C++ program that prints Hello World and include the compilation command as text" | unfence cpp > main.cpp && g++ main.cpp -o main && ./main
```

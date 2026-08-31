# Answer: A Shell-Based Code Assistant

The **answer** toolchain is a shell-based code assistant designed for Linux and macOS that treats Large Language Models (LLMs) as composable command-line filters.

If you are comfortable at a `bash` command-line prompt, most language model coding tools probably feel heavy-handed, injecting large, opaque abstractions that make the shell a second-class citizen, disrupting the terminal workflow. You don't need a harness that attempts to take over your local workspace or write your software for you; you want a predictable utility that fits in with your work style and preserves your control.

The **answer** toolchain treats Large Language Models as composable, standard command-line filters for Linux and macOS. By communicating strictly through standard inputs and outputs alongside tools like `grep`, `awk`, and `sed`, it keeps the model securely bound to the data loop you design.

It allows users to integrate AI directly into their terminal workflows by:
* **Chaining Conversations:** pipe inferences together to maintain inference history.
* **Execute Code Safely:** Explicit commands provide control and confirmation of script execution.
* **Extending Shell Capabilities:** Includes utilities such as `lx` (file ingestion), `bx` (command execution injection), and `help` (specialized for posix/bash/python workflows) to make your LLM a predictable part of the Unix pipeline alongside tools such as `grep`, `awk`, and `sed`.

---

## The Pipeline Model & Auto-Answer Mechanism

To bridge the gap between interactive human use and automated shell scripting, `ask` uses a *magic pipeline* that keeps the inference session history while presenting you with only the last output:

* **Interactive (TTY):** When run directly in a terminal window, `ask` and related commands automatically route the underlying structured payload through `answer`, delivering the assistant's plain-text response.
* **Pipeline (`STDOUT/STDIN`):** When `ask` detects that its output is being piped into another command or redirected to a file, it switches to machine-oriented mode. It emits **JSON** containing the full conversation history (system prompts, user queries, and assistant responses), prefixed with an appropriate MIME header. A downstream `ask` or `help` command recognizes that header and appends another turn; an ordinary Unix command sees the structured stream unless you terminate the conversation pipeline with `answer`.

You can compose pipelines on the command line by interactively re-doing, editing, and appending to the previous commands. You keep multiple `forks` of a conversation or pipeline in play simply by repeating and updating previous commands. You can use your bash shell history commands and keystrokes such as `history`, `!!`, `Ctrl-R` to work with your chat history and command history together. Or run `bash` inside `Emacs` to obtain full editing ability inside a `shell` buffer.

---

## Pipeline Modes & Capabilities

The harness switches seamlessly between interactive workflows and automated text extraction using four primary paradigms:

### 1. One-shot
You can use the `ask` and `help` commands to ask one-shot questions, right in the shell. You can direct input to the commands, and use string interpolation in the prompt.

````bash
    $ hx enable
    👣$ help briefly, how can i use a bash variable reference to drop the last file extension 
    ✨
    Use **parameter expansion** with the `%` operator to remove the shortest match of a dot and any characters
    following it from the end of the string:

    ```bash
    FILE="image.tar.gz"
    echo "${FILE%.*}"
    # Output: image.tar
    ```
    klotz@snapback:~/wip/answer👣$ 
````


### 2. One-shot with input (`| help`, `| ask`)

You can pass general output into `help` and `ask`, with or without the `bx` wrapper. If the input is self-explanatory, use stdin directly. If the request would benefit from having the command that produced the output documented, use `bx`. If there are multiple files, use `lx`.

````bash
    👣$ sudo dmesg | tail -40 | help what is the up with the WiFi
    ✨
    Based on the log snippet provided, there does not appear to be a connection failure or a hardware error. 
    Here is the breakdown of what the WiFi status shows:
    ...

````

````
    👣$ openssl --help 2>&1 | help I want to check the certificate at  https://example.com
    ✨
    ```bash
    openssl s_client -connect example.com:443 -servername example.com </dev/null | openssl x509 -text -noout
    ```
    👣$ 
````

````bash
    👣$ lx bin/*.sh | help look for unnecessary debug statements
    📥📥📥📥📥📥📥📥📥📥📥📥📥📥✨
Based on your provided scripts, here are the unnecessary debug statements (commented-out code or developer trace logs used for inspecting internal state) that should be removed before production use:

### 1. `bin/answer.sh`
* **Line 28:** `# echo "resolved_history=$resolved_history"`  
    *(A commented-out print statement used to inspect a variable's contents during development.)*
...

````

### 3. Building on the one-shot with conversations (`ask | ask`)
Because *answer* supports pipeline magic, you can pipe the output of a one-shot command into another inference command, and the pipeline will retain the conversation history.

Each subsequent command automatically reads the pipeline history, appends your new turn, and tracks context seamlessly without losing state.
```bash
ask "What is 20+30?" | ask "Convert that result to octal"
```

### 4. Tool & Extraction Mode (`ask | unfence | interpreter`)
Target code generated by an LLM, pass it through a confirmation gateway, and stream it straight to an interpreter.
The `unfence` command handles targeted extraction of code fences and requires user confirmation before proceeding.

```bash
help "Write a python script to list files" | unfence python | python
```

### 5. Mid-Pipeline Observation (`ask -t | ask`)
View what the model is generating without fracturing your conversation chain. The `--tee` (or `-t`) flag routes human-readable text out to `stderr`, while passing the pristine JSON history down `stdout`.
```bash
ask "Plan a bash script to xyzzy" | ask -t "Write the in bash code" | unfence bash | bash
```

### 6. Interactive terminal (`ask -i`)
Use `-i` (or `--input`) to enable interactive mode for multi-line `stdin`, which is terminated with `Ctrl-D`. This is ideal when you want to paste large chunks of text or code into the prompt manually.

```bash
$ ask -i What is this emoji? 🥟 [Press Ctrl+D]
💬 Give input followed by Ctrl-D:
 dumpling
💭
This emoji is a **dumpling** (🥟).
```

---

## The Minimalist Toolchain

The harness relies on a suite of single-purpose scripts and a core engine primitive:

* **`ask / help`**: process prompts and `stdin` to construct context payloads. `help` is a specialized wrapper focused on Python and Bash development. 
* **`answer`**: consumes the structured request or conversation history, performs or retrieves the inference, and writes the assistant's plain-text response to `stdout`. You normally do not call it explicitly at an interactive terminal, because `ask` and `help` do that automatically. Add it when you want to terminate the structured conversation pipeline and send plain text to a file or an ordinary Unix command.
    > **⚠️ Crucial Redirection Note:** When redirecting output to a file (e.g., `ask "code" > script.sh`), explicitly call `answer` before the redirection (`ask "code" | answer > script.sh`). Otherwise, you will capture the JSON conversation history instead of the plain-text response.
* **`unfence`** Extracts markdown code blocks from LLM output and provides an interactive pager/confirmation prompt to ensure you don't execute dangerous code without reviewing it first.
* **`lx`**: A file-ingestion utility that streams multiple target files into your pipeline, automatically wrapping them in clean markdown syntax blocks for downstream parsing.
* **`bx`**: A command-execution bridge. It executes shell commands and captures their output inside markdown fences so the results can be injected directly back into an LLM query.
* **`tools`**: A wrapper that routes conversation arrays to `toolex.py` to handle native LLM tool calls (function calling).
* **`hx`**: Workspace management utility used for enabling pipeline paths, resetting cache structures, and managing settings.
* **`systype`**: Provides system profiling metadata (CPU, RAM, Kernel) to ensure LLM reasoning is grounded in your actual hardware specs rather than generic assumptions.
* **`story.txt`**: A comprehensive reference file containing example usage scenarios, prompts, and expected outputs to help you master the harness.

---

## Production Patterns & Interactive Examples

### Example 1: Multi-Turn Pipeline 
```bash
$ ask write fib in bash | ask call it with 20 | ask rewrite in python and output the code in a python code fence | unfence python | python
```

### Example 2: Auditing Your Debugging History
Use standard shell mechanics such as `fc` or `history` to capture your terminal trail and feed it into the model for analysis.
```bash
$ history | tail -n 30 | ask "Summarize my recent actions as a concise markdown guide, skipping failed attempts."
```

### Example 3: Context Chunking for Large Files
To prevent context window overflow when handling massive files, use `split` to page through segments.
```bash
$ sudo dmesg | split -l 1000 --filter="help.sh look for anomalies in this segment"
```

### Example 4: Git wrappers
You can use answer to wrap a few convenient git commands to customize your workflow:

````bash
klotz@tensor:~/wip/answer👣$ help-commit
🐚🐚🐚🐚🐚🐚🐚💬✨🧠
─────┬────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ ```bash
   2 │ git add README.md
   3 │ git commit -m "Add Git wrapper examples to README" \
   4 │   -m "- Include a usage example for customizing git workflows using answer."
   5 │ ```
─────┴────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
🤖 Proceed? (y/N): n
````

---

### Status Emoji
The *answer* suite uses Unicode emoji icons to give status about the pipeline as it executes:

| Text | Icon | Meaning |
| :--- | :--- | :--- |
| ✨︎   | ✨ | Inference (cache miss) |
| 🎯︎   | 🎯 | Inference (cache hit) |
| 💬︎   | 💬 | piped content input |
| 🐚   | 🐚 | `bx` shell input |
| 📥   | 📥 | `lx` file input |

The environment variable `$HX\_ICON\_STYLE` controls the icon style, `text` or `emoji`.

---

## Workspace & Cache Architecture

The toolchain identifies a `.hallux` folder (crawling upwards from your current directory) to serve as an active project workspace and cache. If no such folder is found, it safely falls back to `~/.config/hallux/cache/`.

```text
.hallux/cache/
└── Gemma-4-27B...:5d97ec5e...:chatcmpl-iZss...json
```

---

## Management Utility (`hx`)

Once bootstrapped via `source`, the `hx` function provides workspace management, session control, and interaction auditing. It operates in three distinct modes: **Environment & Session Control**, **Interaction Provenance**, or **Cache Management**.

### 1. Environment & Session Control
These commands manage your active terminal environment and LLM configuration.

* **`hx enable / disable`**: Integrates the harness into your current session, adding a `(👣)` icon to the bash `$PS1`.
* **`hx model [args]`**: Launches the interface to configure API endpoints and model preferences.
* **`hx set-model [args]`**: Quickly switches the active LLM (via `$HX_MODEL`) for the current session.

### 2. Interaction Provenance (`hx provenance ...`)
`hx provenance` allows you to "bookmark" significant terminal interactions. It creates an auditable trail of command history and inference responses within a repository's metadata without polluting your actual git log. It command captures some of the recent command and response history as a specialized Git note `provenance/hallux` reference.
It is still a work in progress.

| Subcommand | Description | Behavior / Output |
| :--- | :--- | :--- |
| **`add`** | Captures the last executed command, its context, and the resulting response as a Git note. | Stores `Prompt + Command + Response`. |
| **`list`** | Displays a chronological timeline of all stored interaction hashes. | List of unique Git note hashes. |
| **`show [hash]`** | Instantly displays the full content of a specific recorded interaction. | Standard Git notes output. |

N.B.: You must call `hx provenance` directly in order to save provecnance.  Contrast with bash and inference cache:
- bash history collects .bash_history files into `$HISTFILE` files
- answer caches the responses to inference commannds, but not to tool calls. 

#### `add` Subcommand Modes
| Mode | Description | Use Case | Icon |
| :--- | :--- | :--- | :--- |
| *(default)* | Captures the last command and its output via history. | Standard CLI workflow automation. | — |
| **`response`** | Marks an interaction specifically as a model/tool response. | Explicitly labeling LLM outputs in history. | `➡️` |
| **`-`** (dash) | Reads content from STDIN or prompts for manual input in TTY. | Piping raw text OR manually entering notes interactively. | `\|` |
| **`describe`** | Records a plain-text description/note. | Adding non-command metadata to the provenance log. | `📜` |
| **`-`** (dash) | Reads content directly from **STDIN**. | Piping raw text or manual input into the provenance log without running a command. | `\|` |

**Usage Examples:**

*   **Standard Capture:**  
    `$ hx provenance add what` *(Captures last command and response)*
*   **Capture STDIN (Pipeline Mode):**  
    `$ echo "Custom text to record" \| hx provenance add -`
*   **Explicitly mark a response:**  
    `$ cat result.txt | hx provenance add response`
*   **Interactive Input:** Simply run `hx provenance add -`. If you are in an active terminal, the tool will prompt you for input; if you are piping text, it reads from STDIN immediately.

### Summary of logical alignment check:
| hx provenance subcmd | Emoji | Meaning |
| :--- | :--- | :--- |
| `what` | 💭 | last text response |
| `why` | 🧠 |  last reasoning trace |
| `response`| ⬅️ | last convo JSON response |
| `describe` | 📜 | describe last convo JSON response with inference |
| `-` | ➡️ | direct stdin attached | 

### 3. Cache Management (`hx cache ...`)
The framework uses local JSON files for caching to ensure speed and reduce API costs. Use these commands to manage your storage or toggle session behavior via environment variables.

* **`hx cache clear / show`**: Manage local history storage and automated caching.
* **`hx cache enable / disable`**: Enable or disable automated caching for the session.
* **`hx cache drop`**: Removes only the single most recent cache entry after a preview/confirmation.
* **`hx why`** and **`hx what`**: Retrieve reasoning (**🧠**) or standard interaction/output (**💭**) from your most recent `answer` inference.

---

## Installation & Setup

### Prerequisites

* **Bash 4+** (Required for harness scripts).
* **`jq 1.8+`** (Command-line JSON processor).
* **LLM API Key and endpoint, or self-hosted model endpoint.**

### Initialization Steps
First check your bash version to see if it is above 4.
```bash
$ echo $BASH_VERSION
5.3.15(1)-release
```

If you are on a Mac, you may wish to use [homebrew](https://brew.sh/) to install a more recent bash. (Or, fork this repo and port it to `zsh` :-)

1. **Clone and Enable:**
   ```bash
   $ git clone <repository_url>
   ```

2. **Configure Environment:**
   ```bash
   $ cd answer
   $ cp bin/commands/env.sh.sample bin/commands/env.sh
   $ emacs bin/commands/env.sh
   $ export VIA_API_CHAT_BASE="http://localhost:5000"
   $ export OPENAI_API_KEY="your-key-here"
   $ cp bin/commands/hx-bootstrap.sh .bash.d/ # or, append to your `.bashrc`
   $ source ~/.bash.d/hx-bootstrap.sh
   ```

---

## Quickstart

Here is a quickstart with a self-introduction you can try:

````bash
$ hx
👣 hallux enabled: model=gemma-4-26b-qat-batch
$ lx README.md | help what can you do
📥✨
Based on the documentation provided, I am part of the **Answer** toolchain—a shell-based code assistant designed to treat LLMs as composable command-line filters for Linux and macOS.

Here is what this toolchain can do:

    ### Core Functionality
    * **Conversational Chaining:** You can pipe commands together (`ask | ask`) to maintain multi-turn conversation history across a pipeline without losing context.
    * **Intelligent Mode Switching:** 
        * **Interactive Mode (TTY):** Delivers clean, plain text for human reading.
        * **Pipeline/Machine Mode:** Emits structured JSON with metadata and MIME headers for downstream automation.
    * **Safe Code Execution:** Through `unfence`, you can extract markdown code blocks from LLM responses and pass them through a confirmation gateway to an interpreter (such as Python or Bash).

    ### Specialized Tooling
    * **`ask`**: The primary interface for building context payloads from prompts, multi-line input (`-i`), or mid-pipeline observation (`--tee`).
    * **`answer`**: Extracts raw text tokens from JSON streams.
    * **`lx`**: Streams multiple target files into a pipeline as clean markdown blocks.
    * **`bx`**: Captures the output of shell commands and injects it back into an LLM query via markdown fences.
    * **`help`**: Optimized prompt for Python/Bash development workflows.
    * **`unfence | [interpreter]`**: Automates the flow from generating code to executing it in a controlled environment.
````

## Tools setup (optional, but recommended)
1. Visit [https://github.com/leighklotz/toolex](https://github.com/leighklotz/toolex) and install.
---

# More Documentation
You can find more `answer` documentation in the doc directory:
- Draft [blog-post-1](doc/blog-post-1.md)
- Doc pages for [commands](doc/commands/)
- More extensive [examples](doc/examples/)
- Implementation [plan](doc/plan/)
- Design center user [stories](doc/stories/)

## Testing

Run the automated test suite to verify pipeline outputs and state management:
```bash
./tests/story-test.sh
```

## Provenance

This LLM agent harness in Bash was derived from https://github.com/leighklotz/llamafiles and previous work.

## License

This project is licensed under the [MIT License](LICENSE).

# Answer: 🤖 A Shell-Based Code Generation & Execution Agent Framework

**Answer** is a command-line LLM-based agent framework that uses Posix pipes to compose and execute nonce agentic pipelines. It provides a conversational, shell-focused workflow for rapid prototyping, experimentation, and analysis.

## The State-Driven Pipeline Model

To allow seamless transitions between "thinking" (conversation) and "doing" (tooling), **Answer** tracks conversation states using an internal `infer()` engine primitive. This eliminates messy data format-juggling inside your shell pipes.

### 1. Conversation Mode (`ask | ask`)
* **Goal:** Build a continuous conversation where each command appends to the running history.
* **How it works:** `ask` passes heavy JSON arrays containing full history through pipes via a magic header. If a trailing `ask` detects a pending user prompt from the previous step, it automatically calls `infer()` to resolve it before adding the next turn.
* **Pattern:** `ask "Q1" | ask "Follow up Q2"`

### 2. Tool/Extraction Mode (`ask | unfence | tools`)
* **Goal:** Take the text result of an LLM and pass it (through a confirmation step) to a shell command (like `python`, `bash`).
* **Pattern:** `bx cat file.sh | ask "Refactor this code" | unfence bash | bash`

Unfence pauses to show you the incoming markdown, and then lets you select which code fences 

### 3. Hybrid/Observation Mode (`ask -t | ask`)
* **Goal:** See what the LLM generated in your terminal *while also* preserving the conversation JSON history for the next command.
* **How it works:** The `--tee` (or `-t`) flag on `ask` resolves the current turn, prints the human-readable text out to `stderr` for you to look at, but sends the full conversation JSON history down `stdout`.
* **Pattern:** `ask -t "Generate base bash script" | ask "Add error handling to it"`

## Pipeline Usage Models

`Answer` is designed to transition seamlessly between interactive chat and automated shell pipelines using four primary patterns:

**1. Interactive Chat (Human-Centric)**
When running `ask` directly in a terminal, it automatically formats the output into human-readable text.
```bash
$ ask "How do I list files by size?"
```

**2. Stateful Conversations (Chaining)**
To maintain context across multiple commands, pipe one `ask` into another. The framework automatically manages the underlying conversation history.
```bash
$ ask "Who is the President?" | ask "How old is he?"
```

**3. Text Extraction (Tooling/Shell Mode)**
To use LLM output in standard shell commands (like `bash` or `python`), use `answer` as a "cut-point" to convert the JSON conversation state into plain text.
```bash
$ ask "Write a hello world script" | unfence | bash
```

**6. End of line answers**
To output to a file or to pipe to a non-**Answer** component, use `answer` to extract the last assistant response. If you do not do call `answer` before the redirection or pipe, you will write out the entire JSON conversation instead.

```bash
$ ask "Write a hello world script in bash" | answer > hello.sh
```


**5. Mid-Pipeline Observation (Hybrid Mode)**
To see what the LLM is saying without breaking the pipeline, use the `--tee` (`-t`) flag. This prints human-readable text to your screen (`stderr`) while passing the JSON state forward (`stdout`) for the next command.
```bash
$ ask "Plan a bash script to ..." | ask -t "Write the code" | ask "Call it with 20" | unfence | bash
```

**6. Paging**
For large log files, you can use split to page through files, without context overlap.
```bash
sudo dmesg | split -l 1000 --filter="help.sh look for anomalies in this 1000-line segment of dmesg output"
```

---

## How it Works: The Dual-Layer Logic

The framework separates data for machines and data for humans to satisfy both interactive and automated environments.

* **Machine Layer (`ask`):** Uses **JSON** to pass the entire conversation history (system messages, user prompts, and assistant responses) through pipes.
* **Human Layer (`answer`):** Acts as the presentation layer, stripping the JSON structure to deliver **Pristine Plain Text** for users and shell utilities.

**Auto-Answer Mechanism:**
To ensure a seamless experience, `ask` detects its execution environment:
* **In a Terminal:** `ask` detects the TTY and automatically pipes its JSON through `answer` so you see text immediately.
* **In a Pipe:** `ask` bypasses auto-answer and outputs **raw JSON** so the next command in the chain can maintain the conversation state.

> **Implementation Note:** When passing JSON through a pipe, `ask` prepends a `PIPELINE_MAGIC_HEADER`. This allows subsequent `ask` commands to instantly distinguish between "raw text context" (like `cat logs.txt | ask`) and "actual conversation history" (like `ask "Q1" | ask "Q2"`).

## Core Components

* **`infer()`**: *The Engine Primitive.* An internal shared helper function. It checks if a conversation history array ends with a `user` query. If it does, it calculates your byte-accurate local cache keys, logs your horizontal tracking status emojis (`🎯` or `💭`) to `stderr`, runs the inference call, appends the `assistant` object, and spits the updated full JSON history out to `stdout`.
* * **ask**: *The State Builder.* Manages conversational turn-taking. It processes inputs, hooks into `infer()` to catch up on un-resolved context strings, appends your new query block, and pipes directly to `answer` if it detects it is at the end of a line (terminal window). Use `-i` (or `--input`) to enable interactive mode for multi-line `stdin` input (terminated with `Ctrl-D`).
* **`answer`**: *The Text Extractor.* The terminal endpoint of the execution tree. It takes your conversation data, resolves it, pushes a clean newline to `stderr` to wrap up your emoji tracker row, and delivers raw text tokens to `stdout`. You need to call `answer` only when the output is not terminal or another **Answer** command.
* **`bx`**: Executes a target command and wraps its raw console output inside a clean markdown code fence.
* **`unfence`**: Outputs only the first markdown code fences from the incoming text; if used in a pipeline, asks for confirmation.
* **`pipetest`**: Captures clean text from `stdin`, runs it through a pager visualizer on `stderr`, and safely pauses to ask you `Y/N` via your keyboard before feeding it forward. Incorporated in unfence already, but there if you need it.
* **`tools`**: Pipeline wrapper around `toolex.py`. Reads a JSON conversation array, resolves native LLM tool calls via toolex, and writes the updated conversation array to stdout.
* **`story.txt`**: A comprehensive file containing example usage scenarios, prompts, and expected outputs to help you get started.

---
## Testing

Automated verification of pipeline outputs is handled by `story-test.sh`. This script simulates expected outputs for common use cases (Fibonacci, Hello World, Math, Sorting) to ensure the `ask`, `answer`, and execution chain behave as documented.

Run tests using:
```bash
./tests/story-test.sh
```

## Examples

**Chaining questions (Conversation Mode):**
```bash
ask "What is 20+30?" | ask "Convert that result to octal"
# Output: 
# 💭💭
# 50 in decimal is 62 in octal.
```

**Running code (Tooling Mode):**
```bash
ask "Write a python script to list files" | unfence | python
```

### Test Case: Context Preservation
Understanding how context flows through different modes is crucial for effective prompting:

**1. Successful Context Chain (`ask | ask`):** The history is passed via JSON automatically.
```bash
$ ask say boo | ask why did you say that
Because you asked me to! You said "say boo," so I followed your instruction. 👻
```

**2. Intended Interface Cut (`ask | answer`):** Using `answer` drops the JSON history to raw text to communicate with your terminal window or standard shell utilities.
```bash
$ ask say boo | answer
Boo! 
```

---

## Workspace Cache Architecture

Your tools automatically crawl upwards from your current working directory to find a `.hallux` folder to claim as a project workspace and initialize a `cache/` directory inside it. If you run your tools outside an active project repository layout, they safely fall back to `~/.config/hallux/cache/` to keep your system clean.

```text
.hallux/cache/
└── _home_klotz_wip_models_Qwen3.6-35B...:5d97ec5e...:chatcmpl-iZss...json
```

---

## Pipeline Patterns

### Basic question and answer
```bash
ask "Write fib in Python"
```

### Piping command output into a question
```bash
dmesg | ask "Spot any SCSI issues"
```

### Pausing for input command output into a question
```bash
$ ask -i What is this emoji?
💬 Give input followed by Ctrl-D:
🥟
^D
💭
This emoji is a **dumpling** (🥟).
$ help -i explain 
💬 Give input followed by Ctrl-D:
if [[ -t 0 ]]; then
^D
💭
The expression `[[ -t 0 ]]` is a Bash conditional used to check if **standard input (stdin)** is connected to an **interactive terminal**.
...
```

### Chained follow-up questions
Use `ask -t` mid-pipeline so the conversation JSON continues to flow on stdout while the human-readable reply appears on stderr:
```bash
dmesg | help "Spot any SCSI issues" | help -t "What can I do about the md0 device?" | help "Write a command to check the drive status" | unfence | bash
```

### Tool-call resolution with toolex
```bash
ask "Spot any SCSI issues with dmesg" | tools linux_tools | ask "What can I do about the md0 device?"
```

---

## Prerequisites

Before you begin, ensure you have the following installed:
* **OpenAI API Key / Local Endpoint:** Required for accessing the inference backend.
* **`jq`:** A lightweight and flexible command-line JSON processor. Install via your package manager:
  * **Debian/Ubuntu:** `sudo apt-get install jq`
  * **macOS:** `brew install jq`
* **Python 3:** Needed for executing generated Python code.
* **Bash 4+:** The scripts are written specifically for Bash 4 or later.

---

## Setup

1. **Clone the Repository & Enable Paths:**
   ```bash
   git clone <repository_url>
   cd answer
   source commands/enable.sh
   ```

2. **Set Environment Variables:**
   
   ```bash
   $ cp env.sh.sample env.sh
   $ emacs env.sh
   export VIA_API_CHAT_BASE="http://localhost:5000"
   export OPENAI_API_KEY="your-key-if-applicable"
   ```

3. Add this to your bash aliases, for bootstrapping. Use `hx enable` to get started. Once enabled, the full definition of `hx` will take precedence.
   ```
   # enable function only; once enabled, answer will override
   function hx() {
       # Require bash 4+
       if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
           echo "🦶ERROR: bash 4 or later is required (running ${BASH_VERSION})." >&2
           return 1 2>/dev/null
       fi
       if [ "$1" == "answer" ] || [ "$1" == "enable" ]; then
           source ~/wip/answer/commands/enable
       else
           echo "usage: hx answer"
           return 1
       fi
   }
   ```

---

## License

This project is licensed under the [MIT License](LICENSE).

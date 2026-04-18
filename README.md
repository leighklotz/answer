# Answer: A Shell-Based Code Generation & Execution Agent Framework

**Answer** is a command-line LLM-based agent framework that uses Posix pipes to compose and execute nonce agentic pipelines. It provides a conversational, shell-focused workflow for rapid prototyping, experimentation, and analysis.

## The Dual-Mode Pipeline Model

To allow seamless transitions between "thinking" (conversation) and "doing" (tooling), **Answer** uses two distinct data protocols in its pipelines:

### 1. Conversation Mode (`ask | ask`)
*   **Goal:** Build a continuous conversation where each command knows the history of previous ones.
*   **How it works:** `ask` passes heavy JSON objects containing full history through pipes via a magic header.
*   **Pattern:** `ask "Q1" | ask "Follow up Q2"`

### 2. Tool/Extraction Mode (`ask | answer | tool`)
*   **Goal:** Take the result of an LLM and pass it to a shell command (like `python`, `bash`, or `pipetest`).
*   **How it works:** The `answer` command acts as a "Gatekeeper." It consumes the heavy JSON history and transforms it into **Plain Text**, which is what tools require.
*   **Pattern:** `ask "Write python code" | answer | unfence | python`

### 3. Hybrid/Observation Mode (`ask | answer -t | ask`)
*   **Goal:** See what the LLM said in your terminal *while also* preserving the conversation history for the next command.
*   **How it works:** The `--tee` (or `-t`) flag prints the human-readable text to `stderr` but keeps the JSON history flowing through `stdout`.
*   **Pattern:** `ask "Q1" | answer -t | ask "Follow up Q2"`

## Components

* **`ask`**: The producer. In a pipe, it sends the full conversation context with header.  When stdout is a terminal, it further automatically calls `answer` to show you pretty text.
* **`answer`**: The transformer. By default, `answer` consumes the JSON history and outputs raw text to stdout (Tool/Extraction mode). Use `answer --tee` (`-t`) mid-pipeline to send human-readable text to stderr while keeping the JSON history flowing on stdout for the next command.
* **`unfence`**: Extracts code-fence (```) sections from model output.
* **`pipetest`**: Shows a preview of what's about to be executed and asks for `Y/N`.

## Examples

**Chaining questions (Conversation Mode):**
```bash
ask "What is 2+2?" | ask "Now multiply that by 10" | answer
# Output: 20
```

**Running code (Tooling Mode):**
```bash
ask "Write a python script to list files" | answer | unfence | python
```

**Refining with visibility (Hybrid Mode):**
```bash
ask "Generate bash script for logs" | answer -t | ask "Add error handling to it" | answer
# You see the first script on your screen, but 'ask' still knows what was generated.
```

## Key Features

* **Interactive Code Generation:** Prompt the language model with natural language instructions to generate code in various languages.
* **Seamless Execution:**  Execute the generated code within your shell environment.
* **Conversation History:** Maintains a JSON-based conversation history for context and iterative refinement.
* **Simple Scripting:**  Uses a small set of Bash scripts for a lightweight and portable experience.
* **Clean Output:**  `unfence` script to remove code delimiters, ensuring clean and executable code.

## Components

* **`ask`:** The core script.  Accepts a prompt, sends it to the language model, and manages the conversation history (stored as a JSON array). If it ends the CLI line and output it going to a terminal, it automatically appends the `answer`command. Otherwise, in a pipeline, it just passes the JSON conversation array along.
* **`bx`:** Executes the specified command and args, and wraps the result in a bash code fence.
* **`answer`:**  Asks for LLM endpoint for an answer, and outputs the last message to stdout. In a pipeline, stdout is suppressed and only the conversation flows through; however, use `answer --tee`or `answer -t` mid-pipeline to print text to stderr as well as pass JSON through on stdout. With no stdin, extracts the latest message content from the JSON conversation, if available.
* **`tools`:** Pipeline wrapper around `toolex.py`. Reads a JSON conversation array from resolves tool calls via toolex, and writes the updated conversation array to stdout.
* **`unfence`:** Removes code blocks enclosed in triple backticks (```) from the input. Crucial for preparing model output for execution.
* **`story.txt`:**  A comprehensive file containing example usage scenarios, prompts, and expected outputs to help you get started.

## Pipeline Patterns

### Basic question and answer

```bash
ask "Write fib in Python" | answer
```

### Piping command output into a question (use `-i`)

```bash
dmesg | ask -i "Spot any SCSI issues" | answer
```

### Chained follow-up questions

Use `answer --tee` or `answer -t` mid-pipeline so the conversation JSON continues to flow on stdout while the human-readable reply appears on stderr:

```bash
dmesg | ask -i "Spot any SCSI issues" | answer --tee | ask "What can I do about the md0 device?" | answer
```

### Tool-call resolution with toolex

```bash
ask "Spot any SCSI issues with dmesg" | tools linux_tools | answer --tee | ask "What can I do about the md0 device?" | answer
```



## Prerequisites

Before you begin, ensure you have the following installed:

* **OpenAI API Key:**  May be required for accessing the language model.
* **VIA API Access:** Access to a VIA API instance.
* **`jq`:**  A lightweight and flexible command-line JSON processor.  Install via your package manager:
    * **Debian/Ubuntu:** `sudo apt-get install jq`
    * **macOS:** `brew install jq`
    * **Windows:**  Download from [https://stedolan.github.io/jq/download/](https://stedolan.github.io/jq/download/)
* **Python 3:** Needed for executing generated Python code.
* **Bash:** The scripts are written for Bash.



## Setup

1. **Clone the Repository:**

   ```bash
   git clone <repository_url>
   cd answer
   . enable.sh
   ```

2. **Set Environment Variables:**

   ```bash
   export VIA_API_CHAT_BASE="http://localhost:5000"
   ```

   See also `$OPENAI_API_KEY`.

## Usage

The `story.txt` file provides a detailed walkthrough of various use cases.  Here's a basic example to get you started:

```bash
ask write a python function to calculate the factorial of a number | answer | unfence > factorial.py
./python factorial.py
```

**Explanation:**

1.  `ask write a python function to calculate the factorial of a number`:  Sends a prompt to the language model requesting a Python function for factorial calculation.
2.  `answer`: Extracts the generated code from the model's JSON response.
3.  `unfence`:  Removes any surrounding code fences (triple backticks) to ensure valid Python code.
4.  `> factorial.py`:  Saves the cleaned code to a file named `factorial.py`.
5.  `python factorial.py`:  Executes the Python code.

You can combine these commands to build complex workflows.  Explore `story.txt` for more advanced scenarios.

```
## License

This project is licensed under the [MIT License](LICENSE).

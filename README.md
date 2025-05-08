# Answer: A Shell-Based Code Generation & Execution Agent Framework

**Answer** is a command-line agent framework that leverages language models via api and posix pipes to generate, execute, and retrieve the results of code snippets directly from your terminal. It provides a conversational, shell-focused workflow for rapid prototyping and experimentation.

**Example Workflow**

```
    $ ask write fib in python | answer | unblock
    ```python
    def fibonacci(n):
      """
      Calculates the nth Fibonacci number.

      Args:
        n: The index of the Fibonacci number to calculate (non-negative integer).

      Returns:
        The nth Fibonacci number.  Returns n if n is 0 or 1.  Returns -1 if n is negative.
      """

      if n < 0:
        return -1  # Handle negative input
      elif n <= 1:
        return n  # Base cases: F(0) = 0, F(1) = 1
      else:
        # Iterative approach (more efficient)
        a, b = 0, 1
        for _ in range(2, n + 1):
          a, b = b, a + b
        return b

    print(fibonacci(20))
    ```

    $ (ask write fib in python |
      ask call it with 20 and note the output |
      ask just print the output | answer)
    6765

    $ (ask write fib in python |
     ask print just the code ready to execute plus 'print(fib(20))'  |
     answer |
     unfence |
     python)
    6765
    $    
```


## Key Features

* **Interactive Code Generation:** Prompt the language model with natural language instructions to generate code in various languages.
* **Seamless Execution:**  Execute the generated code within your shell environment.
* **Conversation History:** Maintains a JSON-based conversation history for context and iterative refinement.
* **Simple Scripting:**  Uses a small set of Bash scripts for a lightweight and portable experience.
* **Clean Output:**  `unfence` script to remove code delimiters, ensuring clean and executable code.

## Components

* **`ask`:** The core script.  Accepts a prompt, sends it to the language model, and manages the conversation history (stored as a JSON array).
* **`bashblock`:** Executs the specified commnd and args, and wraps the result in a bash code fence.
* **`answer`:**  Extracts the latest message content from the JSON conversation history. Useful for retrieving generated code or responses.
* **`unfence`:** Removes code blocks enclosed in triple backticks (```) from the input. Crucial for preparing model output for execution.
* **`story.txt`:**  A comprehensive file containing example usage scenarios, prompts, and expected outputs to help you get started.



## Prerequisites

Before you begin, ensure you have the following installed:

* **OpenAI API Key:**  Required for accessing the language model.
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
   ```

2. **Set Environment Variables:**

   ```bash
   export VIA_API_CHAT_BASE="http://localhost:5000"
   ```

   See also `$OPENAI_API_KEY`.

## Usage

The `story.txt` file provides a detailed walkthrough of various use cases.  Here's a basic example to get you started:

```bash
./ask write a python function to calculate the factorial of a number | ./answer | ./unfence > factorial.py
./python factorial.py
```

**Explanation:**

1.  `./ask write a python function to calculate the factorial of a number`:  Sends a prompt to the language model requesting a Python function for factorial calculation.
2.  `./answer`: Extracts the generated code from the model's JSON response.
3.  `./unfence`:  Removes any surrounding code fences (triple backticks) to ensure valid Python code.
4.  `> factorial.py`:  Saves the cleaned code to a file named `factorial.py`.
5.  `./python factorial.py`:  Executes the Python code.

You can combine these commands to build complex workflows.  Explore `story.txt` for more advanced scenarios.

# Colophon
How this README was created:

```bash
( bashblock cat story.txt; bashblock cat ask; bashblock cat answer; bashblock cat unfence) |
  ./ask -i Read this code: | \
  ./ask Write a README.md file for this new 'answer' github project.  | \
  ./answer | \
  ./ask -i "Re-write this README file to be really good:" | \
  ./answer > README.md
```

## License

This project is licensed under the [MIT License](LICENSE).

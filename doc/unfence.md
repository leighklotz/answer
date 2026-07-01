### Usage

The `unfence` script extracts the first Markdown code block (delimited by ` ``` `) from a text stream. It is designed to process LLM outputs, ensuring that only the code—and not the conversational text—is passed through to the next command.

#### Key Features
* **Magic Header Resolution:** If the input starts with the sequence defined in `PIPELINE_MAGIC_HEADER`, the script automatically resolves the content using the `answer` command before extraction.
* **Automatic Extraction:** Uses `awk` to isolate exactly the first fenced code block found in the input.
* **Smart Paging:** Displays the extracted code in a pager sent to `stderr` for easy previewing. It prioritizes `batcat`, then `bat`, and finally `cat`.
* **Confirmation:** To prevent accidental execution of malicious or incorrect code, the script requires manual confirmation via a prompt sent to the terminal (`/dev/tty`).

#### Basic Pipe Usage
Pipe the output of a command into the script to preview the code before it is sent to `stdout`.

```bash
# Example: Extracting code from an ASK command
🦶$ ask "Write a python script to list files" | unfence
💭
from pathlib import Path

def list_files_simple(directory="."):
    path = Path(directory)
    
    print(f"Listing files in: {path.absolute()}")
    
    # .iterdir() loops through everything in the directory
    for item in path.iterdir():
        if item.is_file():
            print(f"FILE: {item.name}")
        elif item.is_dir():
            print(f"DIR : {item.name}")

# Run the function
list_files_simple(".")
🦶$ 

# Example: Extracting code from a stored markdown file
🦶$ cat response.md | unfence
echo 'Hello, World!'
```

#### Interactive Confirmation
Because the script reads confirmation from `/dev/tty`, it will prompt you even when used in a pipeline:
`🤖 Proceed with this command? (y/N):`

* **Press `y`:** The code is printed to `stdout`.
* **Press any other key (or Enter):** The code is discarded, and the script exits.

The script is most commonly used as an intermediary to safely pipe code into a shell:

```bash
# Preview the command in a pager, then execute it if confirmed
🦶$ ask "Give me a one-liner to check disk usage" | unfence | bash
|---|---|
|1│df -h|
|---|---|
🤖 Proceed with this command? (y/N): y
Filesystem      Size  Used Avail Use% Mounted on
/dev/nvme1n1p2  3.6T  3.3T  202G  95% /
🦶$ 
```

#### Environment Variables
| Variable | Description |
| :--- | :--- |
| `PIPELINE_MAGIC_HEADER` | The string used to identify input that needs resolution via the `answer` command. |
| `PIPETEST_PAGER` | Allows you to override the default pager detection. |


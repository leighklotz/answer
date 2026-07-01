# NAME
    ask - A shell-based LLM agent framework for composing agentic pipelines.

# SYNOPSIS
    ask [-i|--input] [--use-system-message] [--tee|-t] [prompt]

# DESCRIPTION
    `ask` is a command-line agent framework that uses Posix pipes to compose and 
    execute nonce agentic pipelines. It manages conversation states by passing 
    JSON-formatted history through pipes, allowing seamless transitions between 
    conversational "thinking" and terminal "doing."

# OPTIONS
    -i, --input
        Treats the input as plain text. Used primarily when piping data into 
        `ask` to ensure the prompt is handled correctly.

    --use-system-message
        If set, prepends the contents of the `$SYSTEM_MESSAGE` environment 
        variable to the conversation history.

    -t, --tee (Hybrid/Observation Mode)
        Resolves the current turn and prints the human-readable response to 
        `stderr`, while forwarding the full conversation JSON history to `stdout`. 
        This allows you to see the result in the terminal while continuing the 
        pipeline.

    [prompt]
        The user query string. If omitted, `ask` reads from `stdin`.

# MODES OF OPERATION
    1. Conversation Mode (`ask | ask`)
       Appends new prompts to the existing JSON conversation history passed through the pipe.

    2. Tool/Extraction Mode (`ask | answer`)
       Uses the `answer` command as a "Cut-Point" to strip JSON envelopes and 
       output pristine, plain-text Markdown for use with standard shell utilities.

    3. Hybrid Mode (`ask -t | ask`)
       Allows visual observation of the LLM's response (via `stderr`) while 
       preserving the stateful JSON history in the pipeline (`stdout`).

# EXAMPLES
    # Basic question and answer (Text output)
    ask "What is 2+2?" | answer

    # Piping file content into a prompt
    cat script.py | ask -i "Refactor this for performance" | answer

    # Chained conversation (Maintaining context)
    ask "Who is the president of France?" | ask "How old is he?" | answer

    # Hybrid mode (See output, but keep history for next step)
    ask -t "Write a bash script to list files" | ask "Add error handling" | answer

    # Full execution pipeline
    ask "Generate a python script to fetch weather" | answer | unfence | python

# ENVIRONMENT VARIABLES
    VIA_API_CHAT_BASE
        The base URL for the OpenAI-compatible inference API.
    OPENAI_API_KEY
        The API key for authentication.
    VIA_MODEL
        The model to use for inference (defaults to gpt-3.5-turbo).
    ENABLE_THINKING
        Boolean to enable "thinking" capabilities if supported by the model.

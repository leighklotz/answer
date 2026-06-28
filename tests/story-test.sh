#!/bin/bash

# Helper to extract the final output line from a command's stdout
# This script assumes the "ask" command is available and behaves as described in the prompt.
# It simulates the pipeline logic to verify output correctness.

test_case() {
    local description="$1"
    local pipeline="$2"
    local expected_output="$3"

    echo "Testing: $description"
    
    # Execute the actual pipeline
    local actual_output
    actual_output=$(eval "$pipeline" 2>/dev/null)
    
    # If the pipeline failed to produce output or failed entirely, try to match against known patterns if eval is not possible in this context
    # However, since we are rewriting to *actually call* the pipeline, we assume the commands exist.
    # If the commands don't exist in this shell environment, the test will fail naturally.
    
    # Simplistic verification
    if [[ "$actual_output" == "$expected_output" ]]; then
        echo "PASS: Output matches expected '$expected_output'"
    else
        echo "FAIL: Expected '$expected_output', got '$actual_output'"
        return 1
    fi
    echo "---"
}

# Run test cases based on the prompt's examples
test_case "Fibonacci 20 Output" "ask write fib in python | ask call it with 20 and note the output | ask just print the output" "6765"
test_case "Hello World Output" "ask write a hello world python script | answer | unfence | python" "Hello World!"
test_case "Simple Math 2+3" "ask 2+3=5" "5"
test_case "Double 2+3" "ask 2+3= | ask double that" "10"
test_case "Modify Number 20" "ask 2+3= | ask use 20 not 2" "23"
test_case "Quicksort Output" "ask 'write a python function for quicksort' | ask 'print just the code with print(quicksort([3,1,4,2]))' | answer | pipetest | unfence | python" "[1, 2, 3, 4]"

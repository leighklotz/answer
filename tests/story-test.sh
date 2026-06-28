#!/bin/bash

function test_case() {
    local description="$1"
    local actual_output="$2"
    local expected_output="$3"

    echo "Testing: $description"
    
    # Remove a single leading newline if present
    actual_output="${actual_output#$'\n'}"

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
test_case 'Fibonacci 20 Output' "$(ask write fib in python and a call to it with 20 | ask just print the functio and call in one codefence | answer | unfence | python)" '6765'
test_case 'Hello World Output' "$(ask write a 'Hello, World!' python script and output just the one codefence | answer | unfence | python)" 'Hello, World!'
test_case 'Simple Math 2+3' "$(ask 2+3= | answer)" '5'
test_case 'Double 2+3' "$(ask 2+3= | ask double that and output just the result | answer)" '10'
test_case 'Modify Number 20' "$(ask 2+3= | ask use 20 not 2 and output just the result | answer)" '23'
test_case 'Quicksort Output' "$(ask write a python function for quicksort | ask 'output just the python code and call `print(quicksort([3,1,4,2]))`' | answer | unfence | python)" '[1, 2, 3, 4]'

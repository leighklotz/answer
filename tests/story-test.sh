#!/usr/bin/env bash

export ENABLE_THINKING=false

failures=0

function test_case() {
    local description="$1"
    local actual_output="$2"
    local expected_output="$3"

    echo "Testing: $description"

    if [[ "$actual_output" == "$expected_output" ]]; then
        echo "PASS: Output matches expected '$expected_output'"
    else
        echo "FAIL: Expected '$expected_output', got '$actual_output'"
        echo "---"
        return 1
    fi

    echo "---"
}

function run_test() {
    if ! test_case "$@"; then
        failures=$((failures + 1))
    fi
}

# Run test cases based on the prompt's examples.
# When a prompt asks for a codefence, strip the fence before comparing or executing.

# ask.sh lines 71-75 (no-stdin prompt), 100-103 (pipe stdout); two-step pipeline exercises lines 38-65 (history handling)
run_test 'Fibonacci 20 Output' "$(ask 'write fib(n:int):int in python and a call to it with 20' | ask just print the output in one codefence | answer | unfence | python)" '6765'
# ask.sh lines 71-75 (no-stdin prompt), 96-99 (terminal stdout via answer)
run_test 'Hello World Output' "$(ask write a 'Hello, World!' python script and output just the one codefence | answer | unfence | python)" 'Hello, World!'
# ask.sh lines 71-75 (no-stdin prompt), 100-103 (pipe stdout); second ask exercises lines 38-65 (history handling)
run_test 'Simple Math 2+3' "$(ask 2+3= | ask just the answer | answer)" '5'
# ask.sh lines 71-75, 38-65 (history handling), 100-103 (pipe stdout)
run_test 'Double 2+3' "$(ask 2+3= | ask double that and output just the number | answer)" '10'
# Non-deterministic: LLM may return '23' or '20 + 3 = 23' depending on model response.
# run_test 'Modify Number 20' "$(ask 2+3= | ask use 20 not 2 and output just the result | answer)" '23'
# ask.sh lines 71-75 (no-stdin prompt), 38-65 (history handling), 100-103 (pipe stdout)
run_test 'Quicksort Output' "$(ask write a python function for quicksort | ask 'output just the python code and call `print(quicksort([3,1,4,2]))`' | answer | unfence | python)" '[1, 2, 3, 4]'

if (( failures > 0 )); then
    echo "$failures test(s) failed."
    exit 1
fi

echo "All tests passed."

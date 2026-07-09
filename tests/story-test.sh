#!/usr/bin/env bash

TEST_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"

cd "${TEST_DIR}"
source "../bin/logging.sh"
source "../bin/commands/enable"

export ENABLE_THINKING=false

failures=0

INFO=1g

echo "Checking scripts"
for cmd in answer ask bx help-commit help tools unfence;
do
  printf "%s = %s\n" "$cmd" "$(type -t "$cmd")"
done


function test_case() {
    local description="$1"
    local actual_output="$2"
    local expected_output="$3"

    echo "Testing: $description"

    if [[ "$actual_output" == "$expected_output" ]]; then
        log_info "PASS: Output matches expected '$expected_output'"
    else
        log_error "FAIL: Expected '$expected_output', got '$actual_output'"
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

run_test 'Fibonacci 20 Python Output' "$(ask 'write fib(n:int):int function python and a call to it with 20 in one codefence' | unfence | python)" '6765'

run_test 'Hello World Python Output' "$(ask "write a 'Hello, World!' python script and output just script in one codefence" | unfence | python)" 'Hello, World!'

run_test 'Complex Tool Chain' "$(ask 'evaluate 2+3 in a bash oneliner in a codefence' | unfence | bash)" "5"



run_test 'Simple Math 2+3' "$(ask what is 2+3= | ask output just the answer | answer)" '5'

run_test 'Double 2+3' "$(ask 2+3= | ask double that and output just the number | answer)" '10'

run_test 'Bash math 2+3' "$(ask 2+3= | ask in a bash one-liner | unfence | bash)" '5'

run_test "ask ask" "$(ask 20+30= | ask output a single bash one-liner in a codefence  | ask now change it to octal | unfence |bash)" "62"

run_test 'Quicksort Python Output' "$(ask write a python function for quicksort | ask 'output just the python code and call `print(quicksort([3,1,4,2]))`' | unfence | python)" '[1, 2, 3, 4]'

if (( failures > 0 )); then
    echo "$failures test(s) failed."
    exit 1
fi

#


echo "All tests passed."

#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/../env.sh"
source "${SCRIPT_DIR}/../logging.sh"

source "${SCRIPT_DIR}/hx-bootstrap.sh"

hx core

hx cache enable
cd "$(hx cache show)" | tee | || log_and_exit 1 "cannot find .cache"
hx cache disable

for file in *.json; do
    echo -n "$file" >&2
    if [[ ! -f "${file%.json}.md" ]]; then
        (echo -n "# ";
         hx what - < "$file" | ask give this hallux response a concise title | answer;
         echo ""
         hx what - < "$file") > "${file%.json}.md"
    else
        echo -n " [existing]: "
    fi
    head -1 "${file%.json}.md"
done

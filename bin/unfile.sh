#!/bin/bash

# Extracts specified filename from markdown archive from stdin to stdout
# Check if filename to extract argument is provided

if [ $# -ne 1 ]; then
    echo "extracts specified file from markdown archive to stdout" >&2
    echo "Usage: $0 <filename>" >&2
    exit 1
fi

awk -v target_file="$1" '
BEGIN { in_fence = 0; want = 0 }

!in_fence && /^#[[:space:]]+/ {
    marker = $0
    sub(/^#[[:space:]]+/, "", marker)   # strip heading prefix
    sub(/[[:space:]]+$/, "", marker)    # trim trailing spaces
    want = (marker == target_file)
    next
}

/^```/ {
    if (!in_fence) {
        in_fence = 1
        buf = ""
    } else {
        in_fence = 0
        if (want) {
            printf "%s", buf
        }
        want = 0
    }
    next
}

in_fence {
    buf = buf $0 ORS
}
'

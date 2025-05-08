#!/bin/bash -e

# extract content, usually code, between triple-backquotes
# opposite of codeblock.sh

# Buffer stdin; if there are no code fences in stdin, print it out unchanged.
# This version handles stdin buffering and prints un-fenced input.

awk '
BEGIN {
  buffered_input = ""
}
{
  buffered_input = buffered_input $0 "\n"
}
END {
  line = buffered_input
  in_block = 0
  while (match(line, /```/)) {
    if (!in_block) {
      # Opening fence: ignore any text on this line.
      in_block = 1
      line = substr(line, RSTART + 3) # Skip "```"
      break
    } else {
      # Closing fence: print any text that appears before the fence.
      code = substr(line, 1, RSTART - 1)
      if (length(code) > 0)
        print code
      in_block = 0
      line = substr(line, RSTART + 3) # Skip "```"
    }
  }
  # If still inside a code block or if there was no block, print any remaining text
  if (in_block && length(line) > 0)
    print line
  else if (!in_block && length(buffered_input) > 0) {
    # No code fences found, print the entire buffered input.
    print buffered_input
  }
}
' "$@"

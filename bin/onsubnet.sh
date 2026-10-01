#!/usr/bin/env bash

# --- Argument Parsing & Help ---
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]  || [[ -z "$1" ]]; then
  printf "Usage:\n\tonsubnet [ --not ] partial-ip-address\n\n"
  printf "Example:\n\tonsubnet 10.10.\n\tonsubnet --not 192.168.0.\n\n"
  printf "Note:\n\tThe partial-ip-address must match starting at the first\n"
  printf "\tcharacter of the ip-address (e.g., '10.1.' matches '10.1.5.2').\n"
  exit 0
fi

# --- Logic Configuration ---
on=0   # Exit code if match is found (normal behavior)
off=1  # Exit code if no match is found (normal behavior)

if [[ "$1" == "--not" ]] ; then
  shift            # Remove '--not' from the argument list so $1 becomes the IP pattern
  on=1             # Invert: exit with error (non-zero) if matched
  off=0            # Invert: exit with success (zero) if not matched
fi

# The target subnet/pattern passed by user
PATTERN=$1

# Escape dots in the input pattern so they are treated as literal dots in regex 
# e.g., "10.1." becomes "^10\.1\."
REGEXP="^$(echo "$PATTERN" | sed 's/\./\\./g')"

found=false

# --- Data Acquisition & Comparison ---
# We use a subshell to get the list of IPs and pipe them into a while loop. 
# This solves "The Blob Problem" because 'read' processes one line at a time.

if [[ "$(uname)" == "Darwin" ]] ; then
  # macOS: Use ifconfig, filter for inet (IPv4), ignore loopback, strip trailing info
  get_ips() {
    ifconfig | grep -F 'inet ' | grep -vw 127.0.0.1 | awk '{print $2}'
  }
else
  # Linux: Use ip addr show (modern standard), extract IP part before the '/' slash
  get_ips() {
    ip -4 addr show 2>/dev/null | awk '/inet / {split($2,a,"/"); print a[1]}' || hostname -I
  }
fi

# Loop through every line provided by our get_ips function
while read -r ip; do
  if [[ $ip =~ $REGEXP ]]; then
    found=true
    break # Stop looking once we find one match
  fi
done < <(get_ips)

# --- Final Exit Logic ---
if [ "$found" = true ]; then
  exit $on
else
  exit $off
fi

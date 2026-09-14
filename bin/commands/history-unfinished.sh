#!/bin/bash

# Script to list unfinished bash history sessions from specified path
# Usage: history_script.sh [-d DATE] [-p|--project] [-h|--help]
# Options:
#   -d DATE      Date to filter (default: today, e.g., 'Sep 13' or 'YYYY-MM-DD')
#   -p           Use project-specific .bash_history path (default: all bash history)
#   -h           Show this help

# Parse command-line options
date_str=""
path_flag="all"
while getopts "d:p:h" opt; do
    case "$opt" in
        d) date_str="$OPTARG" ;;
        p) path_flag="project" ;;
        h) echo "$0: Usage: $0 [-d DATE] [-p|--project] [-h|--help]" >&2; exit 0 ;;
        *) echo "$0: Invalid option" >&2; exit 1 ;;
    esac
done

# Convert provided date to YYYY-MM-DD format
if [[ -n "$date_str" ]]; then
    # Parse the date string
    parsed_date=$(date -d "$date_str" "+%Y-%m-%d")
    if [[ $? -ne 0 ]]; then
        echo "Invalid date format: $date_str. Use 'Sep 13' or 'YYYY-MM-DD'" >&2
        exit 1
    fi
    date_str="$parsed_date"
else
    # Default to today
    date_str=$(date +%Y-%m-%d)
fi

# Determine the path to search for .bash_history files
case "$path_flag" in
    project)
        # Project-specific path (requires 'hx' command to get root)
        project_path=$(hx root)/.bash_history
        if [[ -d "$project_path" ]]; then
            path="$project_path"
        else
            echo "Project path not found: $project_path" >&2
            exit 1
        fi
        ;;
    all)
        # All bash history in home directory
        path="$HOME"
        ;;
    *)
        echo "Invalid path flag: $path_flag" >&2
        exit 1
        ;;
esac

# Find all .bash_history files in the specified path modified on the given date
files=()
while IFS= read -r file; do
    files+=("$file")
done < <(
    find "$path" -name "*.bash_history" -newermt "$date_str" -not -newermt "$date_str" | sort -r
)

# If no files found, exit
if [[ ${#files[@]} -eq 0 ]]; then
    echo "No .bash_history files found for date $date_str in $path." >&2
    exit 0
fi

# Process each file to generate markdown table
echo "| Date/Time (PDT) | Filename | Title | Notes |"
for file in "${files[@]}"; do
    # Get modification time in PDT
    mod_time=$(date -r "$file" +"%Y-%m-%d %H:%M:%S")
    # For simplicity, assume system timezone is PDT; adjust if needed
    time_pdt="$mod_time"
    
    # Extract title from the first line (e.g., if it's a session name)
    title=$(head -n 1 "$file" | tr -d '\n')
    
    # Check for unfinished work (example: presence of 'unfinished' or 'incomplete')
    if grep -E 'unfinished|incomplete' "$file" > /dev/null; then
        note="Unfinished work detected"
    else
        note=""
    fi
    
    # Format for markdown table with proper escaping
    echo "| $time_pdt | $file | $title | $note |"
done | glow -t --width 200

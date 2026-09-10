# Ghostty OSC 8 Mouseover Protocol Configuration

# External protocol variables defining the OSC 8 hyperlink boundaries.
# Ghostty interprets the destination parameter string as visual tooltip text.
OSC8_START=$'\e]8;;'
OSC8_DIV=$'\e\\'
OSC8_CLOSE=$'\e]8;;\e\\'

# Formats and routes a mouseover tooltip sequence strictly to stderr (Descriptor 2).
# Ensures the primary stdout data stream remains completely clean.
#
# Arguments:
#   $1 - The descriptive text hidden inside the hover state
#   $2 - The visible text or icon printed directly to the terminal grid
#
# Usage: 
#   log_stderr_tooltip "Diagnostic metadata" "⚠️ Warning"
function log_stderr_tooltip() {
    local tooltip_text="$1"
    local visible_text="$2"
    
    # Sanitize inputs by stripping out double or single quotes that could
    # prematurely break or corrupt the escape parameter boundaries.
    tooltip_text="${tooltip_text//[\'\"]/}"
    
    # Write the compiled sequence directly to stderr using descriptor routing
    printf "%s%s%s%s%s\n" \
        "${OSC8_START}" \
        "${tooltip_text}" \
        "${OSC8_DIV}" \
        "${visible_text}" \
        "${OSC8_CLOSE}" >&2
}


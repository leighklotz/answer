# Proposed Changes: Image Injection via `ix.sh`

## Design Overview

`ix.sh` follows the same pipeline philosophy as `lx` (file context) and `bx` (command output), but targets **binary image data**. It base64-encodes images and emits structured blocks that `ask` recognizes and converts into the OpenAI-compatible **multimodal content array** format:

```json
{"role":"user","content":[
  {"type":"text","text":"What's in this image?"},
  {"type":"image_url","image_url":{"url":"data:image/png;base64,iVBOR..."}}
]}
```

### Usage patterns

```bash
# Single image as context
ix screenshot.png | ask "What's in this image?"

# Multiple images
ix photo1.png photo2.png | ask "Compare these two"

# Mixed with text context (lx)
{ lx main.py; ix diagram.png; } | ask "Explain the code and the architecture diagram"

# Mid-pipeline (extending a conversation)
ask "Describe the architecture" | ix diagram.png | ask "Now add the DB layer"

# From a file list
find . -name '*.png' | ix | ask "Summarize all these images"
```

---

## 1. New file: `bin/ix.sh`

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/logging.sh"

set -euo pipefail

# ix.sh – inject image files into the hallux pipeline as multimodal content.
# Mirrors lx.sh for text files; output is structured blocks that ask.sh
# parses and converts into OpenAI-compatible multimodal content parts.
#
# Output format per image:
#   # image <filename>
#   <base64-encoded data (single line, no wrapping)>
#   ---

declare -A mime_map=(
  [png]=image/png
  [jpg]=image/jpeg
  [jpeg]=image/jpeg
  [gif]=image/gif
  [webp]=image/webp
  [bmp]=image/bmp
  [tiff]=image/tiff
  [tif]=image/tiff
  [svg]=image/svg+xml
  [avif]=image/avif
  [ico]=image/x-icon
)

usage() {
  cat <<'EOF'
Usage: ix.sh [files...]
Reads image file paths from args and/or stdin (one per line).
Base64-encodes each image and prints structured blocks for ask to parse.
Non-image files are skipped with a warning on stderr.
EOF
}

files=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *) files+=("$1"); shift ;;
  esac
done

# Collect additional paths from stdin (one per line)
if [ ! -t 0 ]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && files+=("$line")
  done
fi

if [ ${#files[@]} -eq 0 ]; then
  echo "ix: provide one or more image file paths via args or stdin" >&2
  exit 1
fi

for f in "${files[@]}"; do
  [[ -z "$f" ]] && continue

  if [[ ! -e "$f" ]]; then
    echo "ix: $f: no such file" >&2
    exit 1
  fi
  if [[ ! -f "$f" ]]; then
    echo "ix: $f is not a regular file; skipping" >&2
    continue
  fi
  if [[ ! -r "$f" ]]; then
    echo "ix: cannot read $f" >&2
    continue
  fi

  # Determine MIME type (extension first, then `file` fallback)
  mime=""
  if [[ "$f" == *.* && -n "${f##*.}" ]]; then
    ext="${f##*.}"
    ext="$(tr '[:upper:]' '[:lower:]' <<<"$ext")"
    mime="${mime_map[$ext]:-}"
  fi
  if [[ -z "$mime" ]] && command -v file &>/dev/null; then
    mime="$(file --brief --mime-type -- "$f" 2>/dev/null)"
  fi
  if [[ -z "$mime" ]]; then
    mime="application/octet-stream"
  fi

  # Gate: only accept image/* types
  if [[ "$mime" != image/* ]]; then
    echo "ix: $f: not an image (detected: $mime); skipping" >&2
    continue
  fi

  # Emit structured block
  printf '# image %s\n' "$f"
  _base64_encode < "$f"
  printf '\n---\n'

  printf '%s' "${IMAGE_ICON}" >&2
done
```

---

## 2. Changes to `bin/functions.sh`

Append the following functions at the end of the file (before the closing or after `_strip_markdown_fence`):

```bash
# --- IMAGE / MULTIMODAL HELPERS ---

# Cross-platform base64 encode (single line, no wrapping). Reads from stdin.
function _base64_encode() {
  if base64 --version &>/dev/null 2>&1; then
    # GNU coreutils
    base64 -w 0
  else
    # macOS / BSD
    base64 | tr -d '\n'
  fi
}

# Detect MIME type of an image file by extension, falling back to `file`.
# Returns empty string if not an image.
function _detect_image_mime() {
  local f="$1"
  local ext mime=""

  declare -A _ix_mimes=(
    [png]=image/png [jpg]=image/jpeg [jpeg]=image/jpeg
    [gif]=image/gif [webp]=image/webp [bmp]=image/bmp
    [tiff]=image/tiff [tif]=image/tiff [svg]=image/svg+xml
    [avif]=image/avif [ico]=image/x-icon
  )

  if [[ "$f" == *.* && -n "${f##*.}" ]]; then
    ext="${f##*.}"
    ext="$(tr '[:upper:]' '[:lower:]' <<<"$ext")"
    mime="${_ix_mimes[$ext]:-}"
  fi

  if [[ -z "$mime" ]] && command -v file &>/dev/null; then
    mime="$(file --brief --mime-type -- "$f" 2>/dev/null)"
  fi

  # Only return if it looks like an image
  if [[ "$mime" == image/* ]]; then
    printf '%s' "$mime"
  else
    return 1
  fi
}

# Check whether a stdin temp file contains any `# image` blocks.
# Returns 0 (true) if at least one image block is present.
function _stdin_has_images() {
  local file="$1"
  grep -q '^# image ' "$file" 2>/dev/null
}

# Parse a stdin temp file that may contain a mix of text (from lx/raw) and
# `# image` blocks (from ix). Outputs a JSON array of multimodal content parts:
#   [{"type":"text","text":"..."},
#    {"type":"image_url","image_url":{"url":"data:image/png;base64,..."}},
#    {"type":"text","text":"..."}]
#
# If no image blocks are found, outputs a JSON string (the raw text),
# so callers can fall back to the plain-text path.
function _build_multimodal_content() {
  local file="$1"
  local parts="[]"
  local text_buf=""
  local in_image=0
  local img_file=""
  local img_data=""
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ $in_image -eq 1 ]]; then
      if [[ "$line" == "---" ]]; then
        # Flush image part
        local mime
        if mime=$(_detect_image_mime "$img_file"); then
          parts=$(jq -c \
            --arg u "data:${mime};base64,${img_data}" \
            '. + [{type: "image_url", image_url: {url: $u}}]' \
            <<< "$parts")
        fi
        in_image=0
        img_file=""
        img_data=""
      else
        img_data+="$line"
      fi
    else
      if [[ "$line" == "# image " ]]; then
        # Flush pending text before starting image block
        if [[ -n "$text_buf" ]]; then
          parts=$(jq -c --arg t "$text_buf" \
            '. + [{type: "text", text: $t}]' <<< "$parts")
          text_buf=""
        fi
        in_image=1
        img_file="${line#'# image '}"
        img_data=""
      else
        text_buf+="${line}"$'\n'
      fi
    fi
  done < "$file"

  # Flush trailing text
  if [[ -n "$text_buf" ]]; then
    text_buf="${text_buf%$'\n'}"
    parts=$(jq -c --arg t "$text_buf" \
      '. + [{type: "text", text: $t}]' <<< "$parts")
  fi

  # If the array has zero parts (empty stdin), emit an empty string
  local len
  len=$(jq 'length' <<< "$parts")
  if [[ "$len" -eq 0 ]]; then
    printf ''
  elif [[ "$len" -eq 1 && "$(jq '.[0].type' <<< "$parts" | tr -d '"')" == "text" ]]; then
    # Single text part only – emit as plain JSON string for backward compat
    jq -r '.[0].text' <<< "$parts"
  else
    printf '%s' "$parts"
  fi
}
```

---

## 3. Changes to `bin/ask.sh`

Replace the **INPUT HANDLING & HISTORY BUILDING** section (the block from `if [[ "$PLAIN_INPUT" == "1" ]]; then` through the final `else / exit 1 / fi`) with the following:

```bash
  if [[ "$PLAIN_INPUT" == "1" ]]; then
      # MODE: Plain Input / Attachment
      if _stdin_has_images "$stdin_tmp"; then
        log_debug "MODE: Attachment (multimodal)"
        content_parts=$(_build_multimodal_content "$stdin_tmp")
        # content_parts is either a JSON array or a plain string
        if [[ "$content_parts" == \[* ]]; then
          messages=$(jq -n \
            --arg p "$prompt" \
            --argjson parts "$content_parts" \
            '[{role: "user", content: ([{type:"text", text: $p}] + $parts)}]')
        else
          messages=$(jq -n \
            --arg p "$prompt" \
            --arg c "$content_parts" \
            '[{role: "user", content: ($p + $PLAIN_INPUT_ATTACHMENT_SEPARATOR + $c)}]')
        fi
      else
        messages=$(jq -n \
                      --arg p "$prompt" \
                      --rawfile c "$stdin_tmp" \
                      --arg separator "$PLAIN_INPUT_ATTACHMENT_SEPARATOR" \
                      '[{role: "user", content: ($p + $separator + $c)}]')
      fi

  elif [[ "$is_history" == true ]]; then
    # MODE: Conversation History (JSON) – unchanged
    _mktemp_reg "ask.XXXXXX.json" && clean_stdin_tmp="$MKTEMP_REG"
    tail -n +2 "$stdin_tmp" > "$clean_stdin_tmp"

    log_debug "TEE_MODE=$TEE_MODE resolving incoming history"
    if ! clean_stdin=$(_infer < "$clean_stdin_tmp"); then
      log_and_exit 1 "Inference failed while resolving prior conversation state."
    fi

    if ! jq -e '.' <<< "$clean_stdin" >/dev/null 2>&1; then
        log_and_exit 1 "$0: infer returned invalid JSON."
    fi

    if [[ -n "$prompt" ]]; then
      new_msg=$(jq -n --arg p "$prompt" '{"role":"user","content":$p}')
      messages=$(jq -n -c --argjson n "$new_msg" --argjson h "$clean_stdin" '$h + [$n]' 2>/dev/null)
      if [[ -z "$messages" ]] || ! jq -e '.' <<< "$messages" >/dev/null 2>&1; then
        log_and_exit 1 "Failed to merge new prompt into conversation history."
      fi
    else
      messages="$clean_stdin"
    fi

  elif [[ -n "$prompt" ]]; then
    if _stdin_has_images "$stdin_tmp"; then
      log_debug "MODE: Prompt + Piped Content (multimodal)"
      content_parts=$(_build_multimodal_content "$stdin_tmp")
      if [[ "$content_parts" == \[* ]]; then
        messages=$(jq -n \
          --arg p "$prompt" \
          --argjson parts "$content_parts" \
          '[{role: "user", content: ([{type:"text", text: $p}] + $parts)}]')
      else
        messages=$(jq -n \
          --arg p "$prompt" \
          --arg c "$content_parts" \
          '[{role: "user", content: ($p + "\n\nCONTEXT:\n" + $c)}]')
      fi
    else
      log_debug "MODE: Prompt + Piped Content"
      messages=$(jq -n --arg p "$prompt" --rawfile c "$stdin_tmp" \
        '[{role:"user", content: ($p + "\n\nCONTEXT:\n" + $c)}]')
    fi

  else
    if _stdin_has_images "$stdin_tmp"; then
      log_debug "MODE: Only Piped Content (multimodal)"
      content_parts=$(_build_multimodal_content "$stdin_tmp")
      if [[ "$content_parts" == \[* ]]; then
        messages=$(jq -n --argjson parts "$content_parts" \
          '[{role: "user", content: $parts}]')
      else
        messages=$(jq -n --arg c "$content_parts" \
          '[{role: "user", content: $c}]')
      fi
    else
      log_debug "MODE: Only Piped Content"
      messages=$(jq -n --rawfile c "$stdin_tmp" '[{role:"user", content: $c}]')
    fi
  fi
```

> **Key design choice:** The multimodal path is only activated when `_stdin_has_images` returns true. All existing plain-text behaviour is untouched, preserving backward compatibility.

---

## 4. Changes to `bin/answer.sh`

Update the assistant-text extraction to handle both string and array (multimodal) content shapes:

```bash
# Replace the single-line extraction with:
assistant_text=$(jq -r '
  .[-1].content
  | if type == "array" then
      [ .[] | select(.type == "text") | .text ] | join("")
    else
      tostring
    end
  // empty
' <<< "$resolved_history")
```

This ensures that if (in a future edge case) the assistant's content comes back as a content array, we still extract the text portions cleanly.

---

## 5. Changes to `bin/env.sh` (or wherever icons are defined)

Add the image icon alongside the existing ones:

```bash
IMAGE_ICON="${IMAGE_ICON:-🖼️}"
```

---

## 6. Changes to `HALLUX.md`

### In the command table (§1), add a row:

| Command | Primary Purpose | Main Args | Input Type | Output Type (stdout) |
| :--- | :--- | :--- | :--- | :--- |
| `ix <files>` | Injects one or more images into the pipeline as multimodal content. | Image file paths (args and/or stdin, one per line) | Image files on disk | Structured `# image` blocks (base64) for `ask` to parse |

### In §2 (Context Ingestion & Data Tools), add:

*   **`ix <files>`:** Streams one or more image files into the pipeline as base64-encoded blocks. Each block is prefixed with `# image <filename>`, followed by a single line of base64 data, and terminated by `---`. When `ask` detects these blocks in its stdin, it automatically switches to **multimodal content-array mode**, producing the `image_url` content parts required by vision-capable LLM APIs.

### In §3 or a new subsection, document multimodal usage:

### D. Multimodal Image Injection (`ix`)
*   `ix` and `lx` are composable: `{ lx main.py; ix diagram.png; } | ask "..."` sends both text context and an image in a single user message.
*   The multimodal path is transparent – `ask`'s `--tee`, `--answer`, and pipeline modes all work identically; the only difference is the internal message shape (content array vs. plain string).
*   `ix` validates that files are regular, readable images (MIME gate). Non-image files produce a stderr warning and are skipped.

---

## 7. New doc file: `doc/commands/ix.md`

```markdown
# ix

**ix** is the image-injection counterpart to `lx` (text files) and `bx` (command output). It base64-encodes one or more image files and emits structured blocks that `ask` parses into the OpenAI-compatible **multimodal content array** format, enabling vision-capable models to "see" images in the pipeline.

## Synopsis

```bash
ix [files...]
# or
find . -name '*.png' | ix
```

## Description

`ix` reads image file paths from its arguments and/or stdin (one path per line). For each valid image it:

1. Determines the MIME type (extension → `file` fallback).
2. Base64-encodes the file contents (single line, no wrapping).
3. Emits a structured block:
   ```
   # image <filename>
   <base64 data>
   ---
   ```
4. Prints a 🖼️ status icon to stderr.

Non-image files (MIME not `image/*`) are skipped with a warning.

### Interaction with `ask`

When `ask` reads its stdin and detects one or more `# image` blocks, it switches from the plain-string content path to the **multimodal content array** path:

```json
{
  "role": "user",
  "content": [
    {"type": "text", "text": "What's in this image?"},
    {"type": "image_url", "image_url": {"url": "data:image/png;base64,iVBOR..."}}
  ]
}
```

This is the standard OpenAI / VLM multimodal format. If no image blocks are present, `ask` uses the original plain-string content (full backward compatibility).

## Options

| Flag | Description |
|------|-------------|
| `--help` | Print usage and exit. |

No other flags are currently supported. Paths may come from positional args and/or stdin (one per line).

## Supported Image Formats

Determined by extension (case-insensitive) with `file(1)` fallback:

| Extension | MIME |
|-----------|------|
| `.png` | `image/png` |
| `.jpg`, `.jpeg` | `image/jpeg` |
| `.gif` | `image/gif` |
| `.webp` | `image/webp` |
| `.bmp` | `image/bmp` |
| `.tiff`, `.tif` | `image/tiff` |
| `.svg` | `image/svg+xml` |
| `.avif` | `image/avif` |
| `.ico` | `image/x-icon` |

## Examples

**1. Single image, interactive**
```bash
$ ix screenshot.png | ask "What error is shown in this terminal?"
🖼️✨
The terminal shows a `ConnectionRefusedError` on port 5432...
```

**2. Multiple images for comparison**
```bash
$ ix before.png after.png | ask "What changed between these two builds?"
```

**3. Mixed with text context (lx)**
```bash
$ { lx config.yaml; ix dashboard.png; } | ask "Does the config match what the dashboard shows?"
```

**4. Dynamic image list from filesystem**
```bash
$ find ./assets -name '*.png' | ix | ask "Summarize each image"
```

**5. Mid-pipeline (extending a conversation)**
```bash
$ ask "Describe the architecture" | ix diagram.png | ask "Now annotate the data flow"
```
```

---

## 8. Summary of files touched

| File | Change |
|------|--------|
| `bin/ix.sh` | **New** – image encoder / block emitter |
| `bin/functions.sh` | **Add** `_base64_encode`, `_detect_image_mime`, `_stdin_has_images`, `_build_multimodal_content` |
| `bin/ask.sh` | **Modify** message-building block: gate on `_stdin_has_images`, branch to multimodal content-array construction |
| `bin/answer.sh` | **Modify** assistant-text extraction to handle array content |
| `bin/env.sh` | **Add** `IMAGE_ICON` |
| `HALLUX.md` | **Add** `ix` row to table + §2 bullet + §3D section |
| `doc/commands/ix.md` | **New** – full man-page-style documentation |

The `_infer` function and the request-building `jq` in it require **no changes** – the `messages` array is passed through to the API verbatim, and the OpenAI-compatible endpoint already accepts `content` as either a string or an array of typed parts. The cache key (SHA-256 of the full request JSON) naturally includes the base64 payload, so each unique image gets its own cache entry.

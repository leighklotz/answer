# drift

**`drift`** is a constraint-aware comparison utility for auditing LLM output against ground truth. Unlike `dreck`, which compares two files in the absence of external constraints, `drift` ingests a candidate file alongside an original source **and** one or more context items (specs, requirements, test expectations, API contracts, or other ground-truth documents) and evaluates whether the candidate has *drifted* from what the context demands.

It is intended for detecting not just conversational boilerplate and lazy elisions (as `dreck` does), but substantive **violations of stated constraints**: incorrect values, missing required fields, logical contradictions with a specification, or deviations from a reference implementation's observable behaviour.

## Synopsis

```bash
drift FILE_A FILE_B [CONTEXT_FILE...] [-- [EXTRA_PROMPT...]]
```

* **`FILE_A`**: The original source or reference artifact.
* **`FILE_B`**: The candidate (typically LLM-generated) version to be evaluated.
* **`CONTEXT_FILE...`** (one or more): Ground-truth items — specifications, requirements documents, expected test output, API schemas, or any other constraints against which `FILE_B` must be judged. All context files are ingested via `lx` alongside `FILE_A` and `FILE_B`.
* **`-- [EXTRA_PROMPT...]`**: Optional additional instruction text forwarded to `ask`, appended to the built-in drift-detection prompt.

If no positional file arguments are supplied, `drift` reads a single stream from `stdin` (e.g., a multi-section bundle produced by a prior `lx` call) and passes it through `ask` with the drift prompt.

## Description

`drift` sources `env.sh`, `logging.sh`, and `functions.sh` and then builds a conversation with `ask`.

If at least two positional arguments are provided, it first performs an equality check using `cmp` between `FILE_A` and `FILE_B`; if they are identical, it reports this fact via `ask` and exits without triggering a full drift analysis. If they differ, it ingests all files (source, candidate, and context) via `lx` and runs the comparison.

When positional files are present, the pipeline is:

```bash
lx "$FILE_A" "$FILE_B" "$CONTEXT_FILES..." | ask "$EXTRA_PROMPT" "${PROMPT}"
```

When no files are given (piped input), the pipeline is:

```bash
ask "$EXTRA_PROMPT" "${PROMPT}"
```

### Built-in Prompt

The fixed system prompt used for every drift comparison is:

> You are evaluating whether a candidate artifact (the second file) has drifted from its original source (the first file) **and** from the ground-truth constraints provided in the remaining context items.
>
> 0) If any input is JSON, empty, binary data, or a non-text format, report that fact and stop immediately.
> 1) **Dreck check:** Detect any 'LLM dreck' in the candidate (unnecessary conversational intro/outro, boilerplate, or filler).
> 2) **Elision check:** Verify that no critical content from the original source was omitted, summarized away, or truncated in the candidate.
> 3) **Constraint drift:** For each ground-truth context item, identify specific places where the candidate violates, contradicts, or fails to satisfy a stated requirement, expected value, or constraint. Cite the constraint source (filename) and the offending passage.
> 4) **Factual/code drift:** If the context includes expected test output, API contracts, or reference values, check the candidate for concrete mismatches (wrong identifiers, incorrect logic, missing edge-case handling).
> 5) **Verdict:** Conclude with a summary table: `DRIFTED` / `ACCEPTABLE` / `NEEDS_REVISION`, listing each violation with severity (critical / minor / informational).

`EXTRA_PROMPT` (words after `--`) is appended to the base prompt as a user extension, allowing the caller to focus the analysis (e.g., "Focus on the authentication flow" or "Ignore formatting differences").

## Input Modes

| Condition | Behaviour |
|-----------|-----------|
| `drift FILE_A FILE_B CONTEXT1 [CONTEXT2 ...]` | Ingests all files with `lx`; evaluates candidate against source and constraints. |
| `drift FILE_A FILE_B CONTEXT1 ... -- EXTRA...` | Same as above, with additional prompt words forwarded to `ask`. |
| `drift` with piped input | Treats the incoming stream (e.g., a pre-built `lx` bundle or a multi-section document) as the full context set and passes it through `ask` with the drift prompt. |
| `drift -- EXTRA...` with piped input | Same as above with an extra user prompt extension. |

## Relationship to `dreck`

| Aspect | `dreck` | `drift` |
|--------|---------|---------|
| Inputs | Two files (or a single piped stream) | Source + candidate + one or more ground-truth context items |
| Ground truth | None — comparison is relative (A vs. B only) | Present — constraints C define the expected behaviour |
| Detection focus | LLM boilerplate, lazy elisions, generic quality | All of the above **plus** concrete constraint violations and factual/code drift |
| Verdict | "Substantive improvement?" (qualitative) | `DRIFTED` / `ACCEPTABLE` / `NEEDS_REVISION` (categorical, per-violation) |
| Typical use | "Did the rewrite lose anything?" | "Does the output satisfy the spec / pass the test?" |

`drift` subsumes `dreck`: if no context files are provided, its dreck and elision checks behave identically to `dreck`, but the constraint-drift and verdict sections are skipped.

## Examples

**Basic: compare a rewrite against its source and a requirements doc**

```bash
$ drift config.yaml config-rewrite.yaml requirements.md
```

**Multiple ground-truth items (spec + expected test output + API schema)**

```bash
$ drift handler.go handler-rewrite.go spec.md expected_output.txt api_schema.json
```

**With an additional focus instruction**

```bash
$ drift handler.go handler-rewrite.go spec.md -- "Focus on error-handling paths; ignore style differences"
```

**Piped context (pre-built bundle)**

```bash
$ lx original.md rewrite.md test-expected.txt spec.md | drift -- "Emphasize the test cases"
```

**Comparing a git diff against a feature spec**

```bash
$ gx HEAD feature-branch main.py | drift spec.md -- "Only flag deviations from the API contract"
```

**Quick sanity: two files only (degenerates to dreck-like behaviour)**

```bash
$ drift original.md rewritten.md
# No context files provided; constraint-drift section is skipped.
```

## Exit Codes

| Code | Meaning |
| :--- | :--- |
| **0** | Comparison completed (regardless of verdict). |
| **1** | Usage error, missing files, or pipeline failure. |

## Notes

* `drift` is currently **in development**. The implementation will follow the same structural pattern as `dreck` (source shared library files, build an `ask` pipeline, and exit), with the addition of variable-length context file ingestion before the `lx` call.
* Context files are ingested in the order given. The LLM prompt refers to them by filename (as emitted by `lx` headers), so the order matters for disambiguation when multiple specs are provided.
* The `--` separator works identically to `dreck`: everything after it is treated as free-form prompt text, not as a file path.

#!/usr/bin/env bash
set -euo pipefail

# ─── Load the Hallux toolchain into this shell's namespace ───
source "$(dirname "${BASH_SOURCE[0]}")/../bin/commands/hx-bootstrap.sh"
hx enable

# ─── Housekeeping ───
ARTIFACTS=(decide_schema.json empty_schema.json multiword_schema.json \
           score_multi_schema.json score_split_schema.json \
           options_alias_schema.json nearmiss_schema.json \
           debug_schema.json debug_stderr.txt \
           nodebug_schema.json nodebug_stderr.txt)
trap 'rm -f "${ARTIFACTS[@]}"' EXIT

# ─── 1. Argument form, no more words → schema on stdout ───
#   department  → choice  (3 keyed criteria, accumulated across lines)
#   frustration → score   (3 legend levels, single pipe token)
#   is_urgent   → noul    (probability 0..1)
hx schema build "Support Ticket Triage" \
  select department choice "Which team should handle this" \
  option billing "Payment or subscription issues" \
  option technical "Bugs or integration problems" \
  option sales "Pricing or account questions" \
  select frustration score "How frustrated the customer appears" \
  option "Calm, just stating facts|Frustrated but civil|Very angry, strong language" \
  select is_urgent noul "The message conveys urgency or time-sensitivity" \
> decide_schema.json

jq -e '
  (.questions | keys_unsorted) == ["department", "frustration", "is_urgent"]
  and .questions.department.type == "choice"
  and .questions.department.instructions == "Which team should handle this"
  and (.questions.department.criteria | keys) == ["billing", "sales", "technical"]
  and .questions.department.criteria == {
        "billing":   "Payment or subscription issues",
        "technical": "Bugs or integration problems",
        "sales":     "Pricing or account questions"
      }
  and .questions.department.probabilities == {}
  and .questions.frustration.type == "score"
  and .questions.frustration.instructions == "How frustrated the customer appears"
  and (.questions.frustration.criteria | length) == 3
  and .questions.frustration.criteria[0].level == "Calm, just stating facts"
  and .questions.frustration.criteria[1].level == "Frustrated but civil"
  and .questions.frustration.criteria[2].level == "Very angry, strong language"
  and .questions.is_urgent.type == "noul"
  and .questions.is_urgent.instructions == "The message conveys urgency or time-sensitivity"
' decide_schema.json > /dev/null || {
  echo "❌ schema verification failed" >&2
  exit 1
}
echo "✅ schema verification passed" >&2

# ─── 2. Stdout emit via argv (captured, not redirected to a file) ───
argv_out=$(hx schema build "Stdout emit via argv" \
  select solo choice "one field, no finish" \
  option k "only key") || {
  echo "❌ stdout emit via argv failed" >&2
  exit 1
}
jq -e '.questions.solo.type == "choice"
       and .questions.solo.instructions == "one field, no finish"
       and .questions.solo.criteria == {"k": "only key"}' \
  <<<"$argv_out" > /dev/null || {
  echo "❌ stdout emit via argv verification failed" >&2
  exit 1
}
echo "✅ stdout emit via argv passed" >&2

# ─── 3. Argument form: required type, explicit "" instructions ───
hx schema build "Argv required-fields check" \
  select ping noul "" > empty_schema.json

jq -e '.questions.ping.type == "noul" and .questions.ping.instructions == ""' \
  empty_schema.json > /dev/null || {
  echo "❌ empty-string instructions check failed" >&2
  exit 1
}
echo "✅ empty-string instructions check passed" >&2

# ─── 4. Instructions are all remaining words, joined with spaces ───
hx schema build "Multiword instructions" \
  select ok score "How high is" "the priority?" \
  option 'low|medium|high' > multiword_schema.json

jq -e '.questions.ok.instructions == "How high is the priority?"' \
  multiword_schema.json > /dev/null || {
  echo "❌ multiword instruction joining failed" >&2
  exit 1
}
echo "✅ multiword instruction joining passed" >&2

# ─── 5. Score: multi-token option form (levels in order, one command) ───
hx schema build "Multi-token score levels" \
  select mood score "How does the message feel" \
  option "Calm, just stating facts" "Frustrated but civil" "Very angry, strong language" \
> score_multi_schema.json

jq -e '
  (.questions.mood.criteria | length) == 3
  and .questions.mood.criteria[0].level == "Calm, just stating facts"
  and .questions.mood.criteria[1].level == "Frustrated but civil"
  and .questions.mood.criteria[2].level == "Very angry, strong language"
' score_multi_schema.json > /dev/null || {
  echo "❌ multi-token score levels failed" >&2
  exit 1
}
echo "✅ multi-token score levels passed" >&2

# ─── 6. Score: single pipe-token still splits into levels (doc example 1) ───
hx schema build "Pipe-split score levels" \
  select urgency score "How high is the priority?" \
  option 'low|medium|high' \
> score_split_schema.json

jq -e '
  (.questions.urgency.criteria | length) == 3
  and .questions.urgency.criteria[0].level == "low"
  and .questions.urgency.criteria[1].level == "medium"
  and .questions.urgency.criteria[2].level == "high"
' score_split_schema.json > /dev/null || {
  echo "❌ pipe-split score levels failed" >&2
  exit 1
}
echo "✅ pipe-split score levels passed" >&2

# ─── 7. Choice: `options` alias — with a description AND without one; the
#        empty description is stored as "" and probabilities stays {} ───
hx schema build "Options alias" \
  select team choice "Route to team" \
  options billing "Payment and billing questions" \
  option technical \
> options_alias_schema.json

jq -e '
  .questions.team.type == "choice"
  and .questions.team.instructions == "Route to team"
  and .questions.team.criteria == {
        "billing":   "Payment and billing questions",
        "technical": ""
      }
  and .questions.team.probabilities == {}
' options_alias_schema.json > /dev/null || {
  echo "❌ options alias check failed" >&2
  exit 1
}
echo "✅ options alias (with and without description) + probabilities == {} passed" >&2

# ─── 8. Failure cases: the grammar is loud. EVERY failure case must exit
#        non-zero AND refuse to write — the harness asserts both. ───
_expect_fail() {
  local desc=$1
  shift
  local rc=0 out
  out=$( "$@" 2>/dev/null ) || rc=$?
  if (( rc == 0 )); then
    echo "❌ $desc: expected failure, got success" >&2
    exit 1
  fi
  if [[ -n $out ]]; then
    echo "❌ $desc: schema emitted to stdout despite command errors" >&2
    exit 1
  fi
  echo "✅ $desc correctly rejected (no emit)" >&2
}

_expect_fail "missing instructions"   hx schema build t select x score
_expect_fail "missing type"           hx schema build t select x "some words"
_expect_fail "unknown type"           hx schema build t select x widget "some words"
_expect_fail "missing field name"     hx schema build t select
_expect_fail "duplicate field"        hx schema build t select a noul "" select a score "again"
_expect_fail "option before select"   hx schema build t option key "desc"
_expect_fail "noul takes no options"  hx schema build t select a noul "" option x
_expect_fail "unknown command"        hx schema build t frobnicate
_expect_fail "duplicate choice key"   hx schema build t select x choice "" option k "a" option k "b"
_expect_fail "no DSL commands at all" hx schema build t

# ─── 9. Caveat: a token that is EXACTLY select/option/options starts a new
#        command — instruction/description text must not BEGIN with one of
#        those words. Near-misses like "optionally" are ordinary text. ───

# 'select' inside the instructions splits the command, leaving the select
# short of its required instructions.
_expect_fail "instruction starting with 'select'" \
  hx schema build t select x noul "select carefully"

# 'option' inside the instructions splits the same way — the select is left
# with no instructions at all.
_expect_fail "instruction starting with 'option'" \
  hx schema build t select s score "option low|medium"

# A description whose text is the bare word 'option' splits, leaving a
# trailing 'option' command with no key ("option: missing value").
_expect_fail "description starting with 'option'" \
  hx schema build t select x choice "" option k "option"

# Near-miss: "optionally" is NOT the token 'option' — it is ordinary
# description text and must be absorbed whole (exact-token semantics).
hx schema build "Exact-token near-miss" \
  select x choice "" option k "optionally pick this" > nearmiss_schema.json
jq -e '.questions.x.criteria.k == "optionally pick this"' \
  nearmiss_schema.json > /dev/null || {
  echo "❌ near-miss token absorbed check failed" >&2
  exit 1
}
echo "✅ exact-token caveat (splits + near-miss absorbed) passed" >&2

# ─── 10. Emit refuses to write after an earlier error — even when a later
#         command would succeed. Stdout is captured (a file redirect would
#         create the file before the command runs, defeating the check). ───
refuse_rc=0
refuse_out=$(hx schema build "emit refuses" \
  select a noul "" option a "nope" select b noul "" 2>/dev/null) || refuse_rc=$?
if (( refuse_rc == 0 )); then
  echo "❌ emit should refuse after an earlier error" >&2
  exit 1
fi
if [[ -n $refuse_out ]]; then
  echo "❌ emit wrote a schema to stdout despite an earlier error" >&2
  exit 1
fi
echo "✅ emit refusal passed" >&2

# ─── 11. Legacy flag-style input is rejected loudly (glued, then named) ───
_expect_fail "legacy --instructions flag" \
  hx schema build t select x choice --instructions "old habit"

_expect_fail "legacy split flag" \
  hx schema build t select y score "text" --legend "a|b"

# ─── 12. HALLUX_SCHEMA_DEBUG=1 echoes the parsed commands (positional args
#         and flags) while building; the echo is OPT-IN per the doc ───
HALLUX_SCHEMA_DEBUG=1 hx schema build "Debug echo check" \
  select solo noul "debugging" > debug_schema.json 2> debug_stderr.txt

grep -q 'DBG cmd=select' debug_stderr.txt || {
  echo "❌ HALLUX_SCHEMA_DEBUG=1 did not echo the parsed command" >&2
  exit 1
}
grep -q 'solo noul debugging' debug_stderr.txt || {
  echo "❌ HALLUX_SCHEMA_DEBUG=1 did not echo the parsed positional args" >&2
  exit 1
}
jq -e '.questions.solo.type == "noul"' debug_schema.json > /dev/null || {
  echo "❌ debug run produced a wrong schema" >&2
  exit 1
}
echo "✅ debug echo passed" >&2

# Opt-in check: without the variable there must be no debug echo at all.
hx schema build "No debug echo" select quiet noul "" \
  > nodebug_schema.json 2> nodebug_stderr.txt
if grep -q 'DBG' nodebug_stderr.txt; then
  echo "❌ debug echo occurred without HALLUX_SCHEMA_DEBUG=1" >&2
  exit 1
fi
echo "✅ debug echo is opt-in passed" >&2

echo "" >&2
echo "📋 All schema builder checks passed" >&2

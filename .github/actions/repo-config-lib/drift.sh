#!/usr/bin/env bash
#
# drift.sh <name> <desired.json> <actual.json> [normalise-filter]
#
# Compares declared config against live state and reports the difference in a
# form that can be pasted straight back into .github/repo-config/.
#
# Emits:
#   $GITHUB_OUTPUT       drift=true|false
#   $GITHUB_STEP_SUMMARY a ```diff block, readable on the run page
#   $RUNNER_TEMP/repo-config/<name>.actual.json  uploaded as an artifact
#
# The normalise filter runs over BOTH sides, so a resource can sort its own
# unstable arrays (ruleset rules, bypass actors) into a canonical order.

set -euo pipefail

name="$1"
desired_f="$2"
actual_f="$3"
filter="${4:-.}"

lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="${RUNNER_TEMP:-/tmp}/repo-config"
mkdir -p "$out"

jq -S "$filter" "$desired_f" > "$out/$name.desired.json"

jq --slurpfile desired "$out/$name.desired.json" -f "$lib/project.jq" "$actual_f" \
  | jq -S "$filter" > "$out/$name.actual.json"

if diff -u --label "desired ($name)" --label "actual ($name)" \
     "$out/$name.desired.json" "$out/$name.actual.json" > "$out/$name.diff"; then
  drift=false
else
  drift=true
fi

echo "drift=$drift" >> "${GITHUB_OUTPUT:-/dev/null}"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  if [ "$drift" = true ]; then
    {
      echo "### ❌ \`$name\` — drift"
      echo
      echo '```diff'
      cat "$out/$name.diff"
      echo '```'
      echo
      echo "<details><summary>Live state — paste into <code>.github/repo-config/</code> to accept it</summary>"
      echo
      echo '```json'
      cat "$out/$name.actual.json"
      echo '```'
      echo
      echo "</details>"
    } >> "$GITHUB_STEP_SUMMARY"
  else
    echo "### ✅ \`$name\` — in sync" >> "$GITHUB_STEP_SUMMARY"
  fi
fi

if [ "$drift" = true ]; then
  echo "::warning title=Drift in $name::live state does not match .github/repo-config/"
  cat "$out/$name.diff"
else
  echo "$name: in sync"
fi

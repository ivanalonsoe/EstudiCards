#!/usr/bin/env bash
# Decides which CI jobs a change needs (see .github/workflows/ci.yml).
#
#   bash tool/ci_changes.sh <event> <base commit> <head commit>
#
# Prints three lines for $GITHUB_OUTPUT:
#   code=true|false     anything besides documentation changed (quality)
#   windows=true|false  run integration-windows
#   android=true|false  run e2e-android
# It can be run locally to see what a branch would trigger, e.g.
#   bash tool/ci_changes.sh pull_request origin/main HEAD
set -euo pipefail

event="$1"
base="$2"
head="$3"

all() { printf 'code=true\nwindows=true\nandroid=true\n'; }

# The "Run workflow" button runs everything.
if [ "$event" = workflow_dispatch ]; then
  all
  exit 0
fi

# Without a usable base (e.g. main was force-pushed), run everything.
if ! git cat-file -e "${base}^{commit}" 2>/dev/null; then
  echo "No base commit to compare with: running every job" >&2
  all
  exit 0
fi

files=$(git diff --name-only "$base" "$head")
{ echo "Changed files:"; echo "$files"; } >&2

# Prints true if any changed file matches the regular expression $1.
changed() {
  if grep -qE "$1" <<<"$files"; then echo true; else echo false; fi
}

# Documentation only: docs/ and Markdown files (README, AGENTS…).
code=$(if grep -qvE '^docs/|\.md$' <<<"$files"; then echo true; else echo false; fi)

# What can change how the app runs on a device: its code, the flows the
# integration and E2E tests drive, assets, dependencies, code generation
# settings, UI strings and this workflow. Unit and widget tests (test/),
# tools and the Drift schema dumps only need quality.
app='^(lib/|integration_test/|assets/|pubspec\.(yaml|lock)$|build\.yaml$|l10n\.yaml$|\.github/workflows/ci\.yml$)'
windows=$(changed "$app|^windows/")
android=$(changed "$app|^android/|^patrol_test/")

# A push to main is a merged PR: its heavy jobs already ran on the PR.
if [ "$event" = push ]; then
  windows=false
  android=false
fi

printf 'code=%s\nwindows=%s\nandroid=%s\n' "$code" "$windows" "$android"

#!/usr/bin/env bash
# PostToolUse hook: format edited Dart files and surface analyzer issues.
#
# Reads the tool-call payload from stdin, extracts the edited file, and — only
# for .dart files — runs `dart format` then `dart analyze` on that single file.
# `dart analyze` respects analysis_options.yaml (which includes flutter_lints),
# so the same rules as `flutter analyze` apply, but scoped and fast.
#
# Formatting always runs. If the analyzer reports issues, they are printed to
# stderr and the hook exits 2 so Claude sees them immediately.
set -euo pipefail

input="$(cat)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"

case "$file" in
  *.dart) ;;
  *) exit 0 ;;
esac

[ -f "$file" ] || exit 0

# Format in place (never fail the hook on formatting alone).
dart format "$file" >/dev/null 2>&1 || true

# Analyze the single edited file and feed any findings back to Claude.
if ! output="$(dart analyze "$file" 2>&1)"; then
  {
    echo "dart analyze reported issues in $file:"
    echo "$output"
  } >&2
  exit 2
fi

exit 0

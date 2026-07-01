#!/usr/bin/env bash
# PreToolUse hook: block hand-edits to generated / lock artifacts.
#
# pubspec.lock, build/, .dart_tool/, and .flutter-plugins-dependencies are all
# produced by the Flutter toolchain. Editing them by hand desyncs the project.
# Exiting 2 blocks the tool call and returns the message to Claude.
set -euo pipefail

input="$(cat)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"

[ -n "$file" ] || exit 0

case "$file" in
  *pubspec.lock | */build/* | */.dart_tool/* | *.flutter-plugins-dependencies)
    echo "Blocked: '$file' is a generated/lock artifact and must not be hand-edited. Change pubspec.yaml and run 'flutter pub get' instead." >&2
    exit 2
    ;;
esac

exit 0

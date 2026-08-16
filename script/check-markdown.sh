#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

failed=0
file_count=0

while IFS= read -r markdown_file; do
  file_count=$((file_count + 1))

  if [[ ! -s "$markdown_file" ]]; then
    echo "empty Markdown file: $markdown_file" >&2
    failed=1
  fi

  if ! grep -q '^# ' "$markdown_file"; then
    echo "missing level-one heading: $markdown_file" >&2
    failed=1
  fi

  while IFS= read -r raw_target; do
    target="${raw_target#<}"
    target="${target%>}"
    target="${target%%#*}"
    target="${target%%\?*}"

    case "$target" in
      ""|http://*|https://*|mailto:*|tel:*|data:*|app://*)
        continue
        ;;
    esac

    target="${target//%20/ }"
    resolved="$(dirname "$markdown_file")/$target"
    if [[ ! -e "$resolved" ]]; then
      echo "broken local Markdown link: $markdown_file -> $raw_target" >&2
      failed=1
    fi
  done < <(
    perl -ne 'while (/\[[^]]*\]\((<[^>]+>|[^ )]+)(?:\s+"[^"]*")?\)/g) { print "$1\n" }' \
      "$markdown_file"
  )
done < <(git ls-files --cached --others --exclude-standard '*.md' ':!:lib/**')

if [[ "$file_count" -eq 0 ]]; then
  echo "no authored Markdown files found" >&2
  exit 1
fi

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

echo "checked $file_count authored Markdown files"

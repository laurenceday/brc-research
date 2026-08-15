#!/usr/bin/env bash
set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

diagram_count=0
while IFS= read -r markdown_file; do
  file_slug="${markdown_file//\//_}"
  awk -v output_directory="$temporary_directory" -v file_slug="$file_slug" '
    /^```mermaid[[:space:]]*$/ {
      in_diagram = 1
      diagram_number += 1
      output_file = output_directory "/" file_slug "-" diagram_number ".mmd"
      next
    }
    /^```[[:space:]]*$/ && in_diagram {
      in_diagram = 0
      close(output_file)
      next
    }
    in_diagram { print > output_file }
  ' "$markdown_file"
done < <(git ls-files --cached --others --exclude-standard '*.md' ':!:lib/**')

while IFS= read -r -d '' diagram_file; do
  diagram_count=$((diagram_count + 1))
  npx --yes @mermaid-js/mermaid-cli@11.16.0 \
    --input "$diagram_file" \
    --output "$temporary_directory/diagram-$diagram_count.svg" \
    >/dev/null
done < <(find "$temporary_directory" -type f -name '*.mmd' -print0 | sort -z)

if [[ "$diagram_count" -eq 0 ]]; then
  echo "no Mermaid diagrams found" >&2
  exit 1
fi

echo "rendered $diagram_count Mermaid diagrams"

#!/usr/bin/env bash
set -euo pipefail

# Interactive Pi session launcher with agent profile selection.
# Reads agent definitions from ~/.pi/agent/agents/*.md, shows an fzf
# menu, parses frontmatter, and launches pi with the right flags.

agents_dir="$HOME/.pi/agent/agents"

# Build the menu: "file_path — name — description"
entries=()
for f in "$agents_dir"/*.md; do
  [ -f "$f" ] || continue
  name=$(sed -n 's/^name: //p' "$f" | head -1)
  desc=$(sed -n 's/^description: //p' "$f" | head -1)
  [ -z "$name" ] && name=$(basename "$f" .md)
  entries+=("$f|$name — $desc")
done

if [ ${#entries[@]} -eq 0 ]; then
  echo "No agent profiles found in $agents_dir" >&2
  exit 1
fi

# fzf picker
choice=$(printf '%s\n' "${entries[@]}" | \
  fzf --delimiter='|' --with-nth=2 \
      --prompt="Select agent profile: " \
      --height=40% --reverse --info=inline \
      --header="Pi Session Launcher") || exit 0

file=$(echo "$choice" | cut -d'|' -f1)

# Parse frontmatter
model=$(sed -n 's/^model: //p' "$file" | head -1)
thinking=$(sed -n 's/^thinking: //p' "$file" | head -1)
tools=$(sed -n 's/^tools: //p' "$file" | head -1)

# Build pi args
args=()
[ -n "$model" ] && args+=("--model" "$model")
[ -n "$thinking" ] && args+=("--thinking" "$thinking")
args+=("--append-system-prompt" "$file")
[ -n "$tools" ] && args+=("--tools" "$tools")

# Launch pi
exec pi "${args[@]}"

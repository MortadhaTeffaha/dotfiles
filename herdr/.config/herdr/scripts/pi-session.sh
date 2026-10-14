#!/usr/bin/env bash
set -euo pipefail

# Interactive Pi session launcher with agent profile selection.
# Reads agent definitions from ~/.pi/agent/agents/*.md, shows an fzf
# menu, parses frontmatter, and launches pi with the right flags.

# Source env.sh to pick up workspace-specific environment variables
# (PI_MCP_ADAPTER_OAUTH_FILE_KEY, DDTOOL_AUTH_LOGIN_MODE, EDITOR, etc.)
# that are normally only set in interactive zsh shells via .zshrc.
# We can't source ~/.config/zsh/*.sh directly because those files use
# zsh-specific syntax (bindkey, zmodload, local). Instead, load the
# critical env vars here.

# OAuth encryption key for MCP encrypted-file credential store
_oauth_key_file="$HOME/.pi/agent/.oauth-key"
if [ -f "$_oauth_key_file" ]; then
  export PI_MCP_ADAPTER_OAUTH_FILE_KEY="$(cat "$_oauth_key_file")"
fi
unset _oauth_key_file

# Force device-flow auth on headless workspaces (no browser available)
if [ -n "${WORKSPACES_DAEMON_SOCKET:-}" ]; then
  export DDTOOL_AUTH_LOGIN_MODE=device
  unset BROWSER 2>/dev/null || true
fi

# Editor for Pi's Ctrl+G prompt editor
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-nvim}"

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

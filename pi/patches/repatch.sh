#!/usr/bin/env bash
# Re-apply pi-web-access patches after `pi update`
set -euo pipefail

INDEX="$HOME/.pi/agent/npm/node_modules/pi-web-access/index.ts"

if [ ! -f "$INDEX" ]; then
  echo "pi-web-access/index.ts not found — is pi-web-access installed?"
  exit 1
fi

# Patch 1: Force workflow "none" when config says "none"
if grep -q 'params.workflow ?? configWorkflow' "$INDEX"; then
  sed -i '' 's/resolveWorkflow(params.workflow ?? configWorkflow/resolveWorkflow(configWorkflow === "none" ? "none" : (params.workflow ?? configWorkflow)/' "$INDEX"
  echo "✓ Patched: workflow lock"
else
  echo "→ Skip: workflow lock already applied or pattern not found"
fi

# Patch 2: Update tool description (best-effort, may need manual fixup)
if grep -q 'Searches auto-open the interactive browser curator' "$INDEX"; then
  echo "⚠ Tool description still has old text — manual edit recommended"
  echo "  Edit $INDEX around line 1753"
fi

echo "Done. Restart Pi sessions for changes to take effect."

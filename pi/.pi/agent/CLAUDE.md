# Global Instructions

## Datadog: Always use `pup` CLI — never MCP

**There are no Datadog MCP servers configured.** This is intentional.

All Datadog queries and operations MUST use the `pup` CLI tool. Do NOT attempt to:
- Reinstall or reconfigure Datadog MCP servers in `mcp.json`
- Search for or call `mcp__datadog__*` tools — they do not exist
- Suggest adding MCP servers back as a "fix" for missing tools

### Choosing the org

Use `--org staging` or `--org prod` based on context:
- If the user mentions **staging**, **pre-prod**, or a staging-specific service/cluster → `--org staging`
- If the user mentions **prod**, **production**, or a prod-specific service/cluster → `--org prod`
- If unclear → **ask the user** which org to query

### How to use pup

```bash
# Staging
pup --org staging --read-only logs search --query "status:error" --from 1h

# Production
pup --org prod --read-only incidents list

# Check auth status (tokens auto-refresh)
pup --org staging auth status
pup --org prod auth status
```

**Always pass `--read-only`** for investigations and reviews.

### Key commands

| Task | Command |
|---|---|
| Search logs | `pup --org <org> logs search --query "..." --from 1h` |
| Query metrics | `pup --org <org> metrics query --query "avg:..." --from 5m` |
| List monitors | `pup --org <org> monitors list` |
| List incidents | `pup --org <org> incidents list` |
| APM services | `pup --org <org> apm services list` |
| Search traces | `pup --org <org> traces search --query "..." --from 5m` |
| Error tracking | `pup --org <org> error-tracking groups list` |
| Dashboards | `pup --org <org> dashboards list` |
| Audit logs | `pup --org <org> audit-logs list --from 1h` |
| Raw API | `pup --org <org> api GET /api/v1/monitor` |

Replace `<org>` with `staging` or `prod` as appropriate.

Full command reference: see the `datadog-cli` skill (`~/.pi/agent/skills/datadog-cli/SKILL.md`).

### If pup auth fails

```bash
pup --org <org> auth status    # Check if token expired
pup auth login --org <org> --site datadoghq.com  # Re-authenticate via browser
```

The `pup` wrapper at `~/.pi/agent/bin/pup` prints an org banner during `auth login` so you know which org to authorize.

## Web Search: Never open browser, never generate summaries

When calling the `web_search` tool, **always pass `workflow: "none"`**. Never use `workflow: "summary-review"` or `workflow: "auto-summary"`.

- `workflow: "none"` returns raw search results directly in the conversation — no browser window, no summary generation.
- The user does NOT want a Chrome window opening during web searches.
- The user does NOT want AI-generated summaries of search results.
- Just return the raw search results with citations.

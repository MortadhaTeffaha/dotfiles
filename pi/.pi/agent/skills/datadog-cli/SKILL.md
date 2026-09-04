---
name: datadog-cli
description: "MANDATORY for all Datadog queries. There are NO Datadog MCP servers — they are intentionally removed. Do NOT attempt to use, reinstall, or reconfigure Datadog MCP. Use `pup` CLI instead. Covers logs, metrics, monitors, incidents, dashboards, traces, audit logs. Use `--org staging` or `--org prod` to select the environment (ask the user if unclear). Always pass `--read-only` for investigations. If auth fails, run `pup auth login --org <org> --site datadoghq.com`."
---

# Datadog CLI (`pup`)

Use `pup` — the Datadog API CLI — for all Datadog queries and operations. This replaces the Datadog MCP servers.

**Choosing the org:** Use `--org staging` or `--org prod` based on context. If the user doesn't specify, ask which org to query. Both orgs are authenticated and available.

## Authentication

Pup uses OAuth2 with browser-based login. Tokens auto-refresh and are stored in the OS keychain.

```bash
# Login to staging org
pup auth login --org staging --site datadoghq.com

# Login to prod org
pup auth login --org prod --site datadoghq.com

# Check auth status
pup --org staging auth status
pup --org prod auth status
```

## Global flags

| Flag | Purpose |
|---|---|
| `--org <name>` | Select named org session (staging, prod) |
| `--read-only` | Block all write operations (create, update, delete) — use for investigations |
| `--agent` | AI-optimized output wrapping in `{status, data, metadata}` envelope |
| `--no-agent` | Disable agent mode (for human-readable output) |
| `--output <fmt>` | Output format: json (default), table, yaml, csv |
| `--jq <expr>` | Filter output through jq expression |
| `--yes` | Auto-approve destructive operations |
| `-v, --verbose` | Print rate-limit headers to stderr |

## Common commands

### Logs
```bash
pup --org staging logs search --query "status:error" --from 1h --limit 50
pup --org staging logs aggregate --query "service:api" --from 1h --group-by "status"
```

### Metrics
```bash
pup --org staging metrics query --query "avg:system.cpu.user{*}" --from 5m
pup --org staging metrics list --prefix "system.cpu"
```

### Monitors
```bash
pup --org staging monitors list
pup --org staging monitors get <monitor-id>
pup --org staging monitors create --name "..." --query "..." --type metric
```

### Incidents
```bash
pup --org staging incidents list
pup --org staging incidents get <incident-id>
pup --org staging incidents list --query "state:active"
```

### Dashboards
```bash
pup --org staging dashboards list
pup --org staging dashboards get <dashboard-id>
```

### APM / Traces
```bash
pup --org staging apm services list
pup --org staging traces search --query "service:api" --from 5m --limit 10
pup --org staging traces aggregate --query "service:api" --from 1h --group-by "resource"
```

### Events
```bash
pup --org staging events list --from 1h
```

### Audit logs
```bash
pup --org staging audit-logs list --from 1h
```

### SLOs
```bash
pup --org staging slos list
pup --org staging slos get <slo-id>
```

### Synthetics
```bash
pup --org staging synthetics tests list
pup --org staging synthetics tests get <test-id>
pup --org staging synthetics tests results <test-id>
```

### Cases
```bash
pup --org staging cases search --query "bug"
pup --org staging cases get <case-id>
pup --org staging cases create --title "..." --type-id "..." --priority P2
```

### Error tracking
```bash
pup --org staging error-tracking groups list
pup --org staging error-tracking groups get <group-id>
```

### Software / Service catalog
```bash
pup --org staging software-catalog entities list
pup --org staging service-catalog entities list
```

### Infrastructure
```bash
pup --org staging infrastructure hosts list
pup --org staging processes list
pup --org staging containers list
```

### CI/CD
```bash
pup --org staging cicd pipelines list
pup --org staging code-coverage list
pup --org staging test-optimization flaky-tests list
```

### Security
```bash
pup --org staging security-monitoring rules list
pup --org staging security-monitoring signals list
pup --org staging security-monitoring findings list
```

### Costs / Usage
```bash
pup --org staging usage summary --from 2024-01 --to 2024-02
pup --org staging costs list --from 2024-01
```

### Workflows
```bash
pup --org staging workflows list
pup --org staging workflows run <workflow-id>
```

### AI features
```bash
# Ask Datadog Bits AI (requires --auto-create on first use)
pup --org staging bits ask "What caused the last incident?"

# Ask Datadog Docs AI
pup --org staging docs ask "How to create a monitor?"
```

### Raw API access
```bash
# Direct authenticated API request to any Datadog endpoint
pup --org staging api GET /api/v1/monitor
pup --org staging api POST /api/v2/logs/events --body '{"queries":[...]}'
```

## Safety patterns

- **Investigations**: Always use `--read-only` to prevent accidental mutations:
  ```bash
  pup --org staging --read-only logs search --query "status:error" --from 1h
  ```

- **Pipe to jq for compact summaries**:
  ```bash
  pup --org staging --no-agent incidents list | jq '.data[] | {id, title, severity, state}'
  ```

- **Use `--jq` for inline filtering**:
  ```bash
  pup --org staging monitors list --jq '.[] | select(.type=="metric alert") | {id, name}'
  ```

## Tips

- Run `pup help` to see all commands, or `pup <command> --help` for subcommand details
- Use `--no-agent` when you want clean JSON output without the agent envelope wrapper
- `pup auth refresh --org staging` manually refreshes the token if needed
- `pup alias create dd-staging "pup --org staging"` creates command shortcuts
- `pup format` (alias `fmt`) renders JSON through pup's formatter for readable output

---
name: async-command
description: "Run long-running commands in a visible herdr pane and stream output back to the pi session. Use when a command is expected to take more than a few seconds (builds, test suites, deployments, long-running scripts, watch processes, servers). Requires HERDR_ENV=1."
---

# Async Command in Herdr Pane

When the user asks to run a command that may take a long time — builds, test suites, deployments, migrations, long-running scripts — run it in a visible herdr pane so the user can watch progress, and read output back into this session when done or on demand.

## Prerequisites

Verify herdr is available:

```bash
test "${HERDR_ENV:-}" = 1 && herdr --help >/dev/null 2>&1 && echo "herdr ready"
```

If the check fails, fall back to running the command directly via `bash` and inform the user that herdr is not available.

## Workflow

### 1. Split a pane

Create a sibling pane in the current tab, preserving the working directory and keeping focus in the current session:

```bash
herdr pane split --current --direction right --cwd "$PWD" --no-focus
```

Use `--direction down` if the current pane is narrow. Read the new pane ID from `.result.pane.pane_id` in the JSON response.

### 2. Run the command

Send the command to the new pane:

```bash
herdr pane run <pane-id> "cd '$PWD' && <the-command>"
```

Always `cd` into the working directory first so the command runs in the correct context.

### 3. Show initial progress

After a short pause, read the first lines of output so the user sees the command started:

```bash
sleep 2
herdr pane read <pane-id> --source recent-unwrapped --lines 30
```

Print the output to the user. If the command produces progress indicators (progress bars, counters, spinners), mention what you see.

### 4. Monitor progress

For commands that take more than ~10 seconds, check progress periodically:

```bash
herdr pane read <pane-id> --source recent-unwrapped --lines 40
```

Print the last lines of output each time. Tell the user the command is still running and what phase it appears to be in.

If the user asks "is it done?" or "what's the status?", read the pane:

```bash
herdr pane read <pane-id> --source recent-unwrapped --lines 60
```

### 5. Wait for completion

Wait for a completion signal. Use `wait-output` with a pattern that matches the expected end of the command (e.g., a success message, a prompt return, a specific exit line):

```bash
herdr pane wait-output <pane-id> --match "BUILD SUCCESSFUL" --timeout 300000
```

If you don't know the completion pattern, poll by reading the pane every 10-15 seconds and checking whether the shell prompt has returned (the pane shows a prompt line like `$` or `%` with no running command).

Alternatively, run the command with an explicit completion marker:

```bash
herdr pane run <pane-id> "cd '$PWD' && <the-command>; echo '__PI_CMD_DONE_EXIT:'$?'"
```

Then wait for the marker:

```bash
herdr pane wait-output <pane-id> --match "__PI_CMD_DONE_EXIT" --timeout 600000
```

### 6. Read final output

Once complete, read the full output:

```bash
herdr pane read <pane-id> --source recent-unwrapped --lines 200
```

Print the relevant output to the user: the last 30-60 lines, or any error messages, or the success confirmation. Summarize the result.

### 7. Clean up (optional)

If the pane is no longer needed, close it:

```bash
herdr pane close <pane-id>
```

Only close panes you created. If the user wants to inspect the output themselves, leave the pane open.

## Guidelines

- **Always use `--no-focus`** when splitting so the user's focus stays in the pi session.
- **Always `cd "$PWD"`** in the run command so the command executes in the correct directory.
- **Print output to the user** after each read so they can see progress without switching panes.
- **Use `recent-unwrapped`** as the read source — it joins soft-wrapped lines and is best for logs and transcripts.
- **Use `--format ansi`** only when colors and terminal styling are evidence (e.g., test output with red/green).
- **Parse pane IDs from JSON responses** — never hardcode or guess them.
- **Set reasonable timeouts** — 5 minutes (300000ms) for builds, 10 minutes (600000ms) for large test suites. Omit `--timeout` for indefinite waits.
- **Don't close panes you didn't create** unless the user explicitly asks.
- **If the command fails**, read the full output, report the error, and leave the pane open so the user can inspect.

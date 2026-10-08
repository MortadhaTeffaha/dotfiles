#!/usr/bin/env zsh
# ws — create (or reuse) a Datadog workspace and attach it to local Herdr as a saved machine.
#
# Usage:
#   ws <name>                    Create/reuse workspace <name> and attach to Herdr
#   ws <name> -R <org/repo>      Use a different repo's devcontainer
#   ws <name> -r <region>        Specify region (us-east-1, eu-west-3)
#   ws <name> -s <shell>          Specify shell (bash, zsh, fish)
#   ws <name> -y                 Skip interactive review screen
#   ws <name> --pause             Pause the workspace instead
#   ws <name> --resume            Resume a paused workspace
#   ws <name> --delete             Delete the workspace
#   ws --list                     List all workspaces
#
# After creation, the workspace appears as a space in your local Herdr sidebar.
# Run `herdr` to open the UI and click the workspace in the sidebar to connect.

# --- helpers -----------------------------------------------------------------

ws_log()  { echo "▸ $*" >&2; }
ws_ok()   { echo "✓ $*" >&2; }
ws_err()  { echo "✗ $*" >&2; }
ws_die()  { ws_err "$*"; exit 1; }

# --- subcommands -------------------------------------------------------------

ws_list() {
  workspaces list
}

ws_pause() {
  local name="$1"; shift
  ws_log "Pausing workspace '$name'…"
  workspaces pause "$name" -y
  ws_ok "Workspace '$name' paused."
}

ws_resume() {
  local name="$1"; shift
  ws_log "Resuming workspace '$name'…"
  workspaces resume "$name" -y
  ws_ok "Workspace '$name' resumed."
}

ws_delete() {
  local name="$1"; shift
  ws_log "Deleting workspace '$name'…"
  workspaces delete "$name" -y
  # Remove the saved Herdr machine if it exists
  local machine_id
  machine_id=$(herdr machine list --json 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    machines = data if isinstance(data, list) else data.get('machines', [])
    for m in machines:
        if m.get('label') == '$name' or m.get('ssh_target') == 'workspace-$name':
            print(m.get('id', ''))
            break
except: pass
" 2>/dev/null || true)
  if [[ -n "$machine_id" ]]; then
    ws_log "Removing Herdr machine '$machine_id'…"
    herdr machine remove "$machine_id" 2>/dev/null || true
  fi
  ws_ok "Workspace '$name' deleted."
}

# --- main flow: create + attach ----------------------------------------------

ws_create_and_attach() {
  local name=""
  local create_args=()

  # Parse args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -R|--repo)    create_args+=("-R" "$2"); shift 2 ;;
      -r|--region)  create_args+=("-r" "$2"); shift 2 ;;
      -s|--shell)   create_args+=("-s" "$2"); shift 2 ;;
      -A)           create_args+=("-A" "$2"); shift 2 ;;
      -y|--yes)     create_args+=("-y"); shift ;;
      -i|--instance-type) create_args+=("-i" "$2"); shift 2 ;;
      --skip-dotfiles) create_args+=("--skip-dotfiles"); shift ;;
      --skip-ide-setup) create_args+=("--skip-ide-setup"); shift ;;
      *)            name="$1"; shift ;;
    esac
  done

  [[ -z "$name" ]] && ws_die "Usage: ws <name> [create flags]\n  Run 'ws --list' to list workspaces."

  local ssh_host="workspace-${name}"
  local machine_label="${name}"

  # Step 1: Check if workspace already exists
  local existing
  existing=$(workspaces list 2>/dev/null | awk -v n="$name" '$1==n{print $3}' || true)

  if [[ -n "$existing" ]]; then
    case "$existing" in
      PROVISIONED|RUNNING)
        ws_ok "Workspace '$name' already exists ($existing)."
        ;;
      PAUSED)
        ws_log "Workspace '$name' is paused. Resuming…"
        workspaces resume "$name" -y 2>&1 || ws_die "Failed to resume workspace."
        ws_ok "Workspace '$name' resumed."
        ;;
      *)
        ws_log "Workspace '$name' exists (status: $existing)."
        ;;
    esac
  else
    # Step 2: Create the workspace
    ws_log "Creating workspace '$name'…"
    workspaces create "$name" "${create_args[@]}" -y 2>&1 || ws_die "Failed to create workspace."
    ws_ok "Workspace '$name' created."

    # Wait for provisioning to complete
    ws_log "Waiting for workspace to be provisioned…"
    local max_wait=300  # 5 minutes
    local waited=0
    while [[ $waited -lt $max_wait ]]; do
      local ws_status
      ws_status=$(workspaces list 2>/dev/null | awk -v n="$name" '$1==n{print $3}' || true)
      if [[ "$ws_status" == "PROVISIONED" || "$ws_status" == "RUNNING" ]]; then
        ws_ok "Workspace provisioned (status: $ws_status)."
        break
      fi
      sleep 5
      waited=$((waited + 5))
      if [[ $((waited % 30)) -eq 0 ]]; then
        ws_log "Still waiting… (${waited}s elapsed, status: ${ws_status:-unknown})"
      fi
    done
    [[ $waited -ge $max_wait ]] && ws_die "Workspace provisioning timed out after ${max_wait}s."
  fi

  # Step 3: Ensure SSH config is set up
  ws_log "Updating SSH config…"
  workspaces ssh-config "$name" 2>&1 | grep -v "^$" || true
  ws_ok "SSH config ready (host: ${ssh_host})."

  # Step 4: Authenticate ddtool (needed for /refresh-models and AI Gateway)
  ws_log "Checking ddtool authentication…"
  local ddtool_ok
  ddtool_ok=$(ssh -o ConnectTimeout=15 -o ServerAliveInterval=10 "$ssh_host" \
    'timeout 8 ddtool auth token rapid-ai-platform --datacenter us1.ddbuild.io >/dev/null 2>&1 && echo ok' 2>/dev/null || true)
  if [[ "$ddtool_ok" == "ok" ]]; then
    ws_ok "ddtool already authenticated."
  else
    ws_log "ddtool needs authentication. Starting device flow…"
    # Start device login in background, capture the URL + code
    ssh -o ConnectTimeout=15 -o ServerAliveInterval=5 "$ssh_host" \
      'nohup ddtool auth login --mode device --datacenter us1.ddbuild.io > /tmp/ddtool-auth.log 2>&1 & sleep 5; cat /tmp/ddtool-auth.log' 2>&1 | grep -v "^nc:" || true
    # Extract the URL and code from the output
    local auth_url auth_code
    auth_url=$(ssh -o ConnectTimeout=10 "$ssh_host" 'grep -o "https://[a-z./]*" /tmp/ddtool-auth.log | head -1' 2>/dev/null || true)
    auth_code=$(ssh -o ConnectTimeout=10 "$ssh_host" 'grep -o "[A-Z0-9]*-[A-Z0-9]*-[A-Z0-9]*" /tmp/ddtool-auth.log | head -1' 2>/dev/null || true)
    echo ""
    echo "  ┌─────────────────────────────────────────────────────────┐"
    echo "  │  ddtool authentication required                         │"
    echo "  │                                                         │"
    if [[ -n "$auth_url" ]]; then
      echo "  │  Open this URL in your browser:                         │"
      echo "  │    ${auth_url}"
    else
      echo "  │  Open https://www.google.com/device in your browser     │"
    fi
    if [[ -n "$auth_code" ]]; then
      echo "  │  Enter code: ${auth_code}"
    fi
    echo "  │                                                         │"
    echo "  │  Waiting for authentication to complete…                │"
    echo "  └─────────────────────────────────────────────────────────┘"
    echo ""
    # Wait for the background login to complete (up to 2 minutes)
    local auth_waited=0
    while [[ $auth_waited -lt 120 ]]; do
      sleep 3
      auth_waited=$((auth_waited + 3))
      ddtool_ok=$(ssh -o ConnectTimeout=10 "$ssh_host" \
        'timeout 5 ddtool auth token rapid-ai-platform --datacenter us1.ddbuild.io >/dev/null 2>&1 && echo ok' 2>/dev/null || true)
      if [[ "$ddtool_ok" == "ok" ]]; then
        ws_ok "ddtool authenticated."
        break
      fi
      if [[ $((auth_waited % 15)) -eq 0 ]]; then
        ws_log "Still waiting for authentication… (${auth_waited}s)"
      fi
    done
    if [[ "$ddtool_ok" != "ok" ]]; then
      ws_err "ddtool authentication timed out. Run 'ssh ${ssh_host} ddtool auth login --mode device' manually."
    fi
  fi

  # Step 5: Ensure herdr is installed on the workspace
  ws_log "Checking herdr on workspace…"
  if ! ssh -o ConnectTimeout=15 -o ServerAliveInterval=10 "$ssh_host" 'command -v herdr &>/dev/null' 2>/dev/null; then
    ws_log "Installing herdr on workspace…"
    ssh -o ConnectTimeout=15 -o ServerAliveInterval=10 "$ssh_host" \
      'curl -fsSL https://herdr.dev/install.sh | sh' 2>&1 || ws_die "Failed to install herdr on workspace."
    ws_ok "herdr installed on workspace."
  else
    ws_ok "herdr already installed on workspace."
  fi

  # Step 6: Update herdr on the workspace to match local version
  local local_version
  local_version=$(herdr --version 2>/dev/null | awk '{print $2}')
  ws_log "Local herdr version: ${local_version}"
  ssh -o ConnectTimeout=15 -o ServerAliveInterval=10 "$ssh_host" \
    "remote_ver=\$(herdr --version 2>/dev/null | awk '{print \$2}'); echo \"Remote herdr version: \$remote_ver\"" 2>&1 | grep -v "^nc:" || true

  # Step 7: Stop any running herdr server on the workspace (machine add needs a fresh start)
  ws_log "Stopping any existing herdr server on workspace…"
  ssh -o ConnectTimeout=15 -o ServerAliveInterval=10 "$ssh_host" \
    'export PATH="$HOME/.local/bin:$PATH"; herdr server stop 2>/dev/null; true' 2>&1 | grep -v "^nc:" || true
  sleep 1

  # Step 7b: Kill stale SSH connections from the mirror plugin to old/deleted workspaces
  ws_log "Cleaning up stale SSH connections…"
  pkill -f 'ssh.*-M.*workspace-' 2>/dev/null || true
  sleep 1

  # Step 8: Check if machine is already saved
  local existing_machine
  existing_machine=$(herdr machine list --json 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    machines = data if isinstance(data, list) else data.get('machines', [])
    for m in machines:
        if m.get('label') == '${machine_label}' or m.get('ssh_target') == '${ssh_host}':
            print(m.get('id', ''))
            break
except: pass
" 2>/dev/null || true)

  if [[ -n "$existing_machine" ]]; then
    ws_ok "Herdr machine '${machine_label}' already saved (id: ${existing_machine})."
    # Start the remote server so it's ready to connect
    ws_log "Starting herdr server on workspace…"
    ssh -o ConnectTimeout=15 -o ServerAliveInterval=10 "$ssh_host" \
      'nohup herdr server > /tmp/herdr-server.log 2>&1 & sleep 2' 2>&1 | grep -v "^nc:" || true
    ws_ok "Remote herdr server started."
  else
    # Step 8: Add the workspace as a saved Herdr machine
    ws_log "Adding '${machine_label}' as a Herdr machine…"
    herdr machine add --label "$machine_label" "$ssh_host" 2>&1 | grep -v "^nc:" || \
      ws_die "Failed to add Herdr machine."
    ws_ok "Herdr machine '${machine_label}' saved."
  fi

  # Step 10: Sync dotfiles to the workspace
  ws_log "Syncing dotfiles to workspace…"
  workspaces dotfiles sync "$name" 2>&1 || ws_err "Dotfiles sync failed (may need to run 'workspaces dotfiles migrate' first)."

  # Step 11: Done
  echo ""
  ws_ok "Workspace '${name}' is ready!"
  echo ""
  echo "  SSH:      ssh ${ssh_host}"
  echo "  Herdr:    Open 'herdr' and click '${machine_label}' in the sidebar"
  echo "  Dotfiles: workspaces dotfiles sync ${name}"
  echo "  Models:   Run /refresh-models in Pi (ddtool is pre-authenticated)"
  echo ""
}

# --- entry point -------------------------------------------------------------

main() {
  if [[ $# -eq 0 ]]; then
    echo "ws — create a Datadog workspace and attach it to local Herdr"
    echo ""
    echo "Usage:"
    echo "  ws <name> [flags]       Create/reuse workspace and attach to Herdr"
    echo "  ws --list               List all workspaces"
    echo "  ws <name> --pause       Pause the workspace"
    echo "  ws <name> --resume      Resume a paused workspace"
    echo "  ws <name> --delete       Delete the workspace"
    echo ""
    echo "Create flags:"
    echo "  -R <org/repo>           Use a different repo's devcontainer"
    echo "  -r <region>             Region: us-east-1, eu-west-3"
    echo "  -s <shell>              Shell: bash, zsh, fish"
    echo "  -y                      Skip interactive review"
    echo "  --skip-dotfiles         Skip dotfiles installation"
    echo "  --skip-ide-setup        Skip IDE setup"
    return 0
  fi

  case "$1" in
    --list|-l)
      ws_list
      ;;
    --help|-h)
      main
      ;;
    *)
      local action="create"
      local name=""
      local rest=()
      for arg in "$@"; do
        case "$arg" in
          --pause)  action="pause" ;;
          --resume) action="resume" ;;
          --delete)  action="delete" ;;
          *)        rest+=("$arg") ;;
        esac
      done
      name="${rest[1]:-}"
      [[ -z "$name" ]] && ws_die "Workspace name required."

      case "$action" in
        create)  ws_create_and_attach "$@" ;;
        pause)   ws_pause "$name" ;;
        resume)  ws_resume "$name" ;;
        delete)   ws_delete "$name" ;;
      esac
      ;;
  esac
}

# When sourced (by .zshrc), define `ws` as a function and stay silent.
# When executed directly, run main with the given arguments.
# ZSH_EVAL_CONTEXT contains "file" when sourced, and is "toplevel" or unset when executed.
if [[ "${ZSH_EVAL_CONTEXT:-}" == *file ]]; then
  # Script is being sourced — define `ws` as a shell function
  ws() { set -euo pipefail; main "$@"; }
else
  # Script is being executed directly
  set -euo pipefail
  main "$@"
fi

# Prevent idle sleep while an interactive shell is open (macOS only).
# caffeinate -w $$ exits automatically when this shell process dies, so
# closing the terminal tab lets the Mac sleep normally.
if [[ "$(uname -s)" == "Darwin" ]] && [[ -o interactive ]] && command -v caffeinate &>/dev/null; then
  caffeinate -i -w $$ &>/dev/null &
fi

# Homebrew (must be first — other tools depend on brew PATH)
# Login shells initialize this in .zprofile; inherited shells should not repeat it.
if [[ -z "${HOMEBREW_PREFIX:-}" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

export XDG_CONFIG_HOME=~/.config

# Editor (nvim with vim fallback)
if command -v nvim &>/dev/null; then
  export EDITOR=nvim
  export VISUAL=nvim
elif command -v vim &>/dev/null; then
  export EDITOR=vim
  export VISUAL=vim
fi

# Homebrew security
export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_CASK_OPTS=--require-sha
export HOMEBREW_DIR=/opt/homebrew
export HOMEBREW_BIN=/opt/homebrew/bin

# Prefer GNU binaries to Macintosh binaries
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"

# Go
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"
export GO111MODULE=auto

# Docker (colima)
export DOCKER_HOST="unix://$HOME/.colima/docker.sock"

# bat as man pager
export MANPAGER="sh -c 'col -bx | bat --theme=\"Catppuccin Mocha\" -l man -p'"

# pipx
export PATH="$PATH:$HOME/.local/bin"

# On Datadog workspaces, force ddtool to use device-flow auth (no browser).
# The workspace image sets DDTOOL_AUTH_LOGIN_MODE=auth-code which tries to
# open a browser via xdg-open — useless on a headless workspace. Device flow
# prints a URL + code the user enters on their local machine instead.
# Also set up the encrypted-file OAuth key for Pi MCP adapter (no OS keyring
# on headless Linux; Pi uses AES-256-GCM files keyed by PI_MCP_ADAPTER_OAUTH_FILE_KEY).
if [[ -n "${WORKSPACES_DAEMON_SOCKET:-}" ]]; then
  export DDTOOL_AUTH_LOGIN_MODE="device"
  # 'echo' makes the `open` npm package silently succeed instead of trying
  # xdg-open (which fails noisily on headless workspaces and overlaps the TUI).
  export BROWSER="echo"

  # Generate a per-workspace encryption key for Pi MCP OAuth credential files.
  # The key is stored in ~/.pi/agent/.oauth-key (not synced, not in dotfiles).
  # Each workspace gets its own key; tokens must be re-authenticated per workspace.
  local _oauth_key_file="${HOME}/.pi/agent/.oauth-key"
  if [[ ! -f "$_oauth_key_file" ]]; then
    mkdir -p "$(dirname "$_oauth_key_file")"
    dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 > "$_oauth_key_file"
    chmod 600 "$_oauth_key_file"
  fi
  export PI_MCP_ADAPTER_OAUTH_FILE_KEY="$(cat "$_oauth_key_file")"
fi

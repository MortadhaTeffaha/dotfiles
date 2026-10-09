#!/usr/bin/env bash
set -euo pipefail

# User-local binaries include Herdr and Linux tools installed from source.
export PATH="$HOME/.local/bin:$PATH"

# uname reports the kernel (Darwin/Linux); uname -m is retained for diagnostics.
PLATFORM=""
UNAME_SYSTEM="unknown"
UNAME_MACHINE="unknown"
VHS_VERSION="0.11.0"
TTYD_VERSION="1.7.7"
ATUIN_VERSION="18.23.0"
K9S_VERSION="0.32.7"
LAZYGIT_VERSION="0.45.2"
STARSHIP_VERSION="1.23.0"

if ! command -v uname &>/dev/null; then
  echo "Error: uname is required to detect the operating system." >&2
  exit 1
fi

UNAME_SYSTEM="$(uname -s 2>/dev/null || echo unknown)"
UNAME_MACHINE="$(uname -m 2>/dev/null || echo unknown)"

case "$UNAME_SYSTEM" in
  Darwin) PLATFORM="macos" ;;
  Linux) PLATFORM="linux" ;;
  *)
    echo "Error: unsupported operating system: $UNAME_SYSTEM ($UNAME_MACHINE)." >&2
    exit 1
    ;;
esac

LINUX_PACKAGE_MANAGER=""
if [[ "$PLATFORM" == "linux" ]]; then
  if command -v apt-get &>/dev/null; then
    LINUX_PACKAGE_MANAGER="apt"
  elif command -v pacman &>/dev/null; then
    LINUX_PACKAGE_MANAGER="pacman"
  elif command -v dnf &>/dev/null; then
    LINUX_PACKAGE_MANAGER="dnf"
  elif command -v apk &>/dev/null; then
    LINUX_PACKAGE_MANAGER="apk"
  else
    echo "Error: Linux requires one of: apt-get, pacman, dnf, or apk." >&2
    exit 1
  fi
fi

run_as_root() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    "$@"
  elif command -v sudo &>/dev/null; then
    sudo "$@"
  else
    echo "Error: root privileges are required to run: $*" >&2
    return 1
  fi
}

install_linux_packages() {
  case "$LINUX_PACKAGE_MANAGER" in
    apt) run_as_root apt-get install -y "$@" ;;
    pacman) run_as_root pacman -S --needed --noconfirm "$@" ;;
    dnf) run_as_root dnf install -y "$@" ;;
    apk) run_as_root apk add "$@" ;;
    *) return 1 ;;
  esac
}

if [[ "$PLATFORM" == "macos" ]]; then
  if ! command -v brew &>/dev/null; then
    echo "Error: Homebrew is required but not installed."
    echo "Install it from https://brew.sh"
    exit 1
  fi

  PACKAGES=(
    atuin
    bat
    claude
    colima
    eza
    ffmpeg
    fzf
    ghostty
    k9s
    kubectl
    lazygit
    node
    pi
    herdr
    neovim
    pyenv
    rbenv
    starship
    stow
    tmux
    ttyd
    vhs
    zoxide
  )
else
  echo "Detected $UNAME_SYSTEM $UNAME_MACHINE; using $LINUX_PACKAGE_MANAGER packages."

  # Desktop-only macOS tools (Ghostty and Colima) are intentionally omitted
  # from remote Linux workspace installs.
  PACKAGES=(
    node
    atuin
    bat
    claude
    eza
    ffmpeg
    fzf
    go
    k9s
    kubectl
    lazygit
    pi
    herdr
    neovim
    pyenv
    rbenv
    starship
    stow
    tmux
    ttyd
    vhs
    zoxide
  )

  if [[ "$LINUX_PACKAGE_MANAGER" == "apt" ]]; then
    run_as_root apt-get update
  fi
  install_linux_packages curl ca-certificates
fi

# Map package name to Homebrew formula when they differ.
declare -A BREW_NAME=(
  [claude]="claude-code"
  [kubectl]="kubernetes-cli"
  [neovim]="neovim"
)

# Map package name to the binary used to check if it is installed.
declare -A BIN_NAME=(
  [atuin]="atuin"
  [bat]="bat"
  [claude]="claude"
  [colima]="colima"
  [eza]="eza"
  [ffmpeg]="ffmpeg"
  [fzf]="fzf"
  [ghostty]="ghostty"
  [go]="go"
  [k9s]="k9s"
  [kubectl]="kubectl"
  [lazygit]="lazygit"
  [node]="node"
  [pi]="pi"
  [herdr]="herdr"
  [neovim]="nvim"
  [pyenv]="pyenv"
  [rbenv]="rbenv"
  [starship]="starship"
  [stow]="stow"
  [tmux]="tmux"
  [ttyd]="ttyd"
  [vhs]="vhs"
  [zoxide]="zoxide"
)

# Some Homebrew packages are casks, not formulae.
declare -A IS_CASK=(
  [ghostty]=1
)

# Native package names for supported Linux package managers. An intentionally
# empty mapping means that distribution does not provide a reliable package.
declare -A LINUX_NAME=()
if [[ "$PLATFORM" == "linux" ]]; then
  case "$LINUX_PACKAGE_MANAGER" in
    apt)
      LINUX_NAME=(
        [bat]="bat"
        [eza]="eza"
        [ffmpeg]="ffmpeg"
        [fzf]="fzf"
        [go]="golang-go"
        [kubectl]="kubectl"
        [neovim]="neovim"
        [pyenv]="pyenv"
        [rbenv]="rbenv"
        [stow]="stow"
        [tmux]="tmux"
        [ttyd]="ttyd"
        [zoxide]="zoxide"
      )
      ;;
    pacman)
      LINUX_NAME=(
        [atuin]="atuin"
        [bat]="bat"
        [eza]="eza"
        [ffmpeg]="ffmpeg"
        [fzf]="fzf"
        [go]="go"
        [k9s]="k9s"
        [kubectl]="kubectl"
        [lazygit]="lazygit"
        [neovim]="neovim"
        [pyenv]="pyenv"
        [rbenv]="rbenv"
        [starship]="starship"
        [stow]="stow"
        [tmux]="tmux"
        [ttyd]="ttyd"
        [zoxide]="zoxide"
      )
      ;;
    dnf)
      LINUX_NAME=(
        [bat]="bat"
        [eza]="eza"
        [ffmpeg]="ffmpeg-free"
        [fzf]="fzf"
        [go]="golang"
        [kubectl]="kubernetes-client"
        [neovim]="neovim"
        [rbenv]="rbenv"
        [stow]="stow"
        [tmux]="tmux"
        [ttyd]="ttyd"
        [zoxide]="zoxide"
      )
      ;;
    apk)
      LINUX_NAME=(
        [bat]="bat"
        [eza]="eza"
        [ffmpeg]="ffmpeg"
        [fzf]="fzf"
        [go]="go"
        [kubectl]="kubectl"
        [lazygit]="lazygit"
        [neovim]="neovim"
        [starship]="starship"
        [stow]="stow"
        [tmux]="tmux"
        [ttyd]="ttyd"
        [zoxide]="zoxide"
      )
      ;;
  esac
fi

installed=()
skipped=()
failed=()

for pkg in "${PACKAGES[@]}"; do
  bin="${BIN_NAME[$pkg]:-$pkg}"

  # Debian-based distributions expose bat as batcat.
  if [[ "$pkg" == "bat" && "$PLATFORM" == "linux" ]] && command -v batcat &>/dev/null; then
    skipped+=("$pkg")
    continue
  fi

  if command -v "$bin" &>/dev/null; then
    skipped+=("$pkg")
    continue
  fi

  echo "Installing $pkg..."
  if [[ "$PLATFORM" == "macos" ]]; then
    brew_pkg="${BREW_NAME[$pkg]:-$pkg}"
    if [[ "$pkg" == "pi" ]]; then
      if command -v npm &>/dev/null && npm install -g --ignore-scripts @earendil-works/pi-coding-agent; then
        installed+=("$pkg")
      else
        failed+=("$pkg")
      fi
    elif [[ -n "${IS_CASK[$pkg]:-}" ]]; then
      if brew install --cask "$brew_pkg"; then
        installed+=("$pkg")
      else
        failed+=("$pkg")
      fi
    elif brew install "$brew_pkg"; then
      installed+=("$pkg")
    else
      failed+=("$pkg")
    fi
  else
    case "$pkg" in
      node)
        case "$LINUX_PACKAGE_MANAGER" in
          apt|dnf) linux_packages=(nodejs npm) ;;
          pacman|apk) linux_packages=(nodejs npm) ;;
        esac
        if install_linux_packages "${linux_packages[@]}"; then
          installed+=("$pkg")
        else
          failed+=("$pkg")
        fi
        ;;
      claude)
        if command -v npm &>/dev/null && npm install -g @anthropic-ai/claude-code; then
          installed+=("$pkg")
        else
          failed+=("$pkg")
        fi
        ;;
      pi)
        if command -v npm &>/dev/null && npm install -g --ignore-scripts @earendil-works/pi-coding-agent; then
          installed+=("$pkg")
        else
          failed+=("$pkg")
        fi
        ;;
      herdr)
        if curl -fsSL https://herdr.dev/install.sh | sh; then
          installed+=("$pkg")
        else
          failed+=("$pkg")
        fi
        ;;
      atuin)
        # atuin is not in Ubuntu 22.04 apt; install the musl build from GitHub.
        # The gnu build requires GLIBC 2.39 (Ubuntu 22.04 has 2.35); musl is statically linked.
        case "$UNAME_MACHINE" in
          x86_64|amd64) atuin_arch="x86_64-unknown-linux-gnu" ;;
          arm64|aarch64) atuin_arch="aarch64-unknown-linux-musl" ;;
          *) atuin_arch="" ;;
        esac
        mkdir -p "$HOME/.local/bin"
        atuin_tmp="$(mktemp -d)"
        atuin_url="https://github.com/atuinsh/atuin/releases/download/v${ATUIN_VERSION}/atuin-${atuin_arch}.tar.gz"
        if [[ -n "$atuin_arch" ]] && curl -fL "$atuin_url" | tar xz -C "$atuin_tmp" 2>/dev/null; then
          # tar extracts to a subdirectory named atuin-<arch>
          cp "$atuin_tmp/atuin-${atuin_arch}/atuin" "$HOME/.local/bin/atuin"
          chmod 0755 "$HOME/.local/bin/atuin"
          installed+=("$pkg")
        else
          failed+=("$pkg")
        fi
        rm -rf "$atuin_tmp"
        ;;
      k9s)
        case "$UNAME_MACHINE" in
          x86_64|amd64) k9s_arch="amd64" ;;
          arm64|aarch64) k9s_arch="arm64" ;;
          *) k9s_arch="" ;;
        esac
        mkdir -p "$HOME/.local/bin"
        k9s_tmp="$(mktemp)"
        k9s_url="https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_${k9s_arch}.tar.gz"
        if [[ -n "$k9s_arch" ]] && curl -fL "$k9s_url" -o "$k9s_tmp" && tar xzf "$k9s_tmp" -C "$HOME/.local/bin" k9s 2>/dev/null; then
          chmod 0755 "$HOME/.local/bin/k9s"
          installed+=("$pkg")
        else
          failed+=("$pkg")
        fi
        rm -f "$k9s_tmp"
        ;;
      lazygit)
        case "$UNAME_MACHINE" in
          x86_64|amd64) lg_arch="x86_64" ;;
          arm64|aarch64) lg_arch="arm64" ;;
          *) lg_arch="" ;;
        esac
        mkdir -p "$HOME/.local/bin"
        lg_tmp="$(mktemp -d)"
        lg_url="https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${lg_arch}.tar.gz"
        if [[ -n "$lg_arch" ]] && curl -fL "$lg_url" | tar xz -C "$lg_tmp" 2>/dev/null; then
          cp "$lg_tmp/lazygit" "$HOME/.local/bin/lazygit"
          chmod 0755 "$HOME/.local/bin/lazygit"
          installed+=("$pkg")
        else
          failed+=("$pkg")
        fi
        rm -rf "$lg_tmp"
        ;;
      starship)
        # starship's official install script handles arch detection and download.
        mkdir -p "$HOME/.local/bin"
        if curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin" 2>/dev/null; then
          installed+=("$pkg")
        else
          failed+=("$pkg")
        fi
        ;;
      ttyd)
        case "$UNAME_MACHINE" in
          x86_64|amd64)
            ttyd_asset="ttyd.x86_64"
            ttyd_sha256="8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55"
            ;;
          arm64|aarch64)
            ttyd_asset="ttyd.aarch64"
            ttyd_sha256="b38acadd89d1d396a0f5649aa52c539edbad07f4bc7348b27b4f4b7219dd4165"
            ;;
          *)
            ttyd_asset=""
            ttyd_sha256=""
            ;;
        esac
        mkdir -p "$HOME/.local/bin"
        ttyd_tmp="$(mktemp)"
        ttyd_url="https://github.com/tsl0922/ttyd/releases/download/$TTYD_VERSION/$ttyd_asset"
        if [[ -n "$ttyd_asset" ]] && command -v sha256sum &>/dev/null && curl -fL "$ttyd_url" -o "$ttyd_tmp" && printf '%s  %s\n' "$ttyd_sha256" "$ttyd_tmp" | sha256sum -c - >/dev/null; then
          chmod 0755 "$ttyd_tmp"
          mv "$ttyd_tmp" "$HOME/.local/bin/ttyd"
          installed+=("$pkg")
        else
          rm -f "$ttyd_tmp"
          failed+=("$pkg")
        fi
        ;;
      vhs)
        mkdir -p "$HOME/.local/bin"
        if command -v go &>/dev/null && GOBIN="$HOME/.local/bin" go install "github.com/charmbracelet/vhs@v$VHS_VERSION"; then
          installed+=("$pkg")
        else
          failed+=("$pkg")
        fi
        ;;
      *)
        native_pkg="${LINUX_NAME[$pkg]:-}"
        if [[ -z "$native_pkg" ]]; then
          echo "No $LINUX_PACKAGE_MANAGER package mapping for $pkg; skipping." >&2
          failed+=("$pkg")
        elif install_linux_packages "$native_pkg"; then
          installed+=("$pkg")
        else
          failed+=("$pkg")
        fi
        ;;
    esac
  fi
done

# refresh-models is an opt-in package inside an internal monorepo, so Pi cannot
# install it directly from the repository root. Keep a checkout at ~/dd, which
# matches the portable relative path in pi/.pi/agent/settings.json. Datadog
# Workspaces configures per-org Git authentication before running install.sh.
DATADOG_PI_PACKAGES_DIR="${DATADOG_PI_PACKAGES_DIR:-$HOME/dd/datadog-pi-packages}"
DATADOG_PI_PACKAGES_REPO="${DATADOG_PI_PACKAGES_REPO:-https://github.com/ddoghq-sandbox/datadog-pi-packages.git}"
REFRESH_MODELS_MANIFEST="$DATADOG_PI_PACKAGES_DIR/packages/refresh-models/package.json"

if [[ -d "$DATADOG_PI_PACKAGES_DIR/.git" ]]; then
  echo "Updating internal Pi packages checkout..."
  if ! git -C "$DATADOG_PI_PACKAGES_DIR" pull --ff-only; then
    echo "Warning: could not update $DATADOG_PI_PACKAGES_DIR; using the existing checkout." >&2
  fi
elif [[ -e "$DATADOG_PI_PACKAGES_DIR" ]]; then
  echo "Warning: $DATADOG_PI_PACKAGES_DIR exists but is not a Git checkout; refresh-models will not be installed." >&2
else
  echo "Cloning internal Pi packages for refresh-models..."
  mkdir -p "$(dirname "$DATADOG_PI_PACKAGES_DIR")"
  if command -v gh &>/dev/null; then
    if ! gh repo clone ddoghq-sandbox/datadog-pi-packages "$DATADOG_PI_PACKAGES_DIR"; then
      echo "Warning: GitHub CLI clone failed; trying Git with the workspace credential helper." >&2
      git clone "$DATADOG_PI_PACKAGES_REPO" "$DATADOG_PI_PACKAGES_DIR" || true
    fi
  else
    git clone "$DATADOG_PI_PACKAGES_REPO" "$DATADOG_PI_PACKAGES_DIR" || true
  fi
fi

if [[ -f "$REFRESH_MODELS_MANIFEST" ]]; then
  echo "refresh-models is available at $DATADOG_PI_PACKAGES_DIR/packages/refresh-models"
else
  echo "Warning: refresh-models is unavailable. Confirm access to ddoghq-sandbox/datadog-pi-packages." >&2
  failed+=("refresh-models")
fi

# Reinstall the Herdr plugins used by this configuration. Runtime plugin
# checkouts stay outside the dotfiles repository.
if command -v herdr &>/dev/null; then
  HERDR_PLUGINS=(
    "gh-pr|wyattjoh/herdr-plugin-gh-pr|6fe22de9a90c569f2186595cfddc3707f55ba1bd"
    "herdr-file-viewer|smarzban/herdr-file-viewer|647f03236d9aa20de0b07c9de0a951e13a1e59bf"
    "mirror|nikok6/herdr-mirror|41a5475fb5cfed11481a26b08f949f3f9e1588b5"
    "persiyanov.reviewr|persiyanov/herdr-reviewr|b0a997d5e3f30ace4319f599f1a10f82031f355d"
    "ray.plugin-manager|speardragon/herdr-plugin-manager|cc3370f9387ee994229693ae3dd783b859ab162b"
  )

  for plugin in "${HERDR_PLUGINS[@]}"; do
    IFS='|' read -r plugin_id source ref <<< "$plugin"
    if herdr plugin list --plugin "$plugin_id" --json 2>/dev/null | grep -q "\"$plugin_id\""; then
      echo "Herdr plugin already installed: $plugin_id"
    else
      echo "Installing Herdr plugin: $plugin_id"
      herdr plugin install "$source" --ref "$ref" --yes || echo "Warning: failed to install Herdr plugin $plugin_id; continuing." >&2
    fi
  done
fi

# Patch Pi MCP adapter to suppress console output that overlaps the TUI
# during OAuth flows on headless workspaces.
# 1. Replace bundled xdg-open with a no-op (prevents browser-not-found errors)
# 2. Comment out console.log/error/warn in mcp-auth-flow.js and lifecycle.js
if [[ -d "$HOME/.pi/agent/npm/node_modules/open" ]]; then
  printf '#!/bin/sh\nexit 0\n' > "$HOME/.pi/agent/npm/node_modules/open/xdg-open"
  chmod +x "$HOME/.pi/agent/npm/node_modules/open/xdg-open"
fi
MCP_FLOW="$HOME/.pi/agent/npm/node_modules/pi-mcp-adapter/dist/mcp-auth-flow.js"
if [[ -f "$MCP_FLOW" ]]; then
  sed -i 's/console\.log(`MCP Auth: Open this URL/console.log(`MCP Auth: Open this URL/' "$MCP_FLOW" 2>/dev/null || true
  # Use python for reliable multi-pattern suppression
  python3 -c "
import re
path = '$MCP_FLOW'
with open(path) as f: lines = f.readlines()
for i, line in enumerate(lines):
    if 'console.' in line and 'MCP Auth:' in line:
        lines[i] = '// ' + line if not line.strip().startswith('//') else line
with open(path, 'w') as f: f.writelines(lines)
" 2>/dev/null || true
fi
LIFECYCLE="$HOME/.pi/agent/npm/node_modules/pi-mcp-adapter/dist/lifecycle.js"
if [[ -f "$LIFECYCLE" ]]; then
  python3 -c "
path = '$LIFECYCLE'
with open(path) as f: lines = f.readlines()
for i, line in enumerate(lines):
    if 'console.error' in line and 'MCP:' in line:
        lines[i] = '// ' + line if not line.strip().startswith('//') else line
with open(path, 'w') as f: f.writelines(lines)
" 2>/dev/null || true
fi

echo ""
# Ensure ~/.config/mcp/mcp.json exists with oauthCredentialStore setting.
# readPiMcpConfig() strips 'settings' from ~/.pi/agent/mcp.json, so the
# shared-global config at ~/.config/mcp/mcp.json is required for the
# encrypted-file OAuth credential store on headless workspaces.
mkdir -p "$HOME/.config/mcp"
MCP_SHARED="$HOME/.config/mcp/mcp.json"
if [[ ! -f "$MCP_SHARED" ]]; then
  cat > "$MCP_SHARED" << 'MCPEOF'
{
  "settings": {
    "autoAuth": true,
    "oauthCredentialStore": "encrypted-file"
  }
}
MCPEOF
  echo "Created $MCP_SHARED (encrypted-file OAuth store)"
fi

echo ""
echo "=== Summary ==="
[[ ${#skipped[@]} -gt 0 ]] && echo "Already installed: ${skipped[*]}"
[[ ${#installed[@]} -gt 0 ]] && echo "Installed: ${installed[*]}"
[[ ${#failed[@]} -gt 0 ]] && echo "Failed or unavailable: ${failed[*]}"

echo ""
echo "Run ./stow.sh to symlink configs."

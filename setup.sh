#!/usr/bin/env bash
set -euo pipefail

# uname reports the kernel (Darwin/Linux); uname -m is retained for diagnostics.
PLATFORM=""
UNAME_SYSTEM="unknown"
UNAME_MACHINE="unknown"

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
    fzf
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
  [fzf]="fzf"
  [ghostty]="ghostty"
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
        [fzf]="fzf"
        [kubectl]="kubectl"
        [lazygit]="lazygit"
        [neovim]="neovim"
        [pyenv]="pyenv"
        [rbenv]="rbenv"
        [starship]="starship"
        [stow]="stow"
        [tmux]="tmux"
        [zoxide]="zoxide"
      )
      ;;
    pacman)
      LINUX_NAME=(
        [atuin]="atuin"
        [bat]="bat"
        [eza]="eza"
        [fzf]="fzf"
        [k9s]="k9s"
        [kubectl]="kubectl"
        [lazygit]="lazygit"
        [neovim]="neovim"
        [pyenv]="pyenv"
        [rbenv]="rbenv"
        [starship]="starship"
        [stow]="stow"
        [tmux]="tmux"
        [zoxide]="zoxide"
      )
      ;;
    dnf)
      LINUX_NAME=(
        [bat]="bat"
        [eza]="eza"
        [fzf]="fzf"
        [kubectl]="kubernetes-client"
        [neovim]="neovim"
        [rbenv]="rbenv"
        [stow]="stow"
        [tmux]="tmux"
        [zoxide]="zoxide"
      )
      ;;
    apk)
      LINUX_NAME=(
        [bat]="bat"
        [eza]="eza"
        [fzf]="fzf"
        [kubectl]="kubectl"
        [lazygit]="lazygit"
        [neovim]="neovim"
        [starship]="starship"
        [stow]="stow"
        [tmux]="tmux"
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
          export PATH="$HOME/.local/bin:$PATH"
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
      herdr plugin install "$source" --ref "$ref" --yes
    fi
  done
fi

echo ""
echo "=== Summary ==="
[[ ${#skipped[@]} -gt 0 ]] && echo "Already installed: ${skipped[*]}"
[[ ${#installed[@]} -gt 0 ]] && echo "Installed: ${installed[*]}"
[[ ${#failed[@]} -gt 0 ]] && echo "Failed or unavailable: ${failed[*]}"

echo ""
echo "Run ./stow.sh to symlink configs."

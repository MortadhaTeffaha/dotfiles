#!/usr/bin/env bash
set -euo pipefail

# Check brew is available
if ! command -v brew &>/dev/null; then
  echo "Error: brew is required but not installed."
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
  neovim
  pyenv
  rbenv
  starship
  stow
  tmux
  zoxide
)

# Map package name to brew formula when they differ
declare -A BREW_NAME=(
  [claude]="claude-code"
  [kubectl]="kubernetes-cli"
  [neovim]="neovim"
)

# Map package name to the binary used to check if it's installed
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
  [neovim]="nvim"
  [pyenv]="pyenv"
  [rbenv]="rbenv"
  [starship]="starship"
  [stow]="stow"
  [tmux]="tmux"
  [zoxide]="zoxide"
)

# Some packages are casks, not formulae
declare -A IS_CASK=(
  [ghostty]=1
)

installed=()
skipped=()
failed=()

for pkg in "${PACKAGES[@]}"; do
  bin="${BIN_NAME[$pkg]:-$pkg}"
  brew_pkg="${BREW_NAME[$pkg]:-$pkg}"

  if command -v "$bin" &>/dev/null; then
    skipped+=("$pkg")
    continue
  fi

  echo "Installing $pkg..."
  if [[ -n "${IS_CASK[$pkg]:-}" ]]; then
    if brew install --cask "$brew_pkg"; then
      installed+=("$pkg")
    else
      failed+=("$pkg")
    fi
  else
    if brew install "$brew_pkg"; then
      installed+=("$pkg")
    else
      failed+=("$pkg")
    fi
  fi
done

echo ""
echo "=== Summary ==="
[[ ${#skipped[@]} -gt 0 ]] && echo "Already installed: ${skipped[*]}"
[[ ${#installed[@]} -gt 0 ]] && echo "Installed: ${installed[*]}"
[[ ${#failed[@]} -gt 0 ]] && echo "Failed: ${failed[*]}"

echo ""
echo "Run ./stow.sh to symlink configs."

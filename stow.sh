#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

PACKAGES=(
  atuin
  bat
  colima
  ghostty
  git
  k9s
  lazygit
  nvim
  starship
  tmux
)

usage() {
  echo "Usage: $0 [--restow | --delete]"
  echo "  (no args)  Stow all packages"
  echo "  --restow   Re-stow all packages (useful after adding files)"
  echo "  --delete   Unstow all packages (remove symlinks)"
  exit 1
}

ACTION="--stow"
if [[ $# -gt 0 ]]; then
  case "$1" in
    --restow) ACTION="--restow" ;;
    --delete)  ACTION="--delete" ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
fi

for pkg in "${PACKAGES[@]}"; do
  echo "${ACTION#--}: $pkg"
  stow "$ACTION" --adopt --dir="$DOTFILES_DIR" --target="$HOME" "$pkg"
done

echo "Done."

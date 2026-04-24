#!/usr/bin/env bash
set -euo pipefail

# Install tools
./setup.sh

# Symlink configs
./stow.sh

# Wire zsh config
if ! grep -q 'for f in ~/.config/zsh/\*.sh' ~/.zshrc 2>/dev/null; then
  echo 'for f in ~/.config/zsh/*.sh; do source "$f"; done' >> ~/.zshrc
fi

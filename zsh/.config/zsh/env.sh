# Homebrew (must be first — other tools depend on brew PATH)
eval "$(/opt/homebrew/bin/brew shellenv)"

export XDG_CONFIG_HOME=~/.config

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

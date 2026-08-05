# dotfiles

My configuration files, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Packages

| Package | Description |
|---------|-------------|
| atuin | Shell history sync |
| bat | Syntax-highlighted cat (themes) |
| colima | Container runtime |
| ghostty | Terminal emulator |
| git | Global gitignore |
| herdr | Coding-agent terminal multiplexer, keybindings, and plugins |
| k9s | Kubernetes TUI |
| lazygit | Git TUI |
| nvim | Neovim (LazyVim) |
| pi | Pi coding agent settings, packages, extensions, skills, MCP, and theme |
| starship | Shell prompt |
| tmux | Terminal multiplexer |
| zsh | Shell config (aliases, env, tools, keybinds) |

## Fresh machine setup

Only [Homebrew](https://brew.sh) is required. Everything else is installed by the setup script.

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

# 2. Clone and install
git clone https://github.com/MortadhaTeffaha/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh
./stow.sh

# 3. Wire zsh config into your .zshrc
echo 'for f in ~/.config/zsh/*.sh; do source "$f"; done' >> ~/.zshrc
```

The zsh source line must be added manually because `.zshrc` is not managed by this repo (it may contain machine-specific or private configuration).

`setup.sh` detects the host with `uname`. macOS uses the existing Homebrew flow. Linux ARM64 (`arm64`/`aarch64`) auto-detects `apt`, `pacman`, `dnf`, or `apk`, uses native packages where available, installs Pi and Claude Code through npm, and installs Herdr through its official cross-platform installer. Unknown platforms fall back to the macOS flow. Ghostty and Colima are omitted from remote ARM64 installs. The script also restores the pinned Herdr plugins. Pi installs the package sources listed in `pi/.pi/agent/settings.json` automatically on first startup.

Pi authentication, OAuth tokens, sessions, caches, trust decisions, and Herdr runtime data/logs are intentionally not tracked. The Trajectory Pi extension and MCP entry are included, but require the separately managed `~/.trajectory/bin/trajectory` installation. The local `../../dd/datadog-pi-packages/packages/refresh-models` package in Pi settings likewise requires that checkout at `~/dd/datadog-pi-packages`.

## Usage

```bash
# Re-stow after adding new files
./stow.sh --restow

# Remove all symlinks
./stow.sh --delete
```

## Structure

Each package follows the Stow convention — the directory structure mirrors `$HOME`:

```
package-name/
  .config/
    package-name/
      config-file
```

Stow creates symlinks from `~/.config/package-name/` to the repo.

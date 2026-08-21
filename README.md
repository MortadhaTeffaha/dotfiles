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

On macOS, install [Homebrew](https://brew.sh) first. On Linux, `setup.sh` supports `apt`, `pacman`, `dnf`, and `apk` on both x86_64 and ARM64.

```bash
# macOS only: install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

# Clone and install on macOS or Linux
git clone https://github.com/MortadhaTeffaha/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh
./stow.sh

# Wire zsh config into your .zshrc
echo 'for f in ~/.config/zsh/*.sh; do source "$f"; done' >> ~/.zshrc
```

The zsh source line must be added manually because `.zshrc` is not managed by this repo (it may contain machine-specific or private configuration).

`setup.sh` detects the operating system with `uname`. macOS uses Homebrew. Linux on either x86_64 or ARM64 auto-detects `apt`, `pacman`, `dnf`, or `apk`, uses native packages where available, installs Pi and Claude Code through npm, and installs Herdr through its official cross-platform installer. Unsupported operating systems and Linux distributions without a supported package manager fail explicitly instead of falling back to the macOS flow. Ghostty and Colima are omitted from remote Linux installs. The script also restores the pinned Herdr plugins. Pi installs the package sources listed in `pi/.pi/agent/settings.json` automatically on first startup.

Pi authentication, OAuth tokens, sessions, caches, trust decisions, and Herdr runtime data/logs are intentionally not tracked. The Trajectory Pi extension and MCP entry are included, but require the separately managed `~/.trajectory/bin/trajectory` installation.

`refresh-models` lives in the internal `ddoghq-sandbox/datadog-pi-packages` monorepo. `setup.sh` idempotently clones or updates that repository at `~/dd/datadog-pi-packages`, matching the portable `../../dd/datadog-pi-packages/packages/refresh-models` entry in Pi settings. Datadog Workspaces runs this repository's `install.sh` automatically and configures per-org Git authentication first, so no credentials are committed to the dotfiles. Override the checkout or remote with `DATADOG_PI_PACKAGES_DIR` or `DATADOG_PI_PACKAGES_REPO` when needed.

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

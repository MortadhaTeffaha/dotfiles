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
| k9s | Kubernetes TUI |
| lazygit | Git TUI |
| nvim | Neovim (LazyVim) |
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

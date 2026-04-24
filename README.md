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

## Setup

Prerequisites: [Homebrew](https://brew.sh) and git.

```bash
git clone https://github.com/MortadhaTeffaha/dotfiles.git
cd dotfiles

# Install all tools via brew
./setup.sh

# Symlink configs into $HOME
./stow.sh
```

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

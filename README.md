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

## Pi session orchestration

Pi opens as a normal coding session by default. Session routing is opt-in through the explicit skill at `pi/.pi/agent/skills/work/SKILL.md`:

```text
/skill:work implement retry handling for the API client
```

The skill classifies that one request as documentation writing, documentation review, code development, code review, incident investigation, or general work. Before launching, it shows the selected profile, model, and objective for confirmation. Confirmed work opens as an interactive Pi subagent in a Herdr surface. Calling `/skill:work` without arguments asks for the work request first. Later prompts remain ordinary Pi requests unless the skill is invoked again.

The role profiles live in `pi/.pi/agent/agents/`. Their model and thinking defaults are normal frontmatter and can be edited independently of the skill. Normal sessions use Pi's configured default, currently `ai-gw-openai/openai/gpt-5.6-sol` at medium thinking, while respecting explicit command-line or interactive model overrides.

The code-development profile follows a gated hybrid lifecycle:

1. Define the feature, its motivation, scope, non-goals, and acceptance criteria.
2. Use an interactive planner for substantial changes.
3. Keep one pane-resident implementation worker open for coding, validation fixes, and review fixes.
4. Validate with reproducible commands and run code review.
5. Generate unannotated VHS recordings and screenshots containing only real commands and real output.
6. Invalidate and regenerate proof after any later implementation change.
7. Obtain approval before pushing or creating a PR.
8. Check CI, feedback, approvals, conflicts, evidence, proof revision, and repository policy before declaring merge readiness.

The proof gate requires `vhs`, `ttyd`, and `ffmpeg`; `setup.sh` installs them on macOS. On Linux it installs a pinned VHS release into `~/.local/bin`, downloads a pinned checksum-verified `ttyd` binary for x86_64 or ARM64, and installs `ffmpeg` natively. Workflow handoffs and generated evidence are stored outside target repositories under `~/.pi/agent/workflows/<session-id>/`, preventing orchestration metadata and binary proof from polluting diffs or commits.

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

# Starship prompt
eval "$(starship init zsh)"

# Zoxide (smart cd)
eval "$(zoxide init zsh)"

# Atuin (shell history)
source ~/.config/atuin/zsh_init.sh

# fzf
source <(fzf --zsh)

# Python (pyenv)
# Keep pyenv's shims available immediately, but defer its shell integration
# until the first explicit pyenv command.
export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
export PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"
pyenv() {
  unfunction pyenv
  eval "$(command pyenv init --no-rehash -)"
  pyenv "$@"
}

# Ruby (rbenv)
# Keep rbenv's shims available immediately, but defer its shell integration
# until the first explicit rbenv command.
export RBENV_ROOT="${RBENV_ROOT:-$HOME/.rbenv}"
export PATH="$RBENV_ROOT/shims:$RBENV_ROOT/bin:$PATH"
rbenv() {
  unfunction rbenv
  eval "$(command rbenv init --no-rehash -)"
  rbenv "$@"
}

# Plugins
plugin=(eza zsh-interactive-cd)

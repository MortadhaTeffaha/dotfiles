# Starship prompt
eval "$(starship init zsh)"

# Zoxide (smart cd)
eval "$(zoxide init zsh)"

# Atuin (shell history)
source ~/.config/atuin/zsh_init.sh

# fzf
source <(fzf --zsh)

# Python (pyenv)
eval "$(pyenv init -)"

# Ruby (rbenv)
eval "$(rbenv init -)"

# Plugins
plugin=(eza zsh-interactive-cd)

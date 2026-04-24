# eza (ls replacement)
alias ls='eza $eza_params'
alias l='eza --git-ignore $eza_params'
alias ll='eza --all --header --long $eza_params'
alias llm='eza --all --header --long --sort=modified $eza_params'
alias lx='eza -lbhHigUmuSa@'
alias tree='eza --tree --all $eza_params'

# bat (cat replacement)
alias cat='bat --theme="Catppuccin Mocha"'

# fzf
alias cds='cd $(find . -type d -print | fzf)'

# git
alias gck='git branch | grep -v "^\*" | fzf --height=20% --reverse --info=inline | xargs git checkout'
alias gpnew='git push --set-upstream origin $(git rev-parse --abbrev-ref HEAD)'
alias gpf='git push --force-with-lease'
alias gsb='git status -sb'

# neovim
alias nv="nvim"
alias vim="nvim"
alias vimdiff="nvim -d"

# tools
alias lg="lazygit"
alias k=kubectl
alias cc=claude

# functions
newFeatureBranch() {
  git checkout -b $(id -un)/$1
}
alias nfb=newFeatureBranch

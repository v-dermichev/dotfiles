# Instructions

## 1. Requirements
- zsh
- wezterm
- oh-my-zsh
- neovim
- tmux+tpm
- git
- zsh-autoswitch-virtualenv

## 2. One of many ways to replicate setup
```shell
git clone --bare https://github.com/v-dermichev.git $HOME/.dotfiles
alias dotfiles='/usr/bin/git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME"'
dotfiles checkout
dotfiles config --local status.showUntrackedFiles no
```

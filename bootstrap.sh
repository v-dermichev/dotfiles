#!/bin/sh
set -e

DOTFILES_REPO="https://github.com/v-dermichev/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

info()  { printf '\033[34m[dotfiles]\033[0m %s\n' "$*"; }
ok()    { printf '\033[32m[dotfiles]\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m[dotfiles]\033[0m %s\n' "$*"; }
err()   { printf '\033[31m[dotfiles]\033[0m %s\n' "$*" >&2; }

if ! command -v git >/dev/null 2>&1; then
  err "git is required. Install it first: sudo pacman -S git"
  exit 1
fi

if [ -d "$DOTFILES_DIR" ]; then
  err "$DOTFILES_DIR already exists. Remove it first or use 'dotfiles --sync'."
  exit 1
fi

info "Cloning dotfiles bare repo..."
git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"

_dotfiles() { /usr/bin/git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"; }
_dotfiles config --local status.showUntrackedFiles no

info "Checking out dotfiles..."
if _dotfiles checkout 2>/dev/null; then
  ok "Checked out successfully."
else
  warn "Backing up conflicting files to $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
  _dotfiles checkout 2>&1 \
    | grep -E '^\s' \
    | sed 's/^\s*//' \
    | while IFS= read -r file; do
        dir=$(dirname "$file")
        mkdir -p "$BACKUP_DIR/$dir"
        mv "$HOME/$file" "$BACKUP_DIR/$file"
        info "  backed up: $file"
      done
  _dotfiles checkout
  ok "Checked out successfully (conflicts backed up)."
fi

ok "Done! Restart your shell or run: source ~/.zshrc"
info "Then run: dotfiles --healthcheck"

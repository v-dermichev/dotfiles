# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export NVIM_HOME="$HOME/.config/nvim"
export TERMINAL=/usr/bin/kitty
export PATH="$PATH:/home/work/.local/share/JetBrains/Toolbox/scripts"
export PATH="$PATH:/home/work/Android/Sdk/platform-tools"
export PATH="$PATH:/home/work/Android/Sdk/emulator"

export SUDO_EDITOR="nvim"
export VISUAL="nvim"
export EDITOR="nvim"

export COLORTERM=truecolor

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
#
DEFAULT_USER="work"
ZSH_THEME="agnoster"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
#
#
plugins=(
    git
    python
    virtualenv
    dotenv
    zsh-autosuggestions
    zsh-syntax-highlighting
    zoxide
    fzf
    uv
)

# zsh parameter completion for the dotnet CLI

[[ -f $ZSH/oh-my-zsh.sh ]] && source $ZSH/oh-my-zsh.sh
if command -v dotnet &>/dev/null; then
  eval "$(dotnet completions script zsh)"
  _dotnet_zsh_complete()
  {
    local completions=("$(dotnet complete "$words")")

    # If the completion list is empty, just continue with filename selection
    if [ -z "$completions" ]
    then
      _arguments '*::arguments: _normal'
      return
    fi

    # This is not a variable assignment, don't remove spaces!
    _values = "${(ps:\n:)completions}"
  }

  compdef _dotnet_zsh_complete dotnet
fi



# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

dotfiles() {
  local _git="/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME"

  case "$1" in
  --help)
    cat <<'HELP'
Usage: dotfiles [command] [args...]

Commands:
  --healthcheck   Check all dependencies and configs
  --install       Install missing dependencies (pacman + manual)
  --sync          Pull latest dotfiles and checkout
  --backup        Backup current configs to ~/.dotfiles-backup/
  --edit          Open .zshrc in $EDITOR
  --help          Show this help

Git passthrough:
  dotfiles status / log / diff / add / commit / push / ...
  All other arguments are forwarded to git.
HELP
    ;;

  --healthcheck)
    local ok=() missing=()
    _df_cmd()  { command -v "$1" &>/dev/null && ok+=("$1") || missing+=("$1|$2"); }
    _df_dir()  { [[ -d "$2" ]] && ok+=("$1") || missing+=("$1|$3"); }

    # Shell framework
    _df_dir "oh-my-zsh" "$HOME/.oh-my-zsh" \
      "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
    _df_dir "zsh-autosuggestions" "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" \
      "git clone https://github.com/zsh-users/zsh-autosuggestions \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    _df_dir "zsh-syntax-highlighting" "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" \
      "git clone https://github.com/zsh-users/zsh-syntax-highlighting \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"

    # CLI tools
    _df_cmd git      "sudo pacman -S git"
    _df_cmd fzf      "sudo pacman -S fzf"
    _df_cmd zoxide   "sudo pacman -S zoxide"
    _df_cmd yazi     "sudo pacman -S yazi"
    _df_cmd tmux     "sudo pacman -S tmux"
    _df_cmd kitty    "sudo pacman -S kitty"
    _df_cmd nvim     "sudo pacman -S neovim"
    _df_cmd lazygit  "sudo pacman -S lazygit"
    _df_cmd dotnet   "sudo pacman -S dotnet-sdk"
    _df_cmd nvm      "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash"

    # Dotfiles repo
    [[ -d "$HOME/.dotfiles" ]] && ok+=("dotfiles repo") || \
      missing+=("dotfiles repo|git clone --bare https://github.com/v-dermichev/dotfiles.git \$HOME/.dotfiles")

    # Config dirs
    _df_dir "hyprland config" "$HOME/.config/hypr"       "dotfiles checkout -- .config/hypr"
    _df_dir "kitty config"    "$HOME/.config/kitty"      "dotfiles checkout -- .config/kitty"
    _df_dir "nvim config"     "$HOME/.config/nvim"       "dotfiles checkout -- .config/nvim"
    _df_dir "waybar config"   "$HOME/.config/waybar"     "dotfiles checkout -- .config/waybar"
    _df_dir "yazi config"     "$HOME/.config/yazi"       "dotfiles checkout -- .config/yazi"
    _df_dir "lazygit config"  "$HOME/.config/lazygit"    "dotfiles checkout -- .config/lazygit"
    _df_dir "gtk-3.0 config"  "$HOME/.config/gtk-3.0"    "dotfiles checkout -- .config/gtk-3.0"
    _df_dir "qt6ct config"    "$HOME/.config/qt6ct"      "dotfiles checkout -- .config/qt6ct"

    printf '\033[1m=== Dotfiles Healthcheck ===\033[0m\n\n'
    for item in "${ok[@]}"; do
      printf '  \033[32m✓\033[0m %s\n' "$item"
    done
    if (( ${#missing[@]} )); then
      printf '\n'
      for m in "${missing[@]}"; do
        printf '  \033[31m✗\033[0m %s\n  \033[90m  %s\033[0m\n' "${m%%|*}" "${m#*|}"
      done
    fi
    printf '\n  \033[32m%d\033[0m ok, \033[31m%d\033[0m missing\n' "${#ok[@]}" "${#missing[@]}"

    unfunction _df_cmd _df_dir 2>/dev/null
    return $(( ${#missing[@]} > 0 ))
    ;;

  --install)
    local pacman_pkgs=()
    local manual=()
    command -v fzf      &>/dev/null || pacman_pkgs+=(fzf)
    command -v zoxide   &>/dev/null || pacman_pkgs+=(zoxide)
    command -v yazi     &>/dev/null || pacman_pkgs+=(yazi)
    command -v tmux     &>/dev/null || pacman_pkgs+=(tmux)
    command -v kitty    &>/dev/null || pacman_pkgs+=(kitty)
    command -v nvim     &>/dev/null || pacman_pkgs+=(neovim)
    command -v dotnet   &>/dev/null || pacman_pkgs+=(dotnet-sdk)
    command -v git      &>/dev/null || pacman_pkgs+=(git)

    [[ ! -d "$HOME/.oh-my-zsh" ]] && \
      manual+=("oh-my-zsh: sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\"")
    [[ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]] && \
      manual+=("zsh-autosuggestions: git clone https://github.com/zsh-users/zsh-autosuggestions \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions")
    [[ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]] && \
      manual+=("zsh-syntax-highlighting: git clone https://github.com/zsh-users/zsh-syntax-highlighting \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting")
    ! command -v nvm &>/dev/null && [[ ! -s "$NVM_DIR/nvm.sh" ]] && \
      manual+=("nvm: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash")

    if (( ${#pacman_pkgs[@]} )); then
      printf '\033[34m[dotfiles]\033[0m Installing via pacman: %s\n' "${pacman_pkgs[*]}"
      sudo pacman -S --needed "${pacman_pkgs[@]}"
    else
      printf '\033[32m[dotfiles]\033[0m All pacman packages present.\n'
    fi

    if (( ${#manual[@]} )); then
      printf '\n\033[33m[dotfiles]\033[0m Manual installs needed:\n'
      for m in "${manual[@]}"; do
        printf '  \033[31m✗\033[0m %s\n' "$m"
      done
    fi
    ;;

  --sync)
    printf '\033[34m[dotfiles]\033[0m Pulling latest...\n'
    eval "$_git pull --rebase origin master"
    printf '\033[32m[dotfiles]\033[0m Synced.\n'
    ;;

  --backup)
    local backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    eval "$_git ls-tree -r HEAD --name-only" | while IFS= read -r file; do
      [[ -f "$HOME/$file" ]] || continue
      local dir=$(dirname "$file")
      mkdir -p "$backup_dir/$dir"
      cp "$HOME/$file" "$backup_dir/$file"
    done
    printf '\033[32m[dotfiles]\033[0m Backed up to %s\n' "$backup_dir"
    ;;

  --edit)
    ${EDITOR:-nvim} "$HOME/.zshrc"
    ;;

  --)
    shift
    eval "$_git $*"
    ;;

  --*)
    printf '\033[31m[dotfiles]\033[0m Unknown command: %s\n' "$1"
    printf 'Run "dotfiles --help" for usage.\n'
    return 1
    ;;

  *)
    eval "$_git $*"
    ;;
  esac
}
_dotfiles_complete() {
  local -a subcmds
  subcmds=(
    '--healthcheck:Check all dependencies and configs'
    '--install:Install missing dependencies'
    '--sync:Pull latest dotfiles from remote'
    '--backup:Backup tracked configs to ~/.dotfiles-backup/'
    '--edit:Open .zshrc in $EDITOR'
    '--help:Show usage'
  )
  if [[ "$words[2]" == --* ]] && (( CURRENT == 2 )); then
    _describe 'dotfiles command' subcmds
  else
    # git completion for passthrough
    words[1]=git
    _git
  fi
}
compdef _dotfiles_complete dotfiles

pacman-arch() {
    local tmp=$(mktemp)
    cat /etc/pacman.conf > "$tmp"
    printf '\n[extra]\nInclude = /etc/pacman.d/mirrorlist-arch\n' >> "$tmp"
    sudo pacman --config "$tmp" "$@"
    rm -f "$tmp"
}

if command -v fzf &>/dev/null; then
  function fzfdo() {
      if [ $# -lt 1 ]; then
          echo "Usage: fzfdo [fzf_options] <command> [command_options]"
          return 1
      fi

      local args=("$@")
      local cmd_index=0

      # Detect first argument that is an existing command
      for i in "${!args[@]}"; do
          if command -v "${args[$i]}" &>/dev/null; then
              cmd_index=$i
              break
          fi
      done

      if [ $cmd_index -eq 0 ]; then
          echo "No valid command found"
          return 1
      fi

      # fzf options are before the command
      local fzf_opts=("${args[@]:0:$cmd_index}")

      # command + its options are from cmd_index to end
      local cmd_and_opts=("${args[@]:$cmd_index}")

      # Run fzf to select entries
      local selections
      selections=$(fzf "${fzf_opts[@]}")
      if [ -z "$selections" ]; then
          echo "No selection made"
          return 1
      fi

      # Run the command on each selected entry
      while IFS= read -r entry; do
          "${cmd_and_opts[@]}" "$entry"
      done <<< "$selections"
  }

  fdo() {
    local cmd=$1
    shift
    local file
    file=$(fzf "$@") || return
    $cmd "$file"
  }

  _fzf_complete_pacman() {
    if [[ "$@" == *"-S"* ]]; then
      _fzf_complete -- "$@" < <(pacman -Ssq)
    fi
  }
fi

function work() {
    if command -v tmux &>/dev/null; then
        if [ -n "$TMUX" ]; then
            current_session=$(tmux display-message -p '#S')
            echo "Already in tmux session '$current_session'."
        else
            tmux new-session -A -s work
        fi
    else
        echo "tmux is not installed."
    fi
}

command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

if command -v yazi &>/dev/null; then
  function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
      builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
  }
fi

export PATH="$PATH:/home/work/.local/bin"  

export PATH="$HOME/.npm-global/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# OpenClaw Completion
# source "/home/work/.openclaw/completions/openclaw.zsh"
export LC_TIME="C.UTF-8"

aflmac() { AUTOSSH_GATETIME=0 autossh -M 0 -t afl '/opt/homebrew/bin/tmux new -A -s vdermichev'; }
aflwin() { AUTOSSH_GATETIME=0 autossh -M 0 -t aflwin 'tmux new -A -s vdermichev'; }

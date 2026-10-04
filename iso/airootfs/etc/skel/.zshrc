# ╔══════════════════════════════════════════════╗
# ║              GNEGNOLIOS ZSH                 ║
# ╚══════════════════════════════════════════════╝

# ─── Starship ──────────────────────────────────

eval "$(starship init zsh)"

# ─── Autosuggestions ───────────────────────────

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# ─── Syntax highlighting ───────────────────────

source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ─── History ───────────────────────────────────

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt AUTO_CD
setopt CORRECT

# ─── Alias ─────────────────────────────────────

alias ls='eza --icons --group-directories-first'
alias ll='eza -lah --icons --group-directories-first'
alias la='eza -a --icons --group-directories-first'
alias lt='eza --tree --icons --level=2'
alias cat='bat --paging=never'
alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'

# ─── Git ───────────────────────────────────────

alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# ─── GnegnoliOS ────────────────────────────────

export EDITOR=nano
export VISUAL=nano

# ─── Banner ─────────────────────────────────────

if [[ $- == *i* ]]; then
    clear
    printf '\033[38;5;160m'
    printf '╔══════════════════════════════════════════════╗\n'
    printf '║              G N E G N O L I O S             ║\n'
    printf '║                                              ║\n'
    printf '║       Premium Arch Linux Environment         ║\n'
    printf '╚══════════════════════════════════════════════╝\n'
    printf '\033[0m'
    fastfetch
fi

#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/common.sh
source "$REPO_ROOT/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/install-shell.sh [--dry-run] [--check] [--help]

Install or validate zsh, oh-my-zsh, zsh plugins, Codex CLI, and ~/.zshrc settings.
EOF
  usage_common_flags
}

install_oh_my_zsh() {
  local omz_dir="${ZSH:-$HOME/.oh-my-zsh}"

  if [[ -d "$omz_dir" ]]; then
    log "oh-my-zsh is already installed"
    return
  fi

  log "Installing oh-my-zsh"
  if (( DRY_RUN || CHECK_ONLY )); then
    log "Would install oh-my-zsh into $omz_dir"
    return
  fi

  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

install_zsh_plugins() {
  local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  clone_or_update_repo "https://github.com/zsh-users/zsh-autosuggestions.git" \
    "$custom_dir/plugins/zsh-autosuggestions"
  clone_or_update_repo "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
    "$custom_dir/plugins/zsh-syntax-highlighting"
  clone_or_update_repo "https://github.com/zsh-users/zsh-completions.git" \
    "$custom_dir/plugins/zsh-completions"
}

install_codex() {
  if command_exists codex; then
    log "codex is already installed"
    return
  fi

  log "Installing Codex CLI with npm"
  run_cmd npm install -g @openai/codex
}

configure_zshrc() {
  local start_marker="# >>> start_agent managed zsh block >>>"
  local end_marker="# <<< start_agent managed zsh block <<<"
  local block

  block="$(cat <<'EOF'
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_THEME="${ZSH_THEME:-robbyrussell}"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
)

source "$ZSH/oh-my-zsh.sh"

autoload -Uz compinit
compinit

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

setopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
EOF
)"

  if (( CHECK_ONLY )); then
    log "Managed ~/.zshrc block is ready to be applied"
    return
  fi

  if (( DRY_RUN )); then
    log "Would update $HOME/.zshrc with managed zsh block"
    return
  fi

  append_managed_block "$HOME/.zshrc" "$start_marker" "$end_marker" "$block"
  log "Updated $HOME/.zshrc"
}

set_default_shell() {
  local zsh_path

  zsh_path="$(command -v zsh)"
  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    log "Default shell is already zsh"
    return
  fi

  if (( CHECK_ONLY )); then
    warn "Default shell is not zsh: ${SHELL:-unknown}"
    return
  fi

  if (( DRY_RUN )); then
    log "Would change default shell to $zsh_path"
    return
  fi

  log "Changing default shell to $zsh_path"
  chsh -s "$zsh_path"
}

run_checks() {
  local failures=0

  check_package_manager || ((failures+=1))
  ensure_package zsh || ((failures+=1))
  ensure_package git || ((failures+=1))
  ensure_package curl || ((failures+=1))
  ensure_package npm || ((failures+=1))
  check_network_access "https://raw.githubusercontent.com" || ((failures+=1))
  check_network_access "https://github.com" || ((failures+=1))
  check_network_access "https://registry.npmjs.org" || ((failures+=1))
  check_writable_dir "$HOME" || ((failures+=1))

  if (( failures > 0 )); then
    error "Shell prerequisite checks failed: $failures"
    return 1
  fi

  log "Shell prerequisites look good"
}

main() {
  local parse_status=0

  parse_common_flags "$@" || parse_status=$?
  if (( parse_status == 1 )); then
    usage >&2
    exit 1
  fi

  if (( parse_status == 2 )); then
    usage
    exit 0
  fi

  if (( CHECK_ONLY )); then
    run_checks
    configure_zshrc
    set_default_shell
    return
  fi

  ensure_package zsh
  ensure_package git
  ensure_package curl
  ensure_package npm

  install_oh_my_zsh
  install_zsh_plugins
  install_codex
  configure_zshrc
  set_default_shell

  log "Shell setup complete"
}

main "$@"

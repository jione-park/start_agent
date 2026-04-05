#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/common.sh
source "$REPO_ROOT/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/install-tmux.sh [--dry-run] [--check] [--help]

Install or validate tmux, TPM, tmux plugins, and repo-managed tmux.conf copying.
EOF
  usage_common_flags
}

install_tpm() {
  local tpm_dir="$HOME/.tmux/plugins/tpm"

  if [[ -d "$tpm_dir/.git" ]]; then
    log "TPM is already installed"
    if (( CHECK_ONLY )); then
      return
    fi
    log "Updating TPM"
    run_cmd git -C "$tpm_dir" pull --ff-only
    return
  fi

  clone_or_update_repo "https://github.com/tmux-plugins/tpm" "$tpm_dir"
}

install_tmux_plugins() {
  local tpm_dir="$HOME/.tmux/plugins/tpm"
  local install_script="$tpm_dir/bin/install_plugins"

  if (( DRY_RUN || CHECK_ONLY )) && [[ ! -e "$install_script" ]]; then
    log "Would install tmux plugins with $install_script after TPM setup"
    return
  fi

  if [[ ! -x "$install_script" ]]; then
    warn "TPM install script not found at $install_script. Skipping plugin install."
    return
  fi

  log "Installing tmux plugins from ~/.tmux.conf"
  run_cmd "$install_script"
}

apply_tmux_conf() {
  local repo_tmux_conf="$REPO_ROOT/tmux.conf"
  local target_tmux_conf="$HOME/.tmux.conf"

  if [[ ! -f "$repo_tmux_conf" ]]; then
    warn "tmux.conf not found at $repo_tmux_conf. Skipping config apply."
    return
  fi

  ensure_file_copy "$repo_tmux_conf" "$target_tmux_conf"
  log "Copied tmux.conf to $target_tmux_conf"

  if (( DRY_RUN || CHECK_ONLY )); then
    log "Would reload tmux configuration if a tmux server is running"
    return
  fi

  if command_exists tmux && tmux info >/dev/null 2>&1; then
    log "Reloading tmux configuration"
    tmux source-file "$target_tmux_conf"
  fi
}

run_checks() {
  local failures=0

  check_package_manager || ((failures+=1))
  ensure_package git || ((failures+=1))
  check_network_access "https://github.com" || ((failures+=1))
  check_writable_dir "$HOME/.tmux" || ((failures+=1))

  if command_exists tmux; then
    log "tmux is already installed"
  else
    warn "tmux is not installed"
    ((failures+=1))
  fi

  if [[ -f "$REPO_ROOT/tmux.conf" ]]; then
    ensure_file_copy "$REPO_ROOT/tmux.conf" "$HOME/.tmux.conf" || ((failures+=1))
  else
    warn "tmux.conf is not in the repository yet"
  fi

  if (( failures > 0 )); then
    error "tmux prerequisite checks failed: $failures"
    return 1
  fi

  log "tmux prerequisites look good"
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
    apply_tmux_conf
    return
  fi

  ensure_package tmux
  ensure_package git

  install_tpm
  apply_tmux_conf
  install_tmux_plugins

  log "tmux setup complete"
}

main "$@"

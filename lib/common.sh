#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0
CHECK_ONLY=0

log() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

error() {
  printf '[ERROR] %s\n' "$*" >&2
}

usage_common_flags() {
  cat <<'EOF'
Options:
  --dry-run   Print the actions without changing the system
  --check     Validate prerequisites without installing or modifying anything
  --help      Show usage
EOF
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

parse_common_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        ;;
      --check)
        CHECK_ONLY=1
        ;;
      --help)
        return 2
        ;;
      *)
        error "Unknown option: $1"
        return 1
        ;;
    esac
    shift
  done
}

run_cmd() {
  if (( DRY_RUN || CHECK_ONLY )); then
    printf '[PLAN] '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

detect_package_manager() {
  if command_exists brew; then
    printf 'brew\n'
    return
  fi

  if command_exists apt-get; then
    printf 'apt\n'
    return
  fi

  printf 'unknown\n'
}

ensure_package() {
  local package="$1"
  local manager
  manager="$(detect_package_manager)"

  if command_exists "$package"; then
    log "$package is already installed"
    return
  fi

  if (( CHECK_ONLY )); then
    error "$package is not installed"
    return 1
  fi

  case "$manager" in
    brew)
      log "Installing $package with Homebrew"
      run_cmd brew install "$package"
      ;;
    apt)
      log "Installing $package with apt"
      run_cmd sudo apt-get update
      run_cmd sudo apt-get install -y "$package"
      ;;
    *)
      error "Unsupported package manager. Install $package manually."
      return 1
      ;;
  esac
}

clone_or_update_repo() {
  local repo_url="$1"
  local dest_dir="$2"

  if [[ -d "$dest_dir/.git" ]]; then
    log "Updating $(basename "$dest_dir")"
    if (( CHECK_ONLY )); then
      return 0
    fi
    run_cmd git -C "$dest_dir" pull --ff-only
    return
  fi

  if [[ -e "$dest_dir" ]]; then
    warn "$dest_dir exists but is not a git repository. Skipping clone."
    return 1
  fi

  log "Cloning $repo_url"
  run_cmd git clone --depth 1 "$repo_url" "$dest_dir"
}

append_managed_block() {
  local file_path="$1"
  local start_marker="$2"
  local end_marker="$3"
  local block_content="$4"
  local temp_file

  mkdir -p "$(dirname "$file_path")"
  touch "$file_path"

  temp_file="$(mktemp)"
  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    skip != 1 { print }
  ' "$file_path" >"$temp_file"

  {
    cat "$temp_file"
    printf '\n%s\n%s\n%s\n' "$start_marker" "$block_content" "$end_marker"
  } >"$file_path"

  rm -f "$temp_file"
}

ensure_symlink() {
  local source_path="$1"
  local target_path="$2"

  if (( CHECK_ONLY )); then
    if [[ ! -e "$source_path" ]]; then
      error "Cannot link missing source: $source_path"
      return 1
    fi
    log "Symlink can be created: $target_path -> $source_path"
    return
  fi

  mkdir -p "$(dirname "$target_path")"

  if [[ -L "$target_path" || -f "$target_path" ]]; then
    run_cmd rm -f "$target_path"
  fi

  run_cmd ln -s "$source_path" "$target_path"
}

ensure_file_copy() {
  local source_path="$1"
  local target_path="$2"

  if [[ ! -f "$source_path" ]]; then
    error "Cannot copy missing source file: $source_path"
    return 1
  fi

  if (( CHECK_ONLY )); then
    log "File can be copied: $source_path -> $target_path"
    return 0
  fi

  mkdir -p "$(dirname "$target_path")"
  run_cmd cp "$source_path" "$target_path"
}

check_writable_dir() {
  local dir_path="$1"

  if [[ -d "$dir_path" && -w "$dir_path" ]]; then
    log "Writable directory: $dir_path"
    return 0
  fi

  if [[ ! -e "$dir_path" ]]; then
    local parent_dir
    parent_dir="$(dirname "$dir_path")"
    if [[ -d "$parent_dir" && -w "$parent_dir" ]]; then
      log "Writable parent directory: $parent_dir"
      return 0
    fi
  fi

  error "Directory is not writable: $dir_path"
  return 1
}

check_network_access() {
  local url="$1"

  if ! command_exists curl; then
    error "curl is required to verify network access"
    return 1
  fi

  if curl -fsSIL --connect-timeout 5 "$url" >/dev/null; then
    log "Network access verified: $url"
    return 0
  fi

  error "Network access failed: $url"
  return 1
}

check_package_manager() {
  local manager
  manager="$(detect_package_manager)"

  case "$manager" in
    brew)
      log "Package manager detected: Homebrew"
      ;;
    apt)
      log "Package manager detected: apt-get"
      ;;
    *)
      error "Supported package manager not found"
      return 1
      ;;
  esac
}

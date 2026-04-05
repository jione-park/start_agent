#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./install.sh [--dry-run] [--check] [--help]

Run both shell and tmux setup.
EOF
}

main() {
  case "${1:-}" in
    --help)
      usage
      exit 0
      ;;
  esac

  "$REPO_ROOT/scripts/install-shell.sh" "$@"
  "$REPO_ROOT/scripts/install-tmux.sh" "$@"
}

main "$@"

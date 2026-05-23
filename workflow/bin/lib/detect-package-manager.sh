#!/usr/bin/env bash
# Detect package manager from lockfiles in a project directory.
# Source this file, then call detect_package_manager TARGET
# Sets: PM_NAME, INSTALL_CMD, AUDIT_CMD, HAS_JS, HAS_PHP, COPY_NODE_MODULES

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=detect-lib.sh
source "$_LIB_DIR/detect-lib.sh"

# When executed directly, print vars for shell sourcing or debugging
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  if [ $# -lt 1 ]; then
    echo "Usage: source $0; detect_package_manager /path/to/project" >&2
    echo "   or: $0 /path/to/project" >&2
    exit 1
  fi
  detect_package_manager "$(cd "$1" && pwd)"
  echo "PM_NAME=${PM_NAME}"
  echo "INSTALL_CMD=${INSTALL_CMD}"
  echo "AUDIT_CMD=${AUDIT_CMD}"
  echo "HAS_JS=${HAS_JS}"
  echo "HAS_PHP=${HAS_PHP}"
  echo "COPY_NODE_MODULES=${COPY_NODE_MODULES}"
fi

#!/usr/bin/env bash
#
# git-interceptor  — A wrapper that logs every git invocation.
#
# INSTALL  (one time, requires root):
#   sudo ./git-interceptor --install
#
# NORMAL OPERATION (automatic after install):
#   git <anything>   # behaves exactly like the real git
#
# LOG FILE:
#   By default:  /var/log/git-interceptor/git_intercept.log
#   Override:    export GIT_INTERCEPT_LOG=/path/to/file
#
set -euo pipefail

LOGFILE="${GIT_INTERCEPT_LOG:-/var/log/git-interceptor/git_intercept.log}"
SELF="$(readlink -f "$0")"
SELF_DIR="$(dirname "$SELF")"
REAL_GIT="$SELF_DIR/git.real"            # path we’ll look for after install

install_wrapper() {
  # locate current git
  if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git binary not found in PATH." >&2
    exit 1
  fi

  local git_path
  git_path="$(command -v git)"
  git_path="$(readlink -f "$git_path")"   # absolute, follow symlinks
  local git_dir
  git_dir="$(dirname "$git_path")"

  # refuse to run if we’re already installed
  if [[ "$git_path" == "$SELF" ]]; then
    echo "Already installed at $git_path"
    exit 0
  fi

  # create log directory and set permissions
  local log_dir
  log_dir="$(dirname "$LOGFILE")"
  echo "Creating log directory: $log_dir"
  sudo mkdir -p "$log_dir"
  sudo chmod 777 "$log_dir"
  sudo touch "$LOGFILE"
  sudo chmod 666 "$LOGFILE"

  # rename original
  local real_git="${git_dir}/git.real"
  if [[ -e "$real_git" ]]; then
    echo "ERROR: $real_git already exists — aborting." >&2
    exit 1
  fi
  echo "Renaming original git -> $real_git"
  mv "$git_path" "$real_git"

  # copy ourselves into place
  echo "Copying wrapper -> $git_path"
  install -m 0755 "$SELF" "$git_path"

  echo "✔ Installation complete."
  echo "Log file: $LOGFILE"
}

log_and_exec() {
  # ensure we know where the real binary is
  if [[ ! -x "$REAL_GIT" ]]; then
    echo "ERROR: $REAL_GIT not found. Wrapper not installed correctly." >&2
    exit 1
  fi

  {
    echo
    echo "----- $(date '+%F %T') ----------------------------------------"
    echo "PID: $$"
    echo "USER: $(whoami)"
    echo "ARGS: $*"
    echo "Process tree:"
    ps auxf
  } >> "$LOGFILE" 2>&1

  # delegate to real git
  "$REAL_GIT" "$@"
  exit $?
}

main() {
  if [[ "${1-}" == "--install" ]]; then
    install_wrapper
  else
    log_and_exec "$@"
  fi
}

main "$@"
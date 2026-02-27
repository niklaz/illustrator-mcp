#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
PYTHON_BIN=""
REQ_FILE="$SCRIPT_DIR/requirements.txt"
REQ_HASH_FILE="$VENV_DIR/.requirements.sha256"

log() {
  echo "[illustrator-mcp] $1"
}

find_python() {
  if [ -x "$VENV_DIR/Scripts/python.exe" ]; then
    PYTHON_BIN="$VENV_DIR/Scripts/python.exe"
    return 0
  fi

  if command -v python >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python)"
    return 0
  fi

  if command -v py >/dev/null 2>&1; then
    PYTHON_BIN="py -3"
    return 0
  fi

  return 1
}

ensure_venv() {
  if [ ! -x "$VENV_DIR/Scripts/python.exe" ]; then
    log "Creating virtual environment in .venv"
    if command -v python >/dev/null 2>&1; then
      python -m venv "$VENV_DIR"
    elif command -v py >/dev/null 2>&1; then
      py -3 -m venv "$VENV_DIR"
    else
      log "Python was not found. Install Python 3.11+ and retry."
      exit 1
    fi
  fi

  PYTHON_BIN="$VENV_DIR/Scripts/python.exe"
}

requirements_hash() {
  # Git Bash on Windows ships with sha256sum.
  sha256sum "$REQ_FILE" | awk '{print $1}'
}

requirements_ok() {
  local expected_hash current_hash

  if [ ! -f "$REQ_HASH_FILE" ]; then
    return 1
  fi

  expected_hash="$(cat "$REQ_HASH_FILE" 2>/dev/null || true)"
  current_hash="$(requirements_hash)"

  if [ "$expected_hash" != "$current_hash" ]; then
    return 1
  fi

  if ! $PYTHON_BIN -m pip check >/dev/null 2>&1; then
    return 1
  fi

  # Validate key runtime imports for this server.
  if ! $PYTHON_BIN -c "import mcp, PIL, win32com.client" >/dev/null 2>&1; then
    return 1
  fi

  return 0
}

install_requirements() {
  log "Installing dependencies from requirements.txt"
  $PYTHON_BIN -m pip install --upgrade pip
  $PYTHON_BIN -m pip install -r "$REQ_FILE"
  requirements_hash > "$REQ_HASH_FILE"
}

main() {
  ensure_venv

  if requirements_ok; then
    log "Dependencies are already satisfied. Skipping install."
  else
    install_requirements
  fi

  log "Starting Illustrator MCP server..."
  log "To stop the server, press Ctrl+C in this terminal."
  exec $PYTHON_BIN "$SCRIPT_DIR/illustrator/server.py"
}

main "$@"

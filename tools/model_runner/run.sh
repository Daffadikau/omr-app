#!/usr/bin/env bash
set -euo pipefail

# Resolve script directory to handle relative paths robustly
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Activate or create venv inside the script directory
VENV_DIR="${SCRIPT_DIR}/venv"
if [ -d "${VENV_DIR}" ]; then
  source "${VENV_DIR}/bin/activate"
else
  echo "Virtual environment not found. Creating venv..."
  python3 -m venv "${VENV_DIR}"
  source "${VENV_DIR}/bin/activate"
  pip install -r "${SCRIPT_DIR}/requirements.txt"
fi

# Load .env if present (from script directory)
if [ -f "${SCRIPT_DIR}/.env" ]; then
  # shellcheck disable=SC2046
  export $(grep -v '^#' "${SCRIPT_DIR}/.env" | xargs)
fi

# Validate required env vars
: "${GOOGLE_APPLICATION_CREDENTIALS:?GOOGLE_APPLICATION_CREDENTIALS not set}"
: "${FIREBASE_STORAGE_BUCKET:?FIREBASE_STORAGE_BUCKET not set}"
: "${MODEL_PATH:?MODEL_PATH not set}"

# Run the runner
python "${SCRIPT_DIR}/runner.py"

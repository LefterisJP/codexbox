#!/usr/bin/env bash
set -euo pipefail

# Bootstraps the rotki Python environment using uv, just like the original setup.
if [[ -f pyproject.toml ]] && command -v uv >/dev/null 2>&1; then
  echo "[codexbox] Bootstrapping python env via uv..."
  if uv sync --group dev --group lint; then
    :
  else
    echo "[codexbox] uv groups not available; falling back to 'uv sync'"
    uv sync || true
  fi

  VENV_PY="./.venv/bin/python"
  if [[ -x "$VENV_PY" ]]; then
    if "$VENV_PY" -m pip --version >/dev/null 2>&1; then
      :
    else
      echo "[codexbox] Installing pip inside the project venv for stub installs..."
      if "$VENV_PY" -m ensurepip --upgrade; then
        "$VENV_PY" -m pip install --upgrade pip >/dev/null 2>&1 || true
      else
        echo "[codexbox] WARNING: ensurepip not available; mypy may fail when installing stubs."
      fi
    fi
  fi
fi

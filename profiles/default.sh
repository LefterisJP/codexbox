#!/usr/bin/env bash

# Determine directory of this profile file for relative references.
PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default profile runs the base image (minimal tooling).
# Image depends on the selected tool:
#   codex:       podman build -t codexbox:base-codex  -f Containerfile --target base-codex
#   claude-code: podman build -t codexbox:base-claude -f Containerfile --target base-claude
_TOOL="${TOOL_NAME:-codex}"
if [[ "$_TOOL" == "claude-code" ]]; then
  PROFILE_IMAGE="${PROFILE_IMAGE:-codexbox:base-claude}"
else
  PROFILE_IMAGE="${PROFILE_IMAGE:-codexbox:base-codex}"
fi

PROFILE_BOOTSTRAP="${PROFILE_BOOTSTRAP:-$PROFILE_DIR/default-bootstrap.sh}"
PROFILE_PODMAN_OPTS=()

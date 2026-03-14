#!/usr/bin/env bash

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# rotki profile mirrors the original codexbox environment (Node + Python + uv + Rust)
# Image depends on the selected tool:
#   codex:       podman build -t codexbox:rotki        -f Containerfile --target rotki
#   claude-code: podman build -t codexbox:rotki-claude -f Containerfile --target rotki-claude
_TOOL="${TOOL_NAME:-codex}"
if [[ "$_TOOL" == "claude-code" ]]; then
  PROFILE_IMAGE="${PROFILE_IMAGE:-codexbox:rotki-claude}"
else
  PROFILE_IMAGE="${PROFILE_IMAGE:-codexbox:rotki}"
fi

PROFILE_BOOTSTRAP="${PROFILE_BOOTSTRAP:-$PROFILE_DIR/rotki-bootstrap.sh}"
PROFILE_PODMAN_OPTS=()

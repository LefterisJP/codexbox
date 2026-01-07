#!/usr/bin/env bash

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# rotki profile mirrors the original codexbox environment (Node + Python + uv + Rust)
# Build the image with:
#   podman build -t codexbox:rotki -f Containerfile --target rotki
PROFILE_IMAGE="${PROFILE_IMAGE:-codexbox:rotki}"
PROFILE_BOOTSTRAP="${PROFILE_BOOTSTRAP:-$PROFILE_DIR/rotki-bootstrap.sh}"
PROFILE_PODMAN_OPTS=()

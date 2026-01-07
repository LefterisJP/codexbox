#!/usr/bin/env bash

# Determine directory of this profile file for relative references.
PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default profile runs the base image (minimal tooling). Build it with:
# podman build -t codexbox:base -f Containerfile --target base
PROFILE_IMAGE="${PROFILE_IMAGE:-codexbox:base}"
PROFILE_BOOTSTRAP="${PROFILE_BOOTSTRAP:-$PROFILE_DIR/default-bootstrap.sh}"
PROFILE_PODMAN_OPTS=()

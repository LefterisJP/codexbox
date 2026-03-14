FROM node:lts-bookworm AS base

ENV CARGO_HOME=/home/node/.cargo \
    RUSTUP_HOME=/home/node/.rustup

# System deps + Python toolchain prerequisites
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates curl bash \
    python3 python3-venv python3-pip python3-dev \
    build-essential pkg-config \
    libffi-dev libssl-dev \
    ripgrep less \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /home/node
ENV PATH="/home/node/.cargo/bin:/usr/local/bin:/home/node/.local/bin:${PATH}"

# ===========================================================================
# Codex base: installs Codex CLI + AGENTS.override.md
# Build: podman build -t codexbox:base-codex -f Containerfile --target base-codex
# ===========================================================================
FROM base AS base-codex

RUN npm i -g @openai/codex

ENV CODEX_HOME=/opt/codexbox-home
COPY agent-defaults/base/AGENTS.override.md /opt/codexbox-home/AGENTS.override.md
RUN chown -R node:node /opt/codexbox-home

USER node

# ===========================================================================
# Claude Code base: installs Claude Code CLI + CLAUDE.md (same instruction content)
# Build: podman build -t codexbox:base-claude -f Containerfile --target base-claude
# ===========================================================================
FROM base AS base-claude

RUN npm i -g @anthropic-ai/claude-code

# Stage global instructions at a known path; the container entrypoint
# copies them to ~/.claude/CLAUDE.md at runtime.
RUN mkdir -p /opt/claude-home
COPY agent-defaults/base/AGENTS.override.md /opt/claude-home/CLAUDE.md
RUN chown -R node:node /opt/claude-home

USER node

# ===========================================================================
# rotki toolchain: shared stage with pnpm/corepack, uv and rustup
# (not a final target — used by rotki and rotki-claude below)
# ===========================================================================
FROM base AS rotki-toolchain

USER root
RUN corepack enable

RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
  && install -m 0755 /root/.local/bin/uv /usr/local/bin/uv

USER node
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal --default-toolchain stable

# ===========================================================================
# rotki profile (Codex): rotki toolchain + Codex CLI
# Build: podman build -t codexbox:rotki -f Containerfile --target rotki
# ===========================================================================
FROM rotki-toolchain AS rotki

USER root
RUN npm i -g @openai/codex
ENV CODEX_HOME=/opt/codexbox-home
COPY agent-defaults/base/AGENTS.override.md /opt/codexbox-home/AGENTS.override.md
COPY agent-defaults/rotki/AGENTS.override.md /tmp/AGENTS.rotki.override.md
RUN printf "\n\n" >> /opt/codexbox-home/AGENTS.override.md \
  && cat /tmp/AGENTS.rotki.override.md >> /opt/codexbox-home/AGENTS.override.md \
  && rm /tmp/AGENTS.rotki.override.md
RUN chown -R node:node /opt/codexbox-home
USER node

# ===========================================================================
# rotki profile (Claude Code): rotki toolchain + Claude Code CLI
# Build: podman build -t codexbox:rotki-claude -f Containerfile --target rotki-claude
# ===========================================================================
FROM rotki-toolchain AS rotki-claude

USER root
RUN npm i -g @anthropic-ai/claude-code
RUN mkdir -p /opt/claude-home
COPY agent-defaults/base/AGENTS.override.md /opt/claude-home/CLAUDE.md
COPY agent-defaults/rotki/AGENTS.override.md /tmp/AGENTS.rotki.override.md
RUN printf "\n\n" >> /opt/claude-home/CLAUDE.md \
  && cat /tmp/AGENTS.rotki.override.md >> /opt/claude-home/CLAUDE.md \
  && rm /tmp/AGENTS.rotki.override.md
RUN chown -R node:node /opt/claude-home
USER node

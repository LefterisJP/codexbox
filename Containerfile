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

# Codex CLI (common for all profiles)
RUN npm i -g @openai/codex

# Codexbox global instruction seed (read before repo-level AGENTS)
ENV CODEX_HOME=/opt/codexbox-home
COPY agent-defaults/base/AGENTS.override.md /opt/codexbox-home/AGENTS.override.md
RUN chown -R node:node /opt/codexbox-home

WORKDIR /home/node
ENV PATH="/home/node/.cargo/bin:/usr/local/bin:/home/node/.local/bin:${PATH}"
USER node

# ---------------------------------------------------------------------------
# rotki profile: extends base with pnpm/corepack, uv and rustup
# Build with: podman build -t codexbox:rotki -f Containerfile --target rotki
# ---------------------------------------------------------------------------
FROM base AS rotki

USER root
# pnpm via corepack (rotki docs)
RUN corepack enable

# uv (rotki docs)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
  && install -m 0755 /root/.local/bin/uv /usr/local/bin/uv

USER node
# Latest Rust toolchain for Ruff + custom tools (install under node home)
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal --default-toolchain stable

# Override agent defaults for rotki profile
USER root
COPY agent-defaults/rotki/AGENTS.override.md /tmp/AGENTS.rotki.override.md
# Append rotki defaults after base defaults so base applies first.
RUN printf "\n\n" >> /opt/codexbox-home/AGENTS.override.md \
  && cat /tmp/AGENTS.rotki.override.md >> /opt/codexbox-home/AGENTS.override.md \
  && rm /tmp/AGENTS.rotki.override.md
RUN chown -R node:node /opt/codexbox-home
USER node

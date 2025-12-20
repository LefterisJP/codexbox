FROM node:lts-bookworm

# System deps you will actually need for python packages that compile wheels
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates curl bash \
    python3 python3-venv python3-pip python3-dev \
    build-essential pkg-config \
    libffi-dev libssl-dev \
    ripgrep less \
  && rm -rf /var/lib/apt/lists/*

# Install Codex CLI
RUN npm i -g @openai/codex

# pnpm: rotki docs recommend using the version pinned in frontend/package.json via corepack
RUN corepack enable

# uv: rotki docs recommend the Astral installer
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
  && install -m 0755 /root/.local/bin/uv /usr/local/bin/uv

# Non-root user
USER node
WORKDIR /home/node

# Convenience PATH
ENV PATH="/usr/local/bin:/home/node/.local/bin:${PATH}"

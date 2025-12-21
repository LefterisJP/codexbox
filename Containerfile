FROM node:lts-bookworm

# System deps + Python toolchain prerequisites
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates curl bash \
    python3 python3-venv python3-pip python3-dev \
    build-essential pkg-config \
    libffi-dev libssl-dev \
    ripgrep less \
  && rm -rf /var/lib/apt/lists/*

# Codex CLI
RUN npm i -g @openai/codex

# pnpm via corepack (rotki docs)
RUN corepack enable

# uv (rotki docs)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
  && install -m 0755 /root/.local/bin/uv /usr/local/bin/uv

USER node
WORKDIR /home/node
ENV PATH="/usr/local/bin:/home/node/.local/bin:${PATH}"

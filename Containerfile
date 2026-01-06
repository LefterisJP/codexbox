FROM node:lts-bookworm

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

# Codex CLI
RUN npm i -g @openai/codex

# pnpm via corepack (rotki docs)
RUN corepack enable

# uv (rotki docs)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
  && install -m 0755 /root/.local/bin/uv /usr/local/bin/uv

# Latest Rust toolchain for Ruff + custom tools (install under node home)
USER node
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal --default-toolchain stable

WORKDIR /home/node
ENV PATH="/home/node/.cargo/bin:/usr/local/bin:/home/node/.local/bin:${PATH}"

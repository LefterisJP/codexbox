# codexbox

Run AI coding agents **with full autonomy** on a codebase, **safely isolated** from your host system.

Supports **OpenAI Codex** and **Claude Code** (Anthropic).

This setup exists because:

* Agents are most useful when they can run tools freely
* Doing that directly on your host is unsafe
* Containers give us a controlled blast radius without killing usefulness

This is **not** about perfect security. It's about **practical containment**.

---

## What this does (high level)

* Runs an AI agent inside a **rootless Podman container**
* Gives the agent:

  * full filesystem access *inside the container*
  * internet access (but **no LAN / localhost access**)
  * all required dev tools for the profile (Python 3.11, uv, node, pnpm, etc.)
* Protects the host by:

  * mounting the repo **read-only**
  * working on a cloned copy inside the container
  * exporting changes via a **git bridge repo** back to the host

Worst case:

* the container filesystem gets nuked

Best case:

* you get useful changes without babysitting approvals

---

## Directory layout

```
~/.codexbox/
├── agent-defaults/   # Shared instruction files for both tools
│   ├── base/AGENTS.override.md
│   └── rotki/AGENTS.override.md
├── bin/              # Helper commands mounted into the container
├── Containerfile     # Builds multi-stage containers for both tools
├── codexbox          # Runner script (installed into /usr/local/bin)
├── profiles/         # Built-in profiles + bootstrap hooks
└── README.md         # This file
```

Per-project, you'll see:

```
your-repo/
└── .codexbox-out/
    ├── auth.json                    # Codex OAuth token (when using codex)
    ├── claude-config/               # Claude Code credentials (when using claude-code)
    ├── host.git/                    # Shared git bridge repo
    └── run-YYYYMMDD-HHMMSS.log
```

---

## One-time setup (host)

### 1) Install codexbox

```bash
git clone <repo-url> ~/.codexbox
sudo ln -s ~/.codexbox/codexbox /usr/local/bin/codexbox
```

This places the `codexbox` script in your PATH. The script lives in the repo itself, so pulling updates is all you need to stay current.

### 2) Install Podman (Arch)

```bash
sudo pacman -S --needed podman slirp4netns fuse-overlayfs git util-linux
```

Make sure your user has subuids/subgids (required for rootless Podman):

```bash
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
```

Log out & log back in (or reboot), then:

```bash
podman system migrate
```

---

### 3) Authenticate your agent

#### For Codex (OpenAI)

Codex uses your **ChatGPT subscription**, not an API key.

Install Codex on the host (only for login):

```bash
npm i -g @openai/codex
codex login
```

This creates `~/.codex/auth.json`, which `codexbox` copies per-project into the container.

#### For Claude Code (Anthropic)

Install Claude Code on the host (only for login):

```bash
npm i -g @anthropic-ai/claude-code
# or via your system package manager
claude login
```

`codexbox` reads your OAuth credentials from `~/.claude/.credentials.json` (or `~/.claude.json`)
and passes them to the container via the `CLAUDE_CODE_OAUTH_TOKEN` environment variable. It also
stages a `.claude.json` state file so the container skips first-time setup prompts.

---

## Building the containers

Build all images at once:

```bash
codexbox build
```

This builds every final target in the Containerfile. You can also build individually:

```bash
# Codex images
podman build -t codexbox:base-codex  -f Containerfile --target base-codex
podman build -t codexbox:rotki       -f Containerfile --target rotki

# Claude Code images
podman build -t codexbox:base-claude -f Containerfile --target base-claude
podman build -t codexbox:rotki-claude -f Containerfile --target rotki-claude
```

The Containerfile uses a shared `rotki-toolchain` intermediate stage so Python/uv/Rust
layers are built once and shared between the Codex and Claude Code rotki images.

---

## Using codexbox

### Basic usage

```bash
# Run with Codex (default)
codexbox .

# Run with Claude Code
codexbox --tool claude-code .
```

### Tool selection

The `--tool` flag selects which agent to run. Supported values: `codex` (default), `claude-code`.

```bash
codexbox --tool claude-code .
```

You can also set it via environment variable:

```bash
export CODEXBOX_TOOL=claude-code
codexbox .
```

### Profile selection

The default profile is **rotki**. Switch with `--profile <name>` or `CODEXBOX_PROFILE`:

```bash
codexbox --profile default --tool claude-code .
```

Per-project defaults live in `<repo>/.codexbox/config`:

```
profile = default
```

Resolution order: CLI flag → `CODEXBOX_PROFILE` env → repo config → `rotki`.

Profiles automatically select the correct container image based on the tool. For example,
the `rotki` profile uses `codexbox:rotki` for Codex and `codexbox:rotki-claude` for Claude Code.

### What happens

1. Repo is mounted **read-only** at `/src`
2. Repo is cloned into `/tmp/codexworkspace` inside the container
3. The agent runs with full autonomy:
   * Codex: `--dangerously-bypass-approvals-and-sandbox`
   * Claude Code: `--dangerously-skip-permissions`
4. All changes stay inside the container
5. Use `cb-export "message"` to sync changes back to the host

---

## Networking model (important)

The container runs with:

```
--network slirp4netns:allow_host_loopback=false
```

This means:

* ✅ outbound internet (OpenAI/Anthropic APIs, GitHub, package registries)
* ❌ no access to host `localhost`
* ❌ no access to LAN (192.168.x.x, 10.x.x.x, etc.)

This is intentional.

---

## Security model (honest version)

What this protects you from:

* accidental `rm -rf` on your repo or home
* wild file edits outside the workspace
* most "oops" moments from autonomous agents

What it does **not** protect you from:

* container escapes (rare but real)
* resource exhaustion (CPU/RAM/disk)
* exfiltration of anything you mount into the container

Rules:

* Never mount your home directory
* Never mount SSH keys or wallets
* Treat mounted files as readable by the agent

This setup puts you roughly at:

> "running arbitrary build scripts from the internet"
> which is acceptable for serious dev work.

---

## Profiles & hooks

`codexbox` supports **profiles** so you can tailor the container + bootstrap logic per
project while keeping rotki as the default.

Built-in profiles live in `~/.codexbox/profiles/`:

* `rotki` – default. Uses the rotki image and runs the uv bootstrap hook.
* `default` – minimal. Uses the base image and a no-op bootstrap script.

A profile file is just a shell script that sets:

```bash
PROFILE_IMAGE=codexbox:myproject     # podman image/tag to run
PROFILE_BOOTSTRAP=/path/to/hook.sh   # mounted and executed after cloning the repo
PROFILE_PODMAN_OPTS=(--memory=8g)    # optional extra podman run flags
```

Profiles auto-select the right image for the chosen tool (e.g. `codexbox:rotki` vs
`codexbox:rotki-claude`). See `profiles/rotki.sh` for an example.

The bootstrap script executes inside the cloned repo (`/tmp/codexworkspace`). To define a
new profile, copy `profiles/default.sh` + `profiles/default-bootstrap.sh`, tweak them, and
point them at your custom container stage (add one to `Containerfile` if needed). Make the
scripts executable; `codexbox` mounts them automatically.

---

## Customization knobs

If you want tighter limits, set them per profile:

```bash
PROFILE_PODMAN_OPTS=(--memory=8g --cpus=6 --pids-limit=2048)
```

Offline mode? Add `--network none` there. Need extra system deps? Add a new stage to
`Containerfile`, rebuild it, and point your profile at that image.

---

## Agent defaults (global)

codexbox bakes a global instruction file into each container image:

* **Codex**: reads `AGENTS.override.md` from `/opt/codexbox-home/`
* **Claude Code**: the same content is placed as `CLAUDE.md` (at `/opt/claude-home/`,
  copied to `~/.claude/CLAUDE.md` at runtime)

Source files are shared — no duplication:

```
agent-defaults/base/AGENTS.override.md    # base instructions (all profiles)
agent-defaults/rotki/AGENTS.override.md   # rotki-specific additions
```

Edit the appropriate file, then rebuild the images (`codexbox build`) to update defaults.

---

## Iterative workflow (mid-session sync)

codexbox creates a shared bare git repo at:

- inside container: `/out/host.git`
- on host: `<repo>/.codexbox-out/host.git`

Inside the container, two helper commands exist:

- `cb-export "message"`: stages all files (including new ones), commits, pushes to the host bridge repo
- `cb-import`: fetches from the bridge repo and merges into the current branch

The bridge branch name matches the tool (`codex` or `claude-code`), so you can run
both tools on the same repo without conflicts.

### Host helpers

codexbox provides host-side helpers as subcommands.

#### Set up / refresh the remote

```bash
codexbox remote
```

Adds a git remote named `codexbox` pointing to `.codexbox-out/host.git` and fetches.

#### Pull latest agent changes into a branch

```bash
codexbox pull
```

Creates/resets branch `codexbox-work` to the latest agent output (auto-detects which tool branch exists).
From there, merge or cherry-pick as desired.

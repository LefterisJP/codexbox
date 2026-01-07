# codexbox

Run OpenAI Codex **with full autonomy** on a codebase, **safely isolated** from your host system.

This setup exists because:

* Codex is most useful when it can run tools freely (`--dangerously-bypass-approvals-and-sandbox`)
* Doing that directly on your host is unsafe
* Containers give us a controlled blast radius without killing usefulness

This is **not** about perfect security. It’s about **practical containment**.

---

## What this does (high level)

* Runs Codex inside a **rootless Podman container**
* Gives Codex:

  * full filesystem access *inside the container*
  * internet access (but **no LAN / localhost access**)
  * all required dev tools for rotki (Python 3.11, uv, node, pnpm, etc.)
* Protects the host by:

  * mounting the repo **read-only**
  * working on a cloned copy inside the container
  * exporting changes as a **git patch** back to the host

Worst case:

* the container filesystem gets nuked
  Best case:
* you get useful changes without babysitting approvals

---

## Directory layout

```
~/.codexbox/
├── bin/               # Helper commands mounted into the container
├── Containerfile      # Builds multi-stage Codex dev containers
├── codexbox           # Runner script (installed into /usr/local/bin)
├── profiles/          # Built-in profiles + bootstrap hooks
└── README.md          # This file
```

Per-project, you’ll see:

```
your-repo/
└── .codexbox-out/
    ├── auth.json                # copied OAuth token (scoped to this project)
    ├── patch-YYYYMMDD-HHMMSS.diff
    └── run-YYYYMMDD-HHMMSS.log
```

---

## One-time setup (host)

### 1) Install Podman (Arch)

```bash
sudo pacman -S --needed podman slirp4netns fuse-overlayfs git util-linux
```

Make sure your user has subuids/subgids (required for rootless Podman):

```bash
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 lefteris
```

Log out & log back in (or reboot), then:

```bash
podman system migrate
```

---

### 2) Authenticate Codex (OAuth)

Codex uses your **ChatGPT subscription**, not an API key.

Install Codex on the host (only for login):

```bash
npm i -g @openai/codex
```

Login once:

```bash
codex login
```

This creates:

```
~/.codex/auth.json
```

`codexbox` will copy this file per-project and mount **only that file** into the container.

---

## Building the container

From `~/.codexbox` build whichever stages you need:

```bash
# Minimal base image (git + codex CLI + basic toolchain)
podman build -t codexbox:base -f Containerfile --target base

# Full rotki profile (default) with Python, uv, pnpm, Rust…
podman build -t codexbox:rotki -f Containerfile --target rotki
```

`codexbox:rotki` matches the original setup (Python 3.11, uv, node/corepack, pnpm,
Rust/cargo, Codex CLI). `codexbox:base` is intentionally small and acts as the starting
point for new project-specific images. If your tooling changes, update `Containerfile`
(add a new stage if needed) and rebuild the relevant tag.

---

## Using codexbox

From any repo checkout:

```bash
codexbox .
```

The default profile is **rotki**, so this behaves exactly like the original setup.
Switch at runtime with `--profile <name>` or export `CODEXBOX_PROFILE=name`. Example:

```bash
codexbox --profile default .
```

Per-project defaults live in `<repo>/.codexbox/config`:

```
profile = default
```

`codexbox` resolves the profile in this order: CLI flag → `CODEXBOX_PROFILE` env → repo
config → `rotki`.

What happens:

1. Repo is mounted **read-only** at `/src`
2. Repo is cloned into `/tmp/codexworkspace` inside the container
3. Codex runs there with:

   ```
   --dangerously-bypass-approvals-and-sandbox
   ```
4. All changes stay inside the container
5. A patch is written to:

   ```
   .codexbox-out/patch-<timestamp>.diff
   ```

Apply changes manually:

```bash
git apply .codexbox-out/patch-*.diff
```

---

## Networking model (important)

The container runs with:

```
--network slirp4netns:allow_host_loopback=false
```

This means:

* ✅ outbound internet (OpenAI, GitHub, package registries)
* ❌ no access to host `localhost`
* ❌ no access to LAN (192.168.x.x, 10.x.x.x, etc.)

This is intentional.

---

## Security model (honest version)

What this protects you from:

* accidental `rm -rf` on your repo or home
* wild file edits outside the workspace
* most “oops” moments from autonomous agents

What it does **not** protect you from:

* container escapes (rare but real)
* resource exhaustion (CPU/RAM/disk)
* exfiltration of anything you mount into the container

Rules:

* Never mount your home directory
* Never mount SSH keys or wallets
* Treat mounted files as readable by the agent

This setup puts you roughly at:

> “running arbitrary build scripts from the internet”
> which is acceptable for serious dev work.

---

## Profiles & hooks

`codexbox` now supports **profiles** so you can tailor the container + bootstrap logic per
project while keeping rotki as the default.

Built-in profiles live in `~/.codexbox/profiles/`:

* `rotki` – default. Uses the `codexbox:rotki` image and runs the uv bootstrap hook used
  historically.
* `default` – minimal. Uses `codexbox:base` and a no-op bootstrap script.

A profile file is just a shell script that sets:

```bash
PROFILE_IMAGE=codexbox:myproject     # podman image/tag to run
PROFILE_BOOTSTRAP=/path/to/hook.sh   # mounted and executed after cloning the repo
PROFILE_PODMAN_OPTS=(--memory=8g)    # optional extra podman run flags
```

The bootstrap script executes inside the cloned repo (`/tmp/codexworkspace`). To define a
new profile, copy `profiles/default.sh` + `profiles/default-bootstrap.sh`, tweak them, and
point them at your custom container stage (add one to `Containerfile` if needed). Make the
scripts executable; `codexbox` mounts them automatically.

Use `--profile name`, `CODEXBOX_PROFILE`, or `<repo>/.codexbox/config` to pick which
profile runs. This lets you maintain different toolchains/limits/networking per project
without editing the runner script.

---

## Customization knobs

If you want tighter limits, set them per profile:

```bash
PROFILE_PODMAN_OPTS=(--memory=8g --cpus=6 --pids-limit=2048)
```

Offline mode? Add `--network none` there. Need extra system deps? Add a new stage to
`Containerfile`, rebuild it (`podman build -t codexbox:myproj -f Containerfile --target myproj`),
and point your profile at that image.

---

## Iterative workflow (mid-session sync, including new/untracked files)

codexbox creates a shared bare git repo at:

- inside container: `/out/host.git`
- on host: `<repo>/.codexbox-out/host.git`

Inside the container, two helper commands exist:

- `cb-export "message"`: stages all files (including new ones), commits, pushes to host branch `codex`
- `cb-import`: fetches `host/codex` and merges it into the current branch

### Pull changes onto the host (any time)

From the host, to check out what Codex exported:

```bash
git clone .codexbox-out/host.git /tmp/codex-export
cd /tmp/codex-export
git checkout codex

## Host helpers

codexbox provides host-side helpers as subcommands.

### Set up / refresh the Codex remote

```bash
codexbox remote
```

Adds a git remote named codexbox pointing to .codexbox-out/host.git
and fetches the latest changes.

### Pull latest Codex changes into a branch

```bash
codexbox pull
```

Creates/resets branch codexbox-work to the latest Codex output.
From there, merge or cherry-pick as desired.

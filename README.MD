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
├── Containerfile      # Builds the Codex dev container
├── codexbox           # Runner script (installed into /usr/local/bin)
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

From `~/.codexbox`:

```bash
podman build -t codexbox:latest -f Containerfile
```

This image includes everything needed for **rotki development**:

* Python 3.11
* uv
* node + corepack
* pnpm
* git, build tools, SSL headers
* OpenAI Codex CLI

If tools change in the future, update `Containerfile` and rebuild.

---

## Using codexbox

From **any rotki repo checkout**:

```bash
codexbox .
```

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

## Customization knobs

If you want tighter limits, add to `podman run`:

```bash
--memory=8g --cpus=6 --pids-limit=2048
```

If you want **offline mode** (no internet):

```bash
--network none
```

If you want to add more tools:

* edit `Containerfile`
* rebuild image
* done

---

## Why this exists (tl;dr)

Codex without autonomy is a toy.
Codex with autonomy on your host is dangerous.

This setup is the middle ground:
**useful, fast, and contained**.

If future-you wonders “why not just run it locally?”
this README is your answer.

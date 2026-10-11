---
name: remote-codex-over-tailscale
description: "Drive Codex CLI on a remote macOS box: SSH + model fixes."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [macos, linux]
metadata:
  hermes:
    tags: [Codex, Tailscale, SSH, Remote, macOS, Cross-Machine, Coding-Agent]
    related_skills: [codex, github, hermes-agent]
---

# Remote Codex over Tailscale + SSH

Drive Codex CLI on a second machine (B) from the host the agent runs on (A),
over a private Tailscale link, with passwordless SSH. Use this to collaborate
with a Codex install on the user's laptop from their desktop (or vice versa).

## When to use

- "Connect to my laptop", "work with the Codex on my other computer", "build
  agents across two machines".
- The agent has a terminal on one host and must reach a second macOS box.

## Hard constraints (read first)

- **macOS installs and Remote Login need admin (sudo). The agent CANNOT type a
  password.** Hand the user copy-paste commands; never ask for the password in
  chat. (Optional: `SUDO_PASSWORD` in `~/.hermes/.env` lets the agent run sudo -
  user's choice, tell them the tradeoff.)
- The agent only reaches what is **network-reachable from its own host**. A
  machine on a different network needs Tailscale (or a VPN) first.
- GitHub is an async alternative to a live link: both machines clone the same
  repo and coordinate via branches/PRs (see the `github` skill). It needs no
  direct network path.

## Setup

### 1. Tailscale on both machines

- Install (GUI app; the user runs this and enters their admin password):
  `brew install --cask tailscale` then `open -a Tailscale` and sign in via the
  browser. The cask installs a `.pkg` with `sudo`, so it **fails headless** with
  "sudo: a terminal is required to read the password".
- Both machines must sign in to the **same account/tailnet**, or they will not
  see each other. If one is on a different account, use node sharing, or just
  re-login to the same account.
- Bundled CLI path: `/Applications/Tailscale.app/Contents/MacOS/Tailscale`
  (normally symlinked as `tailscale`).
- Verify from A:
  - `tailscale status` - lists peers with name, `100.x.y.z` address, `active; direct ...` or relayed.
  - `tailscale status --json` - parse peers in Python (empty list = not joined).
  - `tailscale ping <name>` - `direct` is best; `via DERP` is the relayed fallback (still works).

### 2. Enable SSH (Remote Login) on the target B

- `sudo systemsetup -setremotelogin on`, or System Settings -> General ->
  Sharing -> Remote Login. Both need admin.
- Check reachability from A: `nc -vz -G 4 <100.x.y.z> 22`
  ("succeeded" = port open; the SSH banner confirms with
  `ssh -o PreferredAuthentications=none nobody@<ip>` -> `Permission denied (publickey,...)`).

### 3. Passwordless SSH key

- On A: `ssh-keygen -t ed25519 -N "" -C "hermes-agent@<hostA>" -f ~/.ssh/<name>_ed25519`
- The user appends the **public** key to B's `~/.ssh/authorized_keys`
  (`mkdir -p ~/.ssh && chmod 700 ~/.ssh`, then append, then `chmod 600`).
- **Discover B's login username** - it is often not the hostname's owner.
  OpenSSH returns the same `Permission denied` for a wrong user and a wrong key,
  so iterate candidate usernames **with the key present**:
  `for u in <cands>; do ssh -i KEY -o BatchMode=yes "$u@<ip>" 'whoami'; done`
  The one that prints `whoami` is correct.
- Then verify: `ssh -i KEY -o BatchMode=yes <user>@<ip> 'hostname; whoami'`.

### 4. Driving Codex on B

- Push whole steps over one SSH call:
  `ssh -i KEY <user>@<ip> 'zsh -lc "cd <repo> && codex exec --sandbox workspace-write \"<task>\""'`
- Non-login `zsh` over SSH may lack `/opt/homebrew/bin` in PATH -> wrap with
  `zsh -lc` or use absolute paths. Hermes-side sessions use `bash -lc`.
- Codex must run inside a **git repo**; use `mktemp -d && git init -q` for scratch.
- **`--sandbox workspace-write` lets Codex edit files but blocks writes to
  `.git`.** It creates/edits the files, then its `git add`/`commit` fail ("this
  session cannot write to `.git`") and it prints the commands for you to run.
  Do the `git add`/`commit`/`push` yourself from the remote shell; never assume
  Codex committed.

### 5. Driving interactive CLIs on the remote (TUI, pickers, logins)

- A CLI that prints `<cmd> requires an interactive terminal` needs a real PTY;
  `nohup`/pipe/plain background will not do. Use tmux **by absolute path** on
  the remote (`/opt/homebrew/bin/tmux`) because non-login zsh over SSH lacks
  Homebrew in PATH:
  - `tmux kill-session -t job 2>/dev/null; tmux new-session -d -s job -x 200 -y 50 '<cmd>'`
  - answer a menu with `tmux send-keys -t job '1' Enter`; read it back with
    `tmux capture-pane -t job -p -S -300` (add `-S -300` for scrollback).
- macOS `script -q <logfile> <cmd>` is a lighter one-shot PTY allocator for
  capturing a menu without tmux.
- **Device-flow logins** (e.g. `hermes model --no-browser`, OAuth CLIs): the
  process prints `Open <url> ... enter code XXXX` and then polls. Relay the URL
  and code to the user to approve in their browser, then re-read the pane - the
  token is stored once they approve. The code is a one-time device code, not a
  password, so it is safe to relay.

## Codex fixes on macOS

### `Killed: 9` / `ENOENT .../@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/codex/codex`

Missing native platform binary (vendor dir empty). Reinstall:
`npm install -g @openai/codex`.

**Pitfall:** run npm from a **valid cwd**. If the shell's persistent cwd was a
`mktemp -d` dir that got deleted, npm dies with `uv_cwd ... ENOENT` and other
commands fail with `getcwd: cannot access parent directories`. `cd "$HOME"`
first, or pass an explicit `workdir`.

### `The '<model>' model is not supported when using Codex with a ChatGPT account`

Two root causes - check BOTH:

1. **Stale model pin** in `~/.codex/config.toml` (`model = "..."`) pointing at a
   retired or renamed slug. Back up the file, comment the line out, so Codex
   resolves its own default.
2. **Old CLI**: an old `codex` ships an outdated model catalog and rejects every
   model. Upgrade: `npm install -g @openai/codex@latest`.

Retired for ChatGPT sign-in: `gpt-5.4` (retired 2026-08-31), `gpt-5.5`
(retires 2026-10-14). Current catalog includes `gpt-6.1-sol`, `gpt-6-sol`,
`gpt-6-luna`, `gpt-6-astra`, `gpt-5.6-sol/terra/luna`. Availability still
varies by plan and rollout.

List what the installed CLI/account offers - `codex debug models` prints a
**huge** JSON (hundreds of KB); extract slugs only:

```
codex debug models 2>/dev/null | python3 -c 'import sys,json;d=json.load(sys.stdin);print("\n".join(m.get("slug","?") for m in d.get("models",[])))'
```

### Local-model (Ollama) configs

Some hosts route Codex through a local proxy, e.g.:

```
model = "gpt-6-sol"
openai_base_url = "http://127.0.0.1:11434/api/codex/v1"
model_catalog_json = "/Users/<u>/.codex/ollama-launch-models.json"
```

On such a host Codex works with names a **bare** ChatGPT account rejects. Do NOT
copy the pinned `model` to another host that lacks the proxy - that host will
fail with the "not supported" error. Either give it a supported model / CLI, or
(more work) expose the proxy over the tailnet (Ollama binds `127.0.0.1`, so it is
not reachable from the peer until rebound) and point the peer's
`openai_base_url` at `http://<tailscale-ip>:11434/api/codex/v1`.

### `gh` token invalid on the remote

`gh auth status` on B may show `The token in default is invalid` **even after the
user runs `gh auth login` on B**: a stale token in the macOS keyring survives the
interactive flow, and `~/.config/gh/hosts.yml` shows the account with no
`oauth_token` line. Do not trust that they "logged in" - re-check
`gh auth status`. The reliable fix is to copy the working token from the
authenticated machine A over SSH stdin (same account; get user consent - it moves
a secret - and never echo it):

```
gh auth token -h github.com | ssh -i KEY <user>@<ip> '/opt/homebrew/bin/gh auth login --with-token -h github.com'
ssh -i KEY <user>@<ip> '/opt/homebrew/bin/gh auth setup-git -h github.com'   # configure the git credential helper
```

`gh` needs its absolute path here (non-login shell over SSH lacks Homebrew in
PATH). Inspect `hosts.yml` with `sed -E 's/(oauth_token:).*/\1 [REDACTED]/'` -
when the token lives in the keyring the file has no token line to redact.

## Cloning a whole Hermes install to another machine

Goal: make machine B's Hermes behave like A's (same settings, skills, memory).

### What actually transfers

- Back up B first: `tar czf ~/.hermes-backup-$(date +%Y%m%d-%H%M%S).tgz -C ~
  .hermes/config.yaml .hermes/.env .hermes/auth.json .hermes/SOUL.md
  .hermes/memories .hermes/skills .hermes/cron .hermes/plugins .hermes/hooks`
- Copy `config.yaml`, `.env`, `auth.json`, `SOUL.md` (scp) plus `skills/` and
  `memories/` as exact mirrors (`rsync -az --delete`). Verify with `md5 -q` on
  both sides - checksums must match. `chmod 600 ~/.hermes/.env
  ~/.hermes/auth.json` after.
- Warn the user what a blind replace destroys: the target may already have its
  own skills, `cron/jobs.json`, plugins (e.g. `superpowers`), and memory. Count
  `find ~/.hermes/skills -name SKILL.md | wc -l` on both before deciding
  replace-vs-merge.
- Restart the gateway to load the new config: `hermes gateway restart`.

### OAuth logins do NOT transfer (the key trap)

`auth.json` copies file-identically, but the Nous Portal login is **bound to the
install and its refresh token rotates**. On the next start B strips the copied
token: `providers.nous.access_token` disappears and `hermes chat` fails with
`No access token found for Nous Portal login`. Each machine must authenticate
**once, itself** - never share `install_id` or one login across two machines
(rotation invalidates both).

### Driving that one-time login remotely (device flow)

`hermes model` refuses a pipe ("requires an interactive terminal"). Give it a
TTY on B with tmux, then read the `user_code` and relay it:

```
T=/opt/homebrew/bin/tmux   # full path - not in a non-login PATH over SSH
ssh B "$T new-session -d -s hlogin -x 200 -y 50 '~/.local/bin/hermes model --no-browser'"
ssh B "$T capture-pane -t hlogin -p | tail -4"      # shows the provider picker
ssh B "$T send-keys -t hlogin 1 Enter"              # 1 = the OAuth provider
ssh B "$T capture-pane -t hlogin -p -S -60"         # prints: Open <url> ... code XXXX-XXXX
```

Give the user the URL + code; the flow polls every second until they approve
(the code is a one-time device code, safe to relay - not a password). Verify
success: `auth.json` regains `access_token` and `hermes chat -q "..."` answers.

## Verification

- `tailscale ping <peer>` returns a path (direct preferred, DERP acceptable).
- `ssh ... 'codex exec "<trivial task>"'` actually **creates the artifact** it
  was asked for - read it back, do not trust the run's own summary.

## Pitfalls

- **macOS has no `timeout`.** Bound a possibly-hanging command with
  `( cmd & P=$!; sleep N; kill $P 2>/dev/null; wait $P 2>/dev/null )`.
- **zsh over SSH globbing**: an unquoted `(...)` or `===` in an `echo` string
  triggers `no matches found`. Avoid parens in remote echo labels; pass a
  single quoted `zsh -lc` payload.
- `codex --version` can hang or be `Killed: 9` on a broken install - that is the
  missing-native-binary symptom, not a version problem.
- **Non-login shells over SSH omit Homebrew (`/opt/homebrew/bin`)** - `tmux`,
  `codex`, `gh` report `command not found`. Call them by absolute path or wrap
  the payload in `zsh -lc` (Hermes-side sessions use `bash -lc`).
- Don't dump config files back in full when they are large; read only the
  relevant keys (e.g. `grep -n model ~/.codex/config.toml`).

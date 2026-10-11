# Cross-machine collaboration (Hermes ↔ Codex on another computer)

Hermes runs on ONE host and reaches only what is network-accessible from it. A
Codex CLI (or any coding agent) on a second machine needs an explicit link.
Pick from the table; they compose (e.g. Tailscale *then* SSH).

## Link options

| Link | How | When | Cost |
|---|---|---|---|
| GitHub as shared bus | Both machines clone the same repo; coordinate via branches / PRs / issues, all through `gh`. No direct link needed. | Default for async handoff; most robust; survives machines being offline. | $0 (GitHub Free: unlimited private repos). |
| Direct SSH | Enable Remote Login on the target; Hermes SSHes in and runs `codex` there: `ssh user@host 'cd repo && codex exec ...'`. | Same LAN, or a VPN/tailnet address. Most real-time — literally driving the other box. | $0 (+ VPN below if roaming). |
| Tailscale (roaming link) | Install Tailscale on both machines; each gets a stable 100.x address reachable from any network. Then SSH over the tailnet. | The laptop moves between Wi-Fi networks. | Personal plan, free (see below). |
| Shared database | Only if the DB is network-reachable (hosted Postgres / Supabase / Mongo Atlas, etc.). A local SQLite file is NOT visible from another machine unless exposed via an SSH tunnel or host. | Both agents read/write the same store. | Depends on host. |
| Codex Cloud | Codex runs on your GitHub repos in the cloud and opens PRs; Hermes interacts via `gh`. | No local link at all; GitHub is the only surface. | Covered by the Codex/ChatGPT plan. |

## Tailscale cost (verified Oct 2026)

- **Personal — $0, free forever:** up to **6 users**, **unlimited user devices**,
  50 tagged resources. Tailscale bills per **user (seat)**, not per device
  ("user devices are free and unlimited") — so one person with a laptop + a
  desktop is comfortably free.
- Standard: **$8/user/month**; Premium: **$18/user/month**.
- **Caveat:** Personal is *non-commercial use only*. For business use, go
  Standard ($8/user/mo).
- Extra tagged resources beyond the included 50: **$1/month each** (not needed for
  a two-machine setup).

## Tailscale + SSH: bringing a second machine in (the roaming link)

Install on BOTH machines and sign in with the SAME account so they land in one
tailnet, then connect.

1. **Install Tailscale (macOS):** `brew install --cask tailscale-app` (or the
   .pkg / Mac App Store). The pkg installer runs under `sudo`, so the Hermes
   agent CANNOT finish it — there is no way to type an admin password. Hand the
   user the exact command to paste in Terminal, or (only if they accept) have
   them set `SUDO_PASSWORD` in `~/.hermes/.env`. The sign-in itself is a browser
   OAuth — the user does it.
2. **Verify from the agent host.** The macOS CLI is bundled in the app:
   `/Applications/Tailscale.app/Contents/MacOS/Tailscale`. Run
   `tailscale status` and `tailscale status --json` (parse the `Peer` map).
   Confirm a peer shows `active; direct <ip>:41641` (best) or `via DERP`
   (fallback, still works). `tailscale ping <peer>` prints `pong ... via ...` —
   use it to prove the tunnel before blaming SSH.
3. **Enable Remote Login (SSH) on the target:** System Settings → General →
   Sharing → Remote Login → on (macOS, also needs admin). Check reachability
   from the agent host: `nc -vz -G 4 <100.x.y.z> 22`.
4. **Set up key auth — the agent never types passwords.** Generate a dedicated
   key on the agent host:
   `ssh-keygen -t ed25519 -N "" -f ~/.ssh/<name>_ed25519`. Have the user append
   the `.pub` to the target's `~/.ssh/authorized_keys` (with `mkdir -p ~/.ssh &&
   chmod 700 ~/.ssh` and `chmod 600 authorized_keys`) and report `whoami` — you
   need the remote username. Then verify:
   `ssh -i ~/.ssh/<name>_ed25519 <user>@<100.x.y.z> 'hostname; whoami'`.
5. Once in, drive Codex remotely:
   `ssh -i <key> <user>@<ip> 'cd repo && codex exec ...'`.

### Pitfalls

- **`tailscale status` shows `peers: []` while the user insists "addresses are
  visible."** They are reading the admin console (or another account's machine
  list). Empty peers = the machines are NOT in the same tailnet: the second
  machine is signed in with a different account, or is offline. Fix by signing
  both in with the same account, or use node sharing / an invite.
- **SSH replies `Permission denied (publickey,password,keyboard-interactive)`.**
  That is a healthy server — port 22 is open and sshd is up; you merely lack
  credentials. It is the green light to do key setup, not a connection failure.
- **macOS admin steps block the agent.** Tailscale's pkg install and enabling
  Remote Login both need `sudo`. Never type or ask for the password in chat;
  hand the user a copy-paste command they run themselves, or (only if they
  choose) have them set `SUDO_PASSWORD` in `~/.hermes/.env`.
- **The remote shell is zsh — quote it and wrap it in a login shell.** `echo
  ===X===` and bare parentheses in the remote command trip zsh globbing
  (`no matches found` / `== not found`); avoid `===` and unquoted `()` in remote
  `echo`s. Also run through a LOGIN shell: `ssh host 'zsh -lc "codex
  --version"'` — a plain non-login remote shell may lack Homebrew on `PATH`, so
  `codex` reports `command not found` even though it is installed.
- **Discover the remote username by probing, not only by asking.** With the key
  already authorized, loop candidates with `ssh -i <key> -o BatchMode=yes
  <candidate>@<ip> 'whoami'`: the wrong user returns `Permission denied`, the
  right one returns the name. Faster than round-trips when the user is unsure of
  their short username (both machines here happened to share it).

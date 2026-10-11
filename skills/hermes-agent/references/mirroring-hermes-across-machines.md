# Mirroring a Hermes install to another machine

Goal: make machine B's Hermes behave like machine A's - same config, skills,
memory, secrets - so the two are interchangeable.

## What to copy (A -> B)

- `config.yaml` (settings), `.env` (secrets - get consent, see below)
- `SOUL.md`, `memories/`, `skills/`
- `cron/`, `plugins/`, `hooks/` when the user wants those too
- `auth.json` - copying it does NOT transfer the login (see hard rule below)

## Procedure

1. **Back up B's `~/.hermes` first** (it may hold its own skills, cron jobs,
   plugins, memory). Tar the identity files/dirs into `~/.hermes-backup-<ts>.tgz`.
2. Copy over SSH. **Mirror** (replace) skills and memory with `--delete`; scp
   the rest, then lock down permissions:
   - `rsync -az --delete -e "ssh -i KEY" ~/.hermes/skills/   USER@IP:.hermes/skills/`
   - `rsync -az --delete -e "ssh -i KEY" ~/.hermes/memories/ USER@IP:.hermes/memories/`
   - `scp -i KEY ~/.hermes/{config.yaml,.env,auth.json,SOUL.md} USER@IP:.hermes/`
   - on B: `chmod 600 ~/.hermes/.env ~/.hermes/auth.json`
3. **Restart B's gateway** so it loads the new config: `hermes gateway restart`.
   Check first with `pgrep -lf hermes` - it is often launchd-supervised.
4. **Verify:** `md5 -q` the copied files on both sides (must match), then
   `hermes status` (shows model/provider) and `hermes chat -q "<trivial task>"`.
   A chat that answers proves the whole chain; a status that reads config proves
   nothing about auth.

## Hard rule: logins are per-install, a copy does not transfer them

- OAuth / portal credentials (Nous Portal, ChatGPT-subscription OAuth, ...) are
  bound to the install and their refresh tokens rotate. **Copying `auth.json`
  does not work:** on B's next start Hermes strips the copied
  `access_token`/`refresh_token` (the file changes; `has access_token` becomes
  false) and B reports `No access token found for <provider> login`.
- Do **not** share one login across two live instances or copy `install_id` to
  "fix" it - single-use refresh rotation invalidates the peer, breaking both.
- Correct fix: log B in **once, at B** (`hermes model --no-browser`, or
  `hermes portal`), completing the device flow. Everything else - API keys in
  `.env`, skills, memory, config - copies fine.
- `hermes model` and similar pickers require an interactive terminal; over SSH
  drive them with tmux by absolute path (see the
  `remote-codex-over-tailscale` skill).

## Notes

- **Version drift is tolerated for data files:** a newer `config.yaml` (e.g.
  from 0.21.6) loads fine on a slightly older Hermes (0.21.0). Don't block the
  copy on aligning versions.
- Copying `.env` **duplicates every API key** onto B. Get explicit consent.
- The target often is not empty - it may have more skills than the source.
  Prefer offering a **merge** (union of skills) over a blind replace, and always
  back up before overwriting.

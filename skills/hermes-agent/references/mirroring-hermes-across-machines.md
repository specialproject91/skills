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

## Sharing only your skills: a catalog repo, not a full mirror

A full mirror is heavy-handed. When the goal is just "the other machine should
have my skills", publish a **catalog**: a GitHub repo laid out as a Hermes tap
(`skills/<name>/SKILL.md`) holding only the non-bundled and user-modified skills
(`hermes skills list-modified`). Leave stock bundled skills out - the other
machine ships them already, and duplicating them freezes them against upstream
updates. Record each skill's category (its parent directory) alongside the files
so a consumer can file it back identically; `hermes skills list` takes the
category from the directory, not from the frontmatter.

- `hermes skills tap add owner/repo` subscribes (path defaults to `skills/`;
  non-default layouts need an edit to `~/.hermes/skills/.hub/taps.json`).
- **`hermes skills install` from a tap is usually blocked, by design.** New taps
  get `community` trust, and the Skills Guard scores any skill that documents SSH
  keys, `sudo`, or `~/.hermes` paths as `dangerous` (`ssh_keygen`, `ssh_backdoor`,
  `sudo_usage`, `hermes_config_ref`, ...). A dangerous verdict on a community or
  trusted source is **unoverridable** - `--force` will not do it and there is no
  user-side trust knob (only a Hermes core PR adding the repo to
  `TRUSTED_REPOS` in `tools/skills_guard.py`). Tap + `inspect` still work.
  Do not go looking for a bypass: a skill that trips these rules is exactly the
  kind a scanner should refuse.
- On your own machines, skip the hub. Either copy the catalog's files straight
  into `~/.hermes/skills/` (back up whatever you replace), or point
  `skills.external_dirs` at a clone of the repo. Copying in is the variant that
  works for **edited bundled** skills, because it lands them as `user-modified`
  on the receiving machine, matching the sending one; `external_dirs` is
  lower precedence than a same-named local skill, so it cannot deliver edits to
  a bundled skill.
- Consumers should pull before they publish: whichever machine made the edit is
  the one that pushes, and an unconditional copy from the repo is how the two
  stay in step.

### The catalog these machines actually use

`specialproject91/skills`, cloned at `~/skills` on both the iMac and the laptop.
`sync.sh` rebuilds `skills/` + `catalog.json` from `~/.hermes/skills` and pushes;
`pull.sh` updates the checkout, then copies the catalog into the profile and
backs up anything it replaces under `~/.hermes/skills-backups/<ts>/` (nothing in
the profile is ever deleted). Publish on the machine that made the edit, pull on
the other. `HERMES_SKILLS=<profile>/skills` retargets another profile.

Verify a pull two ways, and do both: checksum each skill directory on both sides
(`find <dir> -type f ! -name .DS_Store | sort | xargs md5 -q | md5 -q`) to prove
the bytes arrived, then ask the receiving Hermes to name a catalog skill in
`hermes chat --toolsets skills -q "<which skill covers ...>"` to prove the
profile actually loads it.

## Notes

- **Version drift is tolerated for data files:** a newer `config.yaml` (e.g.
  from 0.21.6) loads fine on a slightly older Hermes (0.21.0). Don't block the
  copy on aligning versions.
- Copying `.env` **duplicates every API key** onto B. Get explicit consent.
- The target often is not empty - it may have more skills than the source.
  Prefer offering a **merge** (union of skills) over a blind replace, and always
  back up before overwriting.

# skills — Hermes skill catalog

A GitHub repo of `SKILL.md` directories shared between the Hermes installs on
`wandas-imac` and `marcins-macbook-pro`. It is laid out as a Hermes
[skill tap](https://hermes-agent.nousresearch.com/docs/user-guide/features/skills#publishing-a-custom-skill-tap),
and `pull.sh` installs it into a profile.

## What's in here

Only skills that are *ours*: written here, or a bundled Hermes skill edited
locally (`hermes skills list-modified`). Stock bundled skills are deliberately
**not** copied — the other machine already ships them, and duplicating them
would freeze them against upstream updates. `catalog.json` records, per skill,
the source machine's category and whether it is local or modified-bundled.

## Two channels

**`pull.sh` — the one that works for these skills.** Copies the catalog into the
Hermes profile (`~/.hermes/skills/`), backing up anything it replaces:

```bash
git clone https://github.com/specialproject91/skills.git ~/skills   # once
~/skills/pull.sh
~/skills/pull.sh --dry-run
```

An edited bundled skill arrives as `user-modified` on the receiving machine, which
is exactly its state on the sending machine — so `hermes update` protects it there
too. Backups land in `~/.hermes/skills-backups/<timestamp>/`.

**The tap (`hermes skills tap add`) — for discovery, blocked on install.** Adding
the tap works and lets the other machine browse and `inspect` the catalog:

```bash
hermes skills tap add specialproject91/skills
hermes skills tap list          # confirms path: skills/
hermes skills inspect specialproject91/skills/<skill-name>
```

but `hermes skills install` from it fails by design. New taps get `community`
trust, the Skills Guard scores these skills `dangerous` (they document SSH keys,
`sudo`, `~/.hermes` config paths — the scanner's `ssh_keygen`, `ssh_backdoor`,
`sudo_usage`, `hermes_config_ref` rules), and a dangerous verdict on a community
source is **not** overridable, not even with `--force`. That is the guard working
as intended, not a bug to work around: raise the repo to trusted trust would mean
a Hermes core PR adding it to `TRUSTED_REPOS` in `tools/skills_guard.py`. Use
`pull.sh` for these.

## Publish from the machine where you edited the skill

```bash
./sync.sh              # rebuild skills/ + catalog.json, commit, push
./sync.sh --dry-run    # show what would be synced, change nothing
./sync.sh --no-push    # rebuild and commit locally only
```

Run it on either machine — whichever machine made the edit is the one that
publishes it. `HERMES_SKILLS=/path/to/profile/skills ./sync.sh` targets another
profile.

## Layout

```
skills/<skill-name>/SKILL.md   # one directory per skill; dir name = skill name
catalog.json                   # name -> {category, source}, written by sync.sh
sync.sh                        # publish: profile -> catalog -> GitHub
pull.sh                        # consume: GitHub -> catalog -> profile
```

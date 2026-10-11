# skills — Hermes skill tap

A [Hermes skill tap](https://hermes-agent.nousresearch.com/docs/user-guide/features/skills#publishing-a-custom-skill-tap):
a GitHub repo of `SKILL.md` directories that any Hermes install can subscribe
to. No registry, no release pipeline.

Maintained by `specialproject91` from `wandas-imac`; consumed by Hermes on
`marcins-macbook-pro` (and anything else that wants the same skills).

## What's in here

Only skills that are *ours*: written here, or a bundled Hermes skill that was
edited locally (`hermes skills list-modified`). Stock bundled skills are
deliberately **not** copied — the other machine already ships them, and
duplicating them would shadow upstream updates.

## Subscribe (on the other machine)

```bash
hermes skills tap add specialproject91/skills
hermes skills tap list                       # confirms path: skills/
hermes skills install specialproject91/skills/<skill-name>
```

Or install one skill without subscribing:

```bash
hermes skills install specialproject91/skills/<skill-name>
```

New taps get `community` trust, so each first install runs the normal security
scan and shows the third-party warning panel. That is expected.

## Update

```bash
hermes skills update        # on the consumer: pull newer versions
```

Locally edited skills are never overwritten by an update unless `--force`.

## Publish from the source machine

```bash
./sync.sh              # rebuild skills/, commit, push
./sync.sh --dry-run    # show what would be synced, change nothing
./sync.sh --no-push    # rebuild and commit locally only
```

`sync.sh` rebuilds `skills/` from `~/.hermes/skills` (override with
`HERMES_SKILLS=...`) — every non-bundled skill plus every bundled skill listed
by `hermes skills list-modified` — then prunes anything that no longer
qualifies. Run it after creating or editing a skill.

## Layout

```
skills/<skill-name>/SKILL.md    # one directory per skill; dir name = install slug
sync.sh                         # rebuild + push this catalog
```

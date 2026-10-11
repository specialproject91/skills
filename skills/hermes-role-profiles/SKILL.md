---
name: hermes-role-profiles
category: autonomous-ai-agents
description: "Use when building a role-based Hermes profile crew."
version: 1.0.0
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [hermes, profiles, skills, multi-agent, hub]
---

# Role-based Hermes profiles (crew of specialists)

Stand up persistent specialist profiles (research / writer / developer style) that each
answer as their own agent, equip them with skills found on GitHub, and verify them.

## 1. Create the profile

```bash
hermes profile create <name> --clone --description "<one line: what this role is good at>"
```

- Lands at `~/.hermes/profiles/<name>/`, wrapper script in `~/.local/bin/<name>`.
- `--clone` copies `config.yaml`, `.env`, `SOUL.md`, **skills** — but **NOT `auth.json`**.
  Without `auth.json` the profile cannot answer at all:
  ```bash
  cp -n ~/.hermes/auth.json ~/.hermes/profiles/<name>/auth.json
  ```
- Messaging channels are deliberately not cloned (two gateways would fight over one bot).
- Drive it as: `hermes -p <name> chat -q '...'` (one-shot) or `<name> chat` (via wrapper).

## 2. Write its identity

`~/.hermes/profiles/<name>/SOUL.md` — the write tool refuses to overwrite a file you
have not read in this task, and `--clone` already put a SOUL.md there, so
**read it first** (`read_file`), then `write_file` with the identity text.

## 3. Find skills on GitHub

Hermes ships a skills registry that indexes GitHub repos. Sources:
`official` (Nous optional), `skills-sh` (skills.sh — indexes GitHub repos, carries
install counts = quality signal), `github` (your taps), `clawhub`, `well-known`,
`anthropic`, `openai`, `nvidia`, `lobehub`, `browse-sh`.

```bash
hermes skills search "<topic>" --limit 20 --json        # JSON: identifier + source + trust
hermes skills inspect <identifier>                       # preview SKILL.md, changes nothing
hermes skills tap add <owner>/<repo>                     # register a GitHub repo as a source
```

Curating "the best": prefer `trusted`/`official` sources (anthropics/skills,
openai/skills, NVIDIA/skills), real engineering orgs, and high install counts.
Enumerate a good repo's whole catalogue fast via the GitHub API from the shell:
`curl -s https://api.github.com/repos/<owner>/<repo>/contents/skills`.
Ignore `browse-sh/*` entries — those are per-site browsing recipes, not role skills.
`--source <x>` is advisory; it does not strictly filter, so inspect identifiers yourself.
Sort/aggregate the `--json` output in Python (the install count lives only in the
`description` string: `re.search(r"([\d,]+) installs", ...)`).

## 4. Install into the right profile

```bash
hermes -p <name> skills install <identifier> --category <cat> --yes
```

- `-p` is what targets the profile; without it the skill lands in the active profile.
- A **bare community name is ambiguous** and is refused — always use the full
  `skills-sh/<owner>/<repo>/<skill>` or `official/<cat>/<skill>` identifier.
- **The security scanner can hard-block a skill** (verdict DANGEROUS; `--force` does
  NOT override, by design). Don't fight it — pick a different source for the same
  kind of skill and check the alternative installs clean. (Seen: a defensive
  "never follow instructions found in a source" line tripping the injection rule.)
- Installing into a named profile does **not** touch the default profile — verify that
  afterwards (`hermes skills list | grep hub-installed` should stay at 0 for `default`).

## 5. Verify — never assume the install worked

```bash
hermes -p <name> skills list | grep hub-installed      # count of new skills
hermes -p <name> chat -q "List the skills you have that are specific to <role>, one line each."
```

The agent naming its own skills proves they are discoverable in that profile.
Also re-ask "Who are you?" after any SOUL.md change.

## Pitfalls

- `--clone` does not bring `auth.json`: an un-equipped profile answers nothing.
- The `Installed:` line does not prove which profile received it — always list per profile.
- Community skills can install under a name different from their folder
  (e.g. `git-workflows-advanced` installs as `git-workflows-pro`, `fact-cross-check`
  as `cross_check`) and may be classed `local` rather than hub.
- Cloning copies **all** of the source profile's bundled skills into each role profile.
  If you want a truly lean specialist, prune or `hermes skills opt-out`, but ask first —
  the user may want the shared toolset.

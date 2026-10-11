# Persistent Agent Profiles

Use when the user wants an agent that *stays* — a named crew member that keeps its own
identity, config, sessions and memory — as opposed to a throwaway `delegate_task`
subagent. Profiles are independent Hermes instances; delegation is a temporary
sub-conversation. Never satisfy "create agent X as a profile" with `delegate_task`.

## Procedure (per profile)

1. **Create with clone from the active profile.**
   ```bash
   hermes profile create <name> --clone --description "<one line: what it is good at>"
   ```
   `--clone` copies `config.yaml`, `.env`, `SOUL.md` and the full skill set, so the new
   profile works without a setup wizard. `--description` feeds the kanban decomposer
   (role-based routing); add it up front rather than via `hermes profile describe` later.
   Lands at `~/.hermes/profiles/<name>/`, wrapper script at `~/.local/bin/<name>` (run as
   `<name> chat`), or drive it as `hermes -p <name> chat -q "..."`.

2. **Copy `auth.json` — the clone does NOT bring it.**
   ```bash
   cp -n ~/.hermes/auth.json ~/.hermes/profiles/<name>/auth.json
   ```
   Without this the profile has config and skills but no credentials and cannot answer.
   `-n` (no-clobber) keeps an existing file intact, so the step is safe to re-run and
   safe for a profile that was already authenticated. Applies equally when cloning from a
   non-default source profile — copy from *that* profile's home.

3. **Write the identity into `<profile home>/SOUL.md`.**
   SOUL.md is a system prompt: write it as a direct second-person instruction ("Your name
   is X. You are ..."), not as a description *about* the agent. State what it does, what
   it refuses, and which sibling profiles own those jobs, so the crew does not collide.
   **Read the cloned SOUL.md before overwriting it** — the `write_file` tool refuses to
   overwrite a file this task has not fully read, and `--clone` always leaves one there.
   A `read_file` on the path then `write_file` is the fix; `patch` is the alternative for
   a small targeted edit. Do not skip the read and retry blindly — the refusal repeats.
   **Substitute the owner's real name** wherever the identity says "the owner" (resolve it
   from memory/profile and say which name you used, so a wrong guess is one edit away).

4. **Verify before starting the next one.**
   ```bash
   hermes -p <name> chat -q "Who are you?"
   ```
   A one-shot run, ~10-15s, and it creates a session — that is expected. Read the reply
   and check it names the right agent and the right role; a profile that echoes the
   default Hermes persona means SOUL.md did not take (wrong path, or an overwrite that
   silently failed).

## Pitfalls

- **`--clone` clones no messaging channels** (by design: two profiles sharing one bot
  token make two gateways fight over it). Do not "fix" it with `--clone-channels` unless
  the user wants a second gateway on their own token. If the user expects a chat bot per
  profile, tell them each profile needs its own bot, then `hermes -p <name> setup`.
- **Never create a profile for the main agent itself** when the user asks for a crew —
  the requesting agent stays as it is and only the named siblings get profiles.
- **Verify each one individually.** A batch create-then-check-later hides a single
  profile whose identity did not land; the report the user gets must name each profile's
  path *and* its own answer.
- **Profiles persist across `hermes update`** for user data, but the bundled hub skills'
  SKILL.md is re-synced — put local customisations in the profile's own files
  (SOUL.md, config, its skills), not by editing bundled skill bodies and expecting them
  to survive.

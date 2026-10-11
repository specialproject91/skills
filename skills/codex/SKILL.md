---
name: codex
description: "Delegate coding to OpenAI Codex CLI (features, PRs)."
version: 1.0.1
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Coding-Agent, Codex, OpenAI, Code-Review, Refactoring]
    related_skills: [claude-code, hermes-agent]
---

# Codex CLI

Delegate coding tasks to [Codex](https://github.com/openai/codex) via the Hermes terminal. Codex is OpenAI's autonomous coding agent CLI.

## When to use

- Building features
- Refactoring
- PR reviews
- Batch issue fixing

Requires the codex CLI and a git repository.

## Prerequisites

- Codex installed: `npm install -g @openai/codex`
- OpenAI auth configured: either `OPENAI_API_KEY` or Codex OAuth credentials
  from the Codex CLI login flow
- **Must run inside a git repository** — Codex refuses to run outside one
- Use `pty=true` in terminal calls — Codex is an interactive terminal app

For Hermes itself, `model.provider: openai-codex` uses Hermes-managed Codex
OAuth from `~/.hermes/auth.json` after `hermes auth add openai-codex`. For the
standalone Codex CLI, a valid CLI OAuth session may live under
`~/.codex/auth.json`; do not treat a missing `OPENAI_API_KEY` alone as proof
that Codex auth is missing.

## One-Shot Tasks

```
terminal(command="codex exec 'Add dark mode toggle to settings'", workdir="~/project", pty=true)
```

For scratch work (Codex needs a git repo):
```
terminal(command="cd $(mktemp -d) && git init && codex exec 'Build a snake game in Python'", pty=true)
```

## Background Mode (Long Tasks)

```
# Start in background with PTY
terminal(command="codex exec --sandbox workspace-write 'Refactor the auth module'", workdir="~/project", background=true, pty=true)
# Returns session_id

# Monitor progress
process(action="poll", session_id="<id>")
process(action="log", session_id="<id>")

# Send input if Codex asks a question
process(action="submit", session_id="<id>", data="yes")

# Kill if needed
process(action="kill", session_id="<id>")
```

## Key Flags

| Flag | Effect |
|------|--------|
| `exec "prompt"` | One-shot execution, exits when done |
| `--sandbox workspace-write` (`-s`) | Sandboxed but auto-approves file changes in the workspace (the recommended auto-build mode) |
| `--dangerously-bypass-approvals-and-sandbox` | No sandbox, no approvals (fastest, most dangerous; `--yolo` still works as a hidden alias) |
| `--sandbox danger-full-access` | No Codex sandbox; useful when the host service context breaks bubblewrap |

> **Deprecated:** `--full-auto` still works but the live CLI warns to use `--sandbox workspace-write` instead.

## Hermes Gateway Caveat

When invoking the Codex CLI from a Hermes gateway/service context (for example,
Telegram-driven agent sessions), Codex `workspace-write` sandboxing may fail even
when the same command works in the user's interactive shell. A typical symptom is
bubblewrap/user-namespace errors such as `setting up uid map: Permission denied`
or `loopback: Failed RTM_NEWADDR: Operation not permitted`.

In that context, prefer:

```
codex exec --sandbox danger-full-access "<task>"
```

Use process boundaries as the safety layer instead: explicit `workdir`, clean git
status before launch, narrow task prompts, `git diff` review, targeted tests, and
human/agent confirmation before committing broad changes.

## PR Reviews

Clone to a temp directory for safe review:

```
terminal(command="REVIEW=$(mktemp -d) && git clone https://github.com/user/repo.git $REVIEW && cd $REVIEW && gh pr checkout 42 && codex review --base origin/main", pty=true)
```

## Parallel Issue Fixing with Worktrees

```
# Create worktrees
terminal(command="git worktree add -b fix/issue-78 ~/.hermes/cache/scratch/issue-78 main", workdir="~/project")
terminal(command="git worktree add -b fix/issue-99 ~/.hermes/cache/scratch/issue-99 main", workdir="~/project")

# Launch Codex in each
terminal(command="codex --sandbox workspace-write exec 'Fix issue #78: <description>. Commit when done.'", workdir="~/.hermes/cache/scratch/issue-78", background=true, pty=true)
terminal(command="codex --sandbox workspace-write exec 'Fix issue #99: <description>. Commit when done.'", workdir="~/.hermes/cache/scratch/issue-99", background=true, pty=true)

# Monitor
process(action="list")

# After completion, push and create PRs
terminal(command="cd ~/.hermes/cache/scratch/issue-78 && git push -u origin fix/issue-78")
terminal(command="gh pr create --repo user/repo --head fix/issue-78 --title 'fix: ...' --body '...'")

# Cleanup
terminal(command="git worktree remove ~/.hermes/cache/scratch/issue-78", workdir="~/project")
```

## Batch PR Reviews

```
# Fetch all PR refs
terminal(command="git fetch origin '+refs/pull/*/head:refs/remotes/origin/pr/*'", workdir="~/project")

# Review multiple PRs in parallel
terminal(command="codex exec 'Review PR #86. git diff origin/main...origin/pr/86'", workdir="~/project", background=true, pty=true)
terminal(command="codex exec 'Review PR #87. git diff origin/main...origin/pr/87'", workdir="~/project", background=true, pty=true)

# Post results
terminal(command="gh pr comment 86 --body '<review>'", workdir="~/project")
```

## Rules

1. **Always use `pty=true`** — Codex is an interactive terminal app and hangs without a PTY
2. **Git repo required** — Codex won't run outside a git directory. Use `mktemp -d && git init` for scratch
3. **Use `exec` for one-shots** — `codex exec "prompt"` runs and exits cleanly
4. **`--sandbox workspace-write` for building** — auto-approves changes within the sandbox (`--full-auto` is deprecated for this)
5. **Background for long tasks** — use `background=true` and monitor with `process` tool
6. **Don't interfere** — monitor with `poll`/`log`, be patient with long-running tasks
7. **Parallel is fine** — run multiple Codex processes at once for batch work

## Troubleshooting

- **`spawn ... ENOENT` on launch, or the launcher dies with `Killed: 9`** — the
  platform-native binary is missing from the install (a partial/failed npm
  install leaves the per-platform package's `vendor/<target>/` without the
  `codex` executable). Reinstall fixes it:
  `npm install -g @openai/codex` (it fetches the correct
  `@openai/codex-<os>-<arch>` optional dep). Diagnose with `codex doctor`;
  confirm auth separately with `codex login status` (prints e.g.
  `Logged in using ChatGPT`). `codex --version` reports as `codex-cli X.Y.Z`.
- **npm aborts with `ENOENT ... uv_cwd`** — npm cannot resolve its working
  directory because the Hermes shell's persistent cwd points at a directory that
  no longer exists (classically a `mktemp -d` scratch dir an earlier call made
  and cleanup removed — including the install dir an `npm uninstall` just
  deleted). Reset first: pass an explicit `workdir` to the terminal call (e.g.
  the home directory) or `cd` to an existing path *before* any npm command.
- **`The '<model>' model is not supported when using Codex with a ChatGPT
  account` (HTTP 400).** Codex signed in with a ChatGPT/OAuth login only accepts
  the account's CURRENT model slugs. Two usual causes, fix both:
  - A stale hard-pinned `model = "..."` in `~/.codex/config.toml` (or a
    repo-local `.codex/config.toml`) naming a retired slug. Comment it out so
    Codex resolves its own current default, backing the file up first:
    `cp config.toml config.toml.bak && sed -i '' 's/^model = .*/# model pin removed/' config.toml`
    (macOS `sed` needs the empty `-i ''`). A pin you did not verify only re-breaks
    the next run.
  - An **outdated CLI**: old versions ship a stale model catalog and reject every
    slug, including ones the account supports. Upgrade FIRST:
    `npm install -g @openai/codex@latest`. The catalog is refreshed by the CLI
    binary itself, NOT by `codex login`.
  Listing the account's real catalog: `codex debug models` prints a huge JSON, so
  filter it:
  `codex debug models | python3 -c "import sys,json;print('\n'.join(m['slug'] for m in json.load(sys.stdin)['models']))"`.
- **A working `codex` may be routed through a local gateway.** `openai_base_url`
  + `model_catalog_json` in `config.toml` (e.g. Ollama on
  `http://127.0.0.1:11434/api/codex/v1`) make a pinned model resolve even when
  the ChatGPT account would reject it. When MIRRORING a config across machines,
  copy the WHOLE provider block, not just the `model` line — a second machine
  that inherits only the model name (no base_url) fails the support check.

## Working with Codex on another computer

Hermes runs on one host and reaches only what is network-accessible from it. To
collaborate with a Codex CLI living on a second machine (over GitHub, SSH,
Tailscale, a shared DB, or Codex Cloud), see
`references/cross-machine-collaboration.md` — a decision table of the link
options, verified Tailscale pricing, and the Tailscale + SSH onboarding
steps (install → verify peers → SSH key auth) with their pitfalls.

#!/usr/bin/env bash
# sync.sh — rebuild ./skills/ (this catalog) from this machine's Hermes profile.
#
#   ./sync.sh              rebuild, commit and push
#   ./sync.sh --no-push    rebuild and commit locally only
#   ./sync.sh --dry-run    show what would change, touch nothing
#
# A skill is included when it is NOT bundled with Hermes (agent-created,
# profile-local) or when it IS bundled but you have edited it
# (`hermes skills list-modified`). Untouched bundled skills are skipped: the
# consuming machine already ships them, and shipping them again would shadow
# upstream updates.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HERMES_SKILLS="${HERMES_SKILLS:-$HOME/.hermes/skills}"

DRY=""
PUSH=1
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --no-push) PUSH=0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

python3 - "$REPO" "$DRY" <<'PY'
import json, os, re, shutil, socket, subprocess, sys, time

repo, dry = sys.argv[1], bool(sys.argv[2])
src = os.environ["HERMES_SKILLS"]
dest = os.path.join(repo, "skills")

if not os.path.isdir(src):
    sys.exit(f"no Hermes skills dir at {src}")

manifest_path = os.path.join(src, ".bundled_manifest")
bundled = set()
if os.path.isfile(manifest_path):
    for line in open(manifest_path):
        if ":" in line:
            bundled.add(line.split(":", 1)[0].strip())

modified = set()
try:
    out = subprocess.run(["hermes", "skills", "list-modified"],
                         capture_output=True, text=True, timeout=120).stdout
    modified = set(re.findall(r"^\s*[~>]\s+(\S+)\s*$", out, re.M))
except Exception as exc:  # noqa: BLE001 - best effort
    print(f"! could not run `hermes skills list-modified` ({exc}); "
          f"only non-bundled skills will be synced", file=sys.stderr)

JUNK_DIRS = {"__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".git"}
JUNK_FILES = {".DS_Store"}

def ignore(_dir, names):
    return [n for n in names if n in JUNK_DIRS or n in JUNK_FILES or n.endswith(".pyc")]

# Every directory holding a SKILL.md is a skill; its parent (relative to the
# skills root) is the category pull.sh files it back under in a profile.
found = {}
for root, dirs, files in os.walk(src):
    dirs[:] = [d for d in dirs if not d.startswith(".")]
    if "SKILL.md" in files:
        name = os.path.basename(root)
        category = os.path.dirname(os.path.relpath(root, src))
        found.setdefault(name, []).append((root, "" if category == "." else category))
        dirs[:] = []

keep, skipped = {}, []
for name, entries in sorted(found.items()):
    if len(entries) > 1:
        print(f"! duplicate skill name {name}: {[p for p, _ in entries]}", file=sys.stderr)
    if name in bundled and name not in modified:
        skipped.append(name)
        continue
    keep[name] = entries[0]

if not keep:
    sys.exit("nothing to sync (no local or user-modified skills found)")

catalog = {
    "generated_on": socket.gethostname(),
    "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "skills": {n: {"category": c,
                   "source": "modified-bundled" if n in modified else "local"}
               for n, (_, c) in keep.items()},
}

os.makedirs(dest, exist_ok=True)
for name, (path, category) in keep.items():
    print(f"+ {name}  [{catalog['skills'][name]['source']}] category={category or '-'}")
    if dry:
        continue
    target = os.path.join(dest, name)
    if os.path.isdir(target):
        shutil.rmtree(target)
    shutil.copytree(path, target, ignore=ignore)

if not dry:
    for name in sorted(os.listdir(dest)):
        if name.startswith(".") or name in keep:
            continue
        print(f"- {name}  (removed)")
        p = os.path.join(dest, name)
        shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
    with open(os.path.join(repo, "catalog.json"), "w") as fh:
        json.dump(catalog, fh, indent=2, sort_keys=True)
        fh.write("\n")

print(f"\n{len(keep)} skill(s) in the catalog, {len(skipped)} untouched bundled skill(s) skipped")
PY

if [ -n "$DRY" ]; then
  echo "dry run — no files written"
  exit 0
fi

cd "$REPO"
git add -A
if git diff --cached --quiet; then
  echo "catalog already up to date — nothing to commit"
  exit 0
fi
git commit -q -m "chore(skills): sync skills from $(hostname -s)"
if [ "$PUSH" = 1 ]; then
  git push -q origin HEAD
  echo "pushed to $(git remote get-url origin)"
fi

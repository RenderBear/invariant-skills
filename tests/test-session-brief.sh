#!/bin/sh
# Verify reusable brief receipts stay non-authoritative, shared, and causally fresh.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/invariant-session-brief-test.XXXXXX")
framework=$(mktemp -d "${TMPDIR:-/tmp}/invariant-session-framework-test.XXXXXX")
linked="$fixture-linked"
cleanup() { rm -rf "$fixture" "$framework" "$linked"; }
trap cleanup EXIT HUP INT TERM

mkdir -p "$framework/skills"
cp -R "$root/skills/intent-brief" "$root/skills/intent-land" "$root/skills/intent-coordinate" "$framework/skills/"
session_brief="$framework/skills/intent-brief/scripts/session-brief.sh"

git -C "$fixture" init -qb main
git -C "$fixture" config user.name test
git -C "$fixture" config user.email test@example.com
git -C "$fixture" config commit.gpgsign false
mkdir -p "$fixture/.intent/observations" "$fixture/src"
printf 'seed\n' >"$fixture/src/a file.py"
cat >"$fixture/.intent/config.yml" <<'EOF'
version: 1
resolution: assisted
integration_branch: main
EOF
cat >"$fixture/.intent/DOMAINS.yml" <<'EOF'
version: 1
domains:
  - id: source
    description: Owns source behavior.
    authority: user:task:test#turn-1
    material: [architecture:docs/architecture.md]
EOF
cat >"$fixture/.intent/CONSTRAINTS.yml" <<'EOF'
version: 1
constraints:
  - id: source.boundary
    assertion: Source behavior remains isolated.
    authority: user:task:test#turn-1
    applies_to: [source]
    material: [architecture:docs/architecture.md]
EOF
git -C "$fixture" add -A
git -C "$fixture" commit -qm seed

ok() { echo "ok - $1"; }
die() { echo "not ok - $1"; exit 1; }

out=$(cd "$fixture" && sh "$session_brief" open task-1 --goal "Change source safely" \
  --posture bounded --boundary no-record --path "src/a file.py" --interface SourceApi --domain source)
printf '%s\n' "$out" | grep -q '^BRIEF: opened task-1$' || die "brief did not open"
manifest="$fixture/.git/invariant/briefs/task-1.yml"
[ -f "$manifest" ] || die "brief receipt is not stored in the shared Git directory"
[ ! -e "$fixture/.intent/runtime" ] || die "brief cache polluted the coordination runtime"
grep -q 'Change source safely' "$manifest" && die "raw goal was persisted"
ok "brief receipt is disposable Git-local state"

out=$(cd "$fixture" && sh "$session_brief" check task-1 --goal "Change source safely" \
  --path "src/a file.py" --interface SourceApi --domain source)
printf '%s\n' "$out" | grep -q '^BRIEF: fresh task-1$' || die "unchanged brief was not reusable"
printf '%s\n' "$out" | grep -q '^POSTURE: bounded$' || die "cached posture was not retained"
ok "unchanged instructions, governance, goal, and scope reuse the brief"

if out=$(cd "$fixture" && sh "$session_brief" check task-1 --goal "A different task" 2>&1); then
  die "changed goal reused the prior brief"
fi
printf '%s\n' "$out" | grep -q '^STALE: goal changed$' || die "goal staleness lacks a precise reason"
ok "goal digest prevents cross-purpose reuse"

cp "$framework/skills/intent-brief/SKILL.md" "$framework/SKILL.saved"
printf '\nCache behavior changed.\n' >>"$framework/skills/intent-brief/SKILL.md"
if out=$(cd "$fixture" && sh "$session_brief" check task-1 --goal "Change source safely" 2>&1); then
  die "changed skill package reused the prior brief"
fi
printf '%s\n' "$out" | grep -q '^STALE: intent-brief content changed$' || die "skill staleness lacks a precise reason"
mv "$framework/SKILL.saved" "$framework/skills/intent-brief/SKILL.md"
ok "skill package hashes guard instruction reuse"

if out=$(cd "$fixture" && sh "$session_brief" check task-1 --goal "Change source safely" --path src/new.py 2>&1); then
  die "expanded path scope reused a narrow brief"
fi
printf '%s\n' "$out" | grep -q '^STALE: path scope expanded to src/new.py$' || die "scope expansion lacks a precise reason"
ok "scope expansion invalidates reuse"

cat >"$fixture/.intent/observations/layout.yml" <<'EOF'
version: 1
id: layout
ground: seed
statement: Source currently has one file.
evidence: [repo:src]
relates_to: [domain:source]
EOF
(cd "$fixture" && sh "$session_brief" check task-1 --goal "Change source safely" >/dev/null) || die "non-authoritative evidence invalidated governance"
ok "non-authoritative evidence stays outside brief freshness"

cp "$fixture/.intent/CONSTRAINTS.yml" "$fixture/.intent/CONSTRAINTS.saved"
sed 's/remains isolated/remains strictly isolated/' "$fixture/.intent/CONSTRAINTS.saved" >"$fixture/.intent/CONSTRAINTS.yml"
if out=$(cd "$fixture" && sh "$session_brief" check task-1 --goal "Change source safely" 2>&1); then
  die "changed selected governance reused a stale brief"
fi
printf '%s\n' "$out" | grep -q '^STALE: selected governance changed$' || die "governance staleness lacks a precise reason"
mv "$fixture/.intent/CONSTRAINTS.saved" "$fixture/.intent/CONSTRAINTS.yml"
ok "selected governance digest guards semantic reuse"

git -C "$fixture" worktree add -q -b linked "$linked"
out=$(cd "$linked" && sh "$session_brief" check task-1 --goal "Change source safely")
printf '%s\n' "$out" | grep -q '^BRIEF: fresh task-1$' || die "linked worktree could not reuse shared brief"
ok "linked worktrees share the Git-local receipt"

printf 'next\n' >>"$fixture/src/a file.py"
git -C "$fixture" commit -qam next
if out=$(cd "$fixture" && sh "$session_brief" check task-1 --goal "Change source safely" 2>&1); then
  die "advanced integration head reused a stale brief"
fi
printf '%s\n' "$out" | grep -q '^STALE: integration head changed$' || die "head staleness lacks a precise reason"
ok "integration-head movement invalidates reuse"

out=$(cd "$fixture" && sh "$session_brief" invalidate task-1)
printf '%s\n' "$out" | grep -q '^BRIEF: invalidated task-1$' || die "brief was not invalidated"
[ ! -e "$manifest" ] || die "invalidated brief remains on disk"
ok "invalidation removes only the selected receipt"

echo "10 session-brief checks passed"

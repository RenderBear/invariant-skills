#!/bin/sh
# Commit an explicitly reviewed, mechanically local staged edit directly on
# the integration branch. Reach is probed from a dangling exact-tree commit,
# then land-support independently recomputes it before its atomic ref update.

set -eu

usage() {
  cat >&2 <<'EOF'
usage:
  direct-edit.sh <subject> --unit <id> --no-record [--target <branch>]
                 [--check <locator>]...

This helper never infers that durable meaning is unchanged. `--no-record` is
the caller's explicit disposition. Only mechanically local staged changes are
eligible; bounded, open, or gated work must use a normal isolated work branch.
EOF
  exit 2
}

[ "$#" -ge 1 ] || usage
subject=$1
shift
unit=""
target=""
checks=""
no_record=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --unit) [ "$#" -ge 2 ] || usage; unit=$2; shift 2 ;;
    --target) [ "$#" -ge 2 ] || usage; target=$2; shift 2 ;;
    --check) [ "$#" -ge 2 ] || usage; checks="$checks
$2"; shift 2 ;;
    --no-record) no_record=$((no_record + 1)); shift ;;
    *) usage ;;
  esac
done

case "$unit" in ''|*[!a-zA-Z0-9._-]*) echo "Invariant: invalid unit id '$unit'" >&2; exit 2 ;; esac
[ "$no_record" -eq 1 ] || {
  echo "Invariant: direct edit requires exactly one explicit --no-record disposition" >&2
  exit 2
}

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "Invariant: not inside a Git repository" >&2
  exit 2
}
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
brief_dir="$script_dir/../../intent-brief/scripts"
if [ -z "$target" ]; then
  target=$(sh "$brief_dir/resolve-config.sh" | sed -n 's/^integration_branch_resolved:[[:space:]]*//p')
fi
[ -n "$target" ] || { echo "Invariant: no integration branch resolved" >&2; exit 2; }
git check-ref-format --branch "$target" >/dev/null 2>&1 || {
  echo "Invariant: invalid integration branch '$target'" >&2
  exit 2
}
current=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
[ "$current" = "$target" ] || {
  echo "Invariant: direct edit must run on the checked-out integration branch ('$target')" >&2
  exit 2
}
old=$(git rev-parse -q --verify HEAD^{commit} 2>/dev/null) || {
  echo "Invariant: direct edit requires an existing integration commit" >&2
  exit 2
}
[ -z "$(git ls-files -u)" ] || {
  echo "Invariant: direct edit cannot include unresolved index entries" >&2
  exit 2
}
git diff --cached --quiet -- && {
  echo "Invariant: direct edit requires staged changes" >&2
  exit 2
}

tmp=$(mktemp -d "${TMPDIR:-/tmp}/invariant-direct-edit.XXXXXX")
verify_dir="$tmp/verify"
worktree_added=0
cleanup() {
  if [ "$worktree_added" -eq 1 ]; then
    git -C "$root" worktree remove --force "$verify_dir" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT HUP INT TERM

tree=$(git write-tree)
probe=$(git commit-tree "$tree" -p "$old" -m "Invariant direct-edit reach probe")
git worktree add --quiet --detach "$verify_dir" "$probe"
worktree_added=1

last_attested=$(git log --first-parent \
  --format='%H%x1c%(trailers:key=Intent-Boundary,valueonly,separator=%x1d)' "$old" 2>/dev/null |
  awk 'BEGIN {FS=sprintf("%c",28)} $2!="" {print $1; exit}')
if [ -n "$last_attested" ] && [ "$last_attested" != "$old" ]; then
  reach=$(cd "$verify_dir" && sh "$brief_dir/brief-support.sh" reach --history "$last_attested")
else
  reach=$(cd "$verify_dir" && sh "$brief_dir/brief-support.sh" reach "$old")
fi
verdict=$(printf '%s\n' "$reach" | sed -n 's/^REACH:[[:space:]]*//p')
if [ "$verdict" != local ]; then
  printf '%s\n' "$reach"
  echo "Invariant: direct edit has ${verdict:-unknown} reach; use normal work-branch landing" >&2
  exit 1
fi
scopes=$(printf '%s\n' "$reach" | sed -n 's/^TOPOLOGY:[[:space:]]*//p')
[ -n "$scopes" ] || {
  echo "Invariant: direct edit has no derived path scope; use normal work-branch landing" >&2
  exit 1
}

git -C "$root" worktree remove --force "$verify_dir" >/dev/null
worktree_added=0

set -- staged "$subject" --unit "$unit" --boundary-review no-record --target "$target"
for scope in $scopes; do set -- "$@" --scope "$scope"; done
printf '%s\n' "$checks" | sed '/^$/d' | while IFS= read -r locator; do
  case "$locator" in *[!a-zA-Z0-9._:/@+-]*) echo "Invariant: check locator contains unsupported whitespace or punctuation: '$locator'" >&2; exit 2 ;; esac
done
for locator in $checks; do set -- "$@" --check "$locator"; done
exec sh "$script_dir/land-support.sh" "$@"

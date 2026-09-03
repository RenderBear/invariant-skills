#!/bin/sh
# Cache a non-authoritative task brief receipt in Git's shared administrative
# directory. Landing never consumes this cache and always recomputes reach.

set -u

usage() {
  cat >&2 <<'EOF'
usage:
  session-brief.sh open <task-id> --goal <text> --posture <posture>
                        --boundary <disposition> [--path <path>]...
                        [--interface <name>]... [--domain <id>]...
  session-brief.sh check <task-id> --goal <text> [--path <path>]...
                         [--interface <name>]... [--domain <id>]...
  session-brief.sh invalidate <task-id>

The cache is a freshness receipt, not governance or landing evidence. `check`
rejects changed repository identity, skill content, selected governance or
defining material, goal, or expanded scope. An advanced integration head is
adopted when it remains causally related and cleanly mergeable.
EOF
  exit 2
}

[ "$#" -ge 2 ] || usage
cmd=$1
task=$2
shift 2

case "$task" in ''|*[!A-Za-z0-9._-]*) echo "Invariant: invalid task id '$task'" >&2; exit 2 ;; esac

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "Invariant: not inside a Git repository" >&2
  exit 2
}
cd "$root" || exit 2

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
skills_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
brief_support="$script_dir/brief-support.sh"
resolver="$script_dir/resolve-config.sh"
common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || exit 2
case "$common_dir" in /*) ;; *) common_dir="$root/$common_dir" ;; esac
common_dir=$(CDPATH= cd -- "$common_dir" && pwd -P) || exit 2
cache_root="$common_dir/invariant/briefs"
manifest="$cache_root/$task.yml"

scratch=$(mktemp -d "${TMPDIR:-/tmp}/invariant-session-brief.XXXXXX") || exit 2
pending=""
cleanup() {
  rm -rf "$scratch"
  [ -z "$pending" ] || rm -f "$pending"
}
trap cleanup EXIT HUP INT TERM
paths="$scratch/paths"
interfaces="$scratch/interfaces"
domains="$scratch/domains"
: >"$paths"; : >"$interfaces"; : >"$domains"

yaml_quote() {
  escaped=$(printf '%s' "$1" | sed "s/'/''/g")
  printf "'%s'" "$escaped"
}

manifest_value() {
  prefix=$1
  value=$(awk -v prefix="$prefix" 'index($0, prefix) == 1 {print substr($0, length(prefix) + 1); exit}' "$manifest")
  case "$value" in
    "'"*"'") value=${value#\'}; value=${value%\'}; printf '%s\n' "$value" | sed "s/''/'/g" ;;
    *) printf '%s\n' "$value" ;;
  esac
}

manifest_list() {
  section=$1
  awk -v header="  $section:" '
    $0 == header {inside=1; next}
    inside && /^    - / {
      value=substr($0, 7)
      if (value ~ /^'"'"'.*'"'"'$/) {
        value=substr(value, 2, length(value) - 2)
        gsub(/'"'"''"'"'/, "'"'"'", value)
      }
      print value
      next
    }
    inside {exit}
  ' "$manifest"
}

integration_target() {
  sh "$resolver" | sed -n 's/^integration_branch_resolved:[[:space:]]*//p'
}

integration_head() {
  target=$1
  git rev-parse -q --verify "refs/heads/$target" 2>/dev/null || printf 'unborn\n'
}

repository_identity() {
  target=$1
  roots=$(git rev-list --max-parents=0 "refs/heads/$target" 2>/dev/null | LC_ALL=C sort)
  if [ -n "$roots" ]; then printf '%s\n' "$roots" | git hash-object --stdin
  else printf '%s\n' "$common_dir" | git hash-object --stdin
  fi
}

skill_digest() {
  skill=$1
  skill_root="$skills_root/$skill"
  [ -f "$skill_root/SKILL.md" ] || {
    echo "Invariant: missing $skill instructions" >&2
    return 1
  }
  skill_files="$scratch/$skill.files"
  find "$skill_root" -type f -print | LC_ALL=C sort >"$skill_files"
  {
    while IFS= read -r skill_file; do printf '%s\n' "${skill_file#"$skill_root"/}"; done <"$skill_files"
    git hash-object --stdin-paths <"$skill_files"
  } | git hash-object --stdin
}

governance_digest() {
  domain_source=${1:-$domains}
  set --
  while IFS= read -r domain; do [ -z "$domain" ] || set -- "$@" "$domain"; done <"$domain_source"
  sh "$brief_support" digest "$@" | sed -n 's/^DIGEST:[[:space:]]*//p'
}

governance_digest_at() {
  at=$1; domain_source=$2
  if [ "$at" = unborn ]; then
    git hash-object --stdin </dev/null
    return
  fi
  set --
  while IFS= read -r domain; do [ -z "$domain" ] || set -- "$@" "$domain"; done <"$domain_source"
  sh "$brief_support" digest --at "$at" "$@" | sed -n 's/^DIGEST:[[:space:]]*//p'
}

material_changes() {
  base=$1; tip=$2; domain_source=$3
  set -- "$base" "$tip"
  while IFS= read -r domain; do [ -z "$domain" ] || set -- "$@" "$domain"; done <"$domain_source"
  sh "$brief_support" material-changes "$@"
}

parse_scope_args() {
  allow_posture=$1
  shift
  goal=""; goal_supplied=0; posture=""; boundary=""; scope_supplied=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --goal) [ "$#" -ge 2 ] || usage; goal=$2; goal_supplied=1; shift 2 ;;
      --posture)
        [ "$allow_posture" -eq 1 ] && [ "$#" -ge 2 ] || usage
        posture=$2; shift 2
        ;;
      --boundary)
        [ "$allow_posture" -eq 1 ] && [ "$#" -ge 2 ] || usage
        boundary=$2; shift 2
        ;;
      --path) [ "$#" -ge 2 ] || usage; printf '%s\n' "$2" >>"$paths"; scope_supplied=1; shift 2 ;;
      --interface) [ "$#" -ge 2 ] || usage; printf '%s\n' "$2" >>"$interfaces"; scope_supplied=1; shift 2 ;;
      --domain) [ "$#" -ge 2 ] || usage; printf '%s\n' "$2" >>"$domains"; scope_supplied=1; shift 2 ;;
      *) usage ;;
    esac
  done
  LC_ALL=C sort -u "$paths" -o "$paths"
  LC_ALL=C sort -u "$interfaces" -o "$interfaces"
  LC_ALL=C sort -u "$domains" -o "$domains"
}

write_list() {
  name=$1; file=$2
  printf '  %s:\n' "$name"
  while IFS= read -r item; do printf '    - %s\n' "$(yaml_quote "$item")"; done <"$file"
}

stale() {
  printf 'STALE: %s\n' "$1"
  exit 1
}

refresh_integration() {
  head=$1; governance=$2
  pending=$(mktemp "$cache_root/.$task.XXXXXX") || exit 2
  quoted_head=$(yaml_quote "$head")
  quoted_governance=$(yaml_quote "$governance")
  awk -v head="$quoted_head" -v governance="$quoted_governance" '
    /^integration_head: / {$0="integration_head: " head}
    /^  integration_governance_digest: / {$0="  integration_governance_digest: " governance}
    {print}
  ' "$manifest" >"$pending"
  mv "$pending" "$manifest"
  pending=""
}

case "$cmd" in
  open)
    parse_scope_args 1 "$@"
    [ "$goal_supplied" -eq 1 ] || usage
    case "$posture" in local|bounded|open|gated) ;; *) usage ;; esac
    case "$boundary" in no-record|recorded|unresolved|audit:*) ;; *) usage ;; esac

    target=$(integration_target)
    [ -n "$target" ] || { echo "Invariant: could not resolve integration target" >&2; exit 2; }
    head=$(integration_head "$target")
    repository=$(repository_identity "$target")
    goal_digest=$(printf '%s' "$goal" | git hash-object --stdin)
    brief_skill=$(skill_digest intent-brief) || exit 2
    land_skill=$(skill_digest intent-land) || exit 2
    governance=$(governance_digest) || exit 2
    integration_governance=$(governance_digest_at "$head" "$domains") || exit 2

    mkdir -p "$cache_root"
    pending=$(mktemp "$cache_root/.$task.XXXXXX") || exit 2
    {
      echo 'version: 1'
      printf 'repository: %s\n' "$(yaml_quote "$repository")"
      printf 'task: %s\n' "$(yaml_quote "$task")"
      printf 'goal_digest: %s\n' "$(yaml_quote "$goal_digest")"
      printf 'integration_target: %s\n' "$(yaml_quote "$target")"
      printf 'integration_head: %s\n' "$(yaml_quote "$head")"
      echo 'skills:'
      printf '  intent-brief: %s\n' "$(yaml_quote "$brief_skill")"
      printf '  intent-land: %s\n' "$(yaml_quote "$land_skill")"
      echo 'scope:'
      write_list paths "$paths"
      write_list interfaces "$interfaces"
      write_list domains "$domains"
      echo 'intent:'
      printf '  governance_digest: %s\n' "$(yaml_quote "$governance")"
      printf '  integration_governance_digest: %s\n' "$(yaml_quote "$integration_governance")"
      printf '  posture: %s\n' "$(yaml_quote "$posture")"
      printf '  boundary: %s\n' "$(yaml_quote "$boundary")"
    } >"$pending"
    mv "$pending" "$manifest"
    printf 'BRIEF: opened %s\n' "$task"
    printf 'RECEIPT: %s\n' "$manifest"
    ;;
  check)
    [ -f "$manifest" ] || { echo "Invariant: no cached brief '$task'" >&2; exit 1; }
    parse_scope_args 0 "$@"
    [ "$goal_supplied" -eq 1 ] || usage
    [ "$(manifest_value 'version: ')" = 1 ] || { echo "Invariant: unsupported cached brief '$task'" >&2; exit 2; }
    [ "$(manifest_value 'task: ')" = "$task" ] || { echo "Invariant: corrupt cached brief '$task'" >&2; exit 2; }

    cached_target=$(manifest_value 'integration_target: ')
    target=$(integration_target)
    [ "$target" = "$cached_target" ] || stale "integration target changed from $cached_target to $target"
    [ "$(repository_identity "$target")" = "$(manifest_value 'repository: ')" ] || stale "repository identity changed"
    [ "$(skill_digest intent-brief)" = "$(manifest_value '  intent-brief: ')" ] || stale "intent-brief content changed"
    [ "$(skill_digest intent-land)" = "$(manifest_value '  intent-land: ')" ] || stale "intent-land content changed"

    manifest_list domains >"$scratch/cached-domains"
    [ "$(governance_digest "$scratch/cached-domains")" = "$(manifest_value '  governance_digest: ')" ] || stale "selected governance changed"

    current_goal=$(printf '%s' "$goal" | git hash-object --stdin)
    [ "$current_goal" = "$(manifest_value 'goal_digest: ')" ] || stale "goal changed"

    if [ "$scope_supplied" -eq 1 ]; then
      manifest_list paths >"$scratch/cached-paths"
      manifest_list interfaces >"$scratch/cached-interfaces"
      manifest_list domains >"$scratch/cached-domains"
      for pair in "path:$paths:$scratch/cached-paths" "interface:$interfaces:$scratch/cached-interfaces" "domain:$domains:$scratch/cached-domains"; do
        kind=${pair%%:*}; rest=${pair#*:}; requested=${rest%%:*}; cached=${rest#*:}
        while IFS= read -r item; do
          [ -z "$item" ] || grep -qxF "$item" "$cached" || stale "$kind scope expanded to $item"
        done <"$requested"
      done
    fi

    cached_head=$(manifest_value 'integration_head: ')
    current_head=$(integration_head "$target")
    if [ "$current_head" != "$cached_head" ]; then
      [ "$cached_head" != unborn ] && [ "$current_head" != unborn ] || stale "integration branch birth state changed"
      git merge-base --is-ancestor "$cached_head" "$current_head" >/dev/null 2>&1 || stale "integration history no longer descends from the cached head"

      integration_governance=$(governance_digest_at "$current_head" "$scratch/cached-domains") || exit 2
      [ "$integration_governance" = "$(manifest_value '  integration_governance_digest: ')" ] || stale "selected governance changed on the integration branch"
      changed_material=$(material_changes "$cached_head" "$current_head" "$scratch/cached-domains") || exit 2
      if [ -n "$changed_material" ]; then
        first_material=$(printf '%s\n' "$changed_material" | sed -n '1s/^MATERIAL-CHANGED: //p')
        stale "governing material changed — $first_material"
      fi

      task_tip=$(git rev-parse -q --verify HEAD 2>/dev/null || true)
      if [ -n "$task_tip" ] && [ "$task_tip" != "$current_head" ]; then
        git merge-base --is-ancestor "$cached_head" "$task_tip" >/dev/null 2>&1 || stale "task history no longer descends from the cached head"
        if ! git merge-tree --write-tree "$current_head" "$task_tip" >/dev/null 2>&1; then
          printf 'MERGE-REQUIRED: task conflicts with advanced integration head %s\n' "$current_head"
          exit 1
        fi
      fi
      refresh_integration "$current_head" "$integration_governance"
      printf 'HEAD: advanced %s..%s — mergeable, brief reused\n' "$cached_head" "$current_head"
    fi

    printf 'BRIEF: fresh %s\n' "$task"
    printf 'REUSE: skill instructions and selected governance rows\n'
    printf 'POSTURE: %s\n' "$(manifest_value '  posture: ')"
    printf 'BOUNDARY: %s\n' "$(manifest_value '  boundary: ')"
    ;;
  invalidate)
    [ "$#" -eq 0 ] || usage
    if [ -f "$manifest" ]; then rm -f "$manifest"; printf 'BRIEF: invalidated %s\n' "$task"
    else printf 'BRIEF: absent %s\n' "$task"
    fi
    rmdir "$cache_root" 2>/dev/null || true
    rmdir "$common_dir/invariant" 2>/dev/null || true
    ;;
  *) usage ;;
esac

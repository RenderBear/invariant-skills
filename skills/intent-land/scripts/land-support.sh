#!/bin/sh
# Construct and verify a prospective landing before atomically advancing the
# integration ref. The target branch is never moved on a failed preflight.

set -eu

usage() {
  cat >&2 <<'EOF'
usage:
  land-support.sh direct <subject> --unit <id>... --scope <scope>...
                  --paths <path>... [--domain <id>]... [--interface <name>]...
                  [--governance <ref>]... [--reviewed constraint:<id>]...
                  --boundary-review <no-record|audit:id|recorded>
                  [--target <branch>] [--check <locator>]...
                  [--allow-open] [--plan <id>]
  land-support.sh staged <subject> --unit <id> --scope <scope>...
                  --boundary-review no-record [--target <branch>]
                  [--check <locator>]...
  land-support.sh merge <branch> <subject> --unit <id>... --scope <scope>...
                  [--domain <id>]... [--interface <name>]...
                  [--governance <ref>]... [--reviewed constraint:<id>]...
                  --boundary-review <no-record|audit:id|recorded>
                  [--target <branch>] [--check <locator>]...
                  [--allow-open] [--plan <id>]

Check locators are executable `command:path` wrappers or supported `test:`
locators. `--allow-open` states that intent-land has already resolved the
authority gate for an open or gated governance transition. `no-record` states
that the durable-meaning review found no new governance to adopt. `audit:id`
names a fresh scoped audit with only no-action or observation findings.
`recorded` requires the owning domain, contract, or constraint references via
`--governance`.
EOF
  exit 2
}

[ "$#" -ge 2 ] || usage
mode=$1
shift
merge_branch=""
case "$mode" in
  direct) subject=$1; shift ;;
  staged) subject=$1; shift ;;
  merge) [ "$#" -ge 2 ] || usage; merge_branch=$1; subject=$2; shift 2 ;;
  *) usage ;;
esac

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "Invariant: not inside a Git repository" >&2
  exit 2
}
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
brief_dir="$script_dir/../../intent-brief/scripts"
coordinate_dir="$script_dir/../../intent-coordinate/scripts"
audit_dir="$script_dir/../../intent-audit/scripts"
runtime=$(sh "$coordinate_dir/runtime-support.sh" root) || exit 2

units=""
scopes=""
paths=""
checks=""
domains=""
interfaces=""
governance=""
reviewed=""
boundary_review=""
target_override=""
plan=""
allow_open=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --unit) [ "$#" -ge 2 ] || usage; units="$units $2"; shift 2 ;;
    --scope) [ "$#" -ge 2 ] || usage; scopes="$scopes $2"; shift 2 ;;
    --domain) [ "$#" -ge 2 ] || usage; domains="$domains $2"; shift 2 ;;
    --interface) [ "$#" -ge 2 ] || usage; interfaces="$interfaces $2"; shift 2 ;;
    --governance) [ "$#" -ge 2 ] || usage; governance="$governance $2"; shift 2 ;;
    --reviewed) [ "$#" -ge 2 ] || usage; reviewed="$reviewed $2"; shift 2 ;;
    --boundary-review)
      [ "$#" -ge 2 ] || usage
      [ -z "$boundary_review" ] || { echo "Invariant: pass exactly one --boundary-review" >&2; exit 2; }
      boundary_review=$2
      shift 2
      ;;
    --target) [ "$#" -ge 2 ] || usage; target_override=$2; shift 2 ;;
    --plan) [ "$#" -ge 2 ] || usage; plan=$2; shift 2 ;;
    --check) [ "$#" -ge 2 ] || usage; checks="$checks
$2"; shift 2 ;;
    --allow-open) allow_open=1; shift ;;
    --paths)
      shift
      while [ "$#" -gt 0 ] && [ "${1#--}" = "$1" ]; do
        paths="$paths
$1"
        shift
      done
      ;;
    *) usage ;;
  esac
done

[ -n "$units" ] || { echo "Invariant: landing requires at least one unit id" >&2; exit 2; }
[ -n "$scopes" ] || { echo "Invariant: landing requires at least one scope" >&2; exit 2; }
[ "$mode" != direct ] || [ -n "$paths" ] || { echo "Invariant: direct landing requires --paths" >&2; exit 2; }
[ -n "$boundary_review" ] || { echo "Invariant: landing requires exactly one --boundary-review disposition" >&2; exit 2; }
case "$boundary_review" in
  no-record|recorded) ;;
  audit:*)
    audit_id=${boundary_review#audit:}
    case "$audit_id" in ''|*[!a-zA-Z0-9._-]*) echo "Invariant: invalid boundary audit id '$audit_id'" >&2; exit 2 ;; esac
    ;;
  *) echo "Invariant: invalid --boundary-review '$boundary_review'" >&2; exit 2 ;;
esac
[ "$boundary_review" != recorded ] || [ -n "$governance" ] || {
  echo "Invariant: --boundary-review recorded requires at least one --governance reference" >&2
  exit 2
}
if [ "$mode" = staged ]; then
  [ "$boundary_review" = no-record ] && [ -z "$domains$interfaces$governance$reviewed$plan" ] && [ "$allow_open" -eq 0 ] || {
    echo "Invariant: staged landing is only for an explicit local no-record edit; use normal work-branch landing" >&2
    exit 2
  }
fi

if [ -n "$target_override" ]; then target=$target_override
else target=$(sh "$brief_dir/resolve-config.sh" | sed -n 's/^integration_branch_resolved:[[:space:]]*//p')
fi
[ -n "$target" ] || { echo "Invariant: no integration branch resolved" >&2; exit 2; }
git check-ref-format --branch "$target" >/dev/null 2>&1 || {
  echo "Invariant: invalid integration branch '$target'" >&2
  exit 2
}
current=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
unborn=0
old=$(git rev-parse -q --verify "refs/heads/$target^{commit}" 2>/dev/null || true)
if [ -z "$old" ]; then
  if ! git rev-parse -q --verify HEAD >/dev/null 2>&1; then
    unborn=1
  else
    echo "Invariant: integration branch '$target' has no commit" >&2
    exit 2
  fi
fi
[ "$mode" != merge ] || [ "$unborn" -eq 0 ] || {
  echo "Invariant: an unborn integration branch requires a direct first landing" >&2
  exit 2
}
[ "$mode" != staged ] || [ "$unborn" -eq 0 ] || {
  echo "Invariant: staged landing requires an existing integration commit" >&2
  exit 2
}
[ "$mode" != direct ] || [ "$unborn" -eq 1 ] || {
  echo "Invariant: direct landing is reserved for the first commit on an unborn integration branch; use a work branch and merge" >&2
  exit 2
}

worktree_for_branch() {
  branch=$1
  git worktree list --porcelain 2>/dev/null | awk -v wanted="refs/heads/$branch" '
    /^worktree / {path=substr($0, 10); next}
    /^branch / && substr($0, 8)==wanted {print path; exit}
  '
}

tracked_worktree_clean() {
  worktree=$1
  git -C "$worktree" diff --quiet -- && git -C "$worktree" diff --cached --quiet --
}

target_worktree=$(worktree_for_branch "$target")
if [ "$mode" = direct ]; then
  [ "$current" = "$target" ] || {
    echo "Invariant: unborn direct landing must run in the integration worktree ('$target')" >&2
    exit 2
  }
  [ -n "$target_worktree" ] || target_worktree=$root
  git diff --cached --quiet -- || {
    echo "Invariant: staged changes exist; preserve or unstage them before direct landing" >&2
    exit 2
  }
elif [ "$mode" = staged ]; then
  [ "$current" = "$target" ] || {
    echo "Invariant: staged landing must run in the checked-out integration branch ('$target')" >&2
    exit 2
  }
  [ -n "$target_worktree" ] || target_worktree=$root
  [ -z "$(git ls-files -u)" ] || {
    echo "Invariant: staged landing cannot include unresolved index entries" >&2
    exit 2
  }
  git diff --cached --quiet -- && {
    echo "Invariant: staged landing requires staged changes" >&2
    exit 2
  }
elif [ -n "$target_worktree" ] && ! tracked_worktree_clean "$target_worktree"; then
  echo "Invariant: integration worktree '$target_worktree' has tracked changes; landing cannot synchronize it safely" >&2
  exit 2
fi

branch_ref=""
if [ "$mode" = merge ]; then
  branch_ref=$(git rev-parse -q --verify "refs/heads/$merge_branch^{commit}" 2>/dev/null) || {
    echo "Invariant: merge branch '$merge_branch' does not exist locally" >&2
    exit 2
  }
  candidate_worktree=$(worktree_for_branch "$merge_branch")
  if [ -n "$candidate_worktree" ] && ! tracked_worktree_clean "$candidate_worktree"; then
    echo "Invariant: candidate worktree '$candidate_worktree' has uncommitted tracked changes" >&2
    exit 2
  fi
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/invariant-land.XXXXXX")
verify_dir="$tmp/verify"
worktree_added=0
cleanup() {
  if [ "$worktree_added" -eq 1 ]; then
    git -C "$root" worktree remove --force "$verify_dir" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT HUP INT TERM

covers=""
reach_base="$old"
if [ "$unborn" -eq 0 ]; then
  last_attested=$(git log --first-parent \
    --format='%H%x1c%(trailers:key=Intent-Boundary,valueonly,separator=%x1d)' "$old" 2>/dev/null |
    awk 'BEGIN {FS=sprintf("%c",28)} $2!="" {print $1; exit}')
  if [ -n "$last_attested" ] && [ "$last_attested" != "$old" ]; then
    covers="$last_attested..$old"
    reach_base=$last_attested
  fi
fi

message_args=""
for unit in $units; do message_args="$message_args --unit $unit"; done
for scope in $scopes; do message_args="$message_args --scope $scope"; done
for domain in $domains; do message_args="$message_args --domain $domain"; done
[ -z "$plan" ] || message_args="$message_args --plan $plan"
# Arguments are identifiers validated by the message generator and contain no
# whitespace by schema. shellcheck disable=SC2086
sh "$brief_dir/brief-support.sh" message "$subject" $message_args >"$tmp/message"
printf 'Intent-Boundary: %s\n' "$boundary_review" >>"$tmp/message"
[ -z "$covers" ] || printf 'Intent-Covers: %s\n' "$covers" >>"$tmp/message"
for ref in $governance; do printf 'Intent-Governance: %s\n' "$ref" >>"$tmp/message"; done

if [ "$mode" = direct ]; then
  index="$tmp/index"
  if [ "$unborn" -eq 1 ]; then
    GIT_INDEX_FILE="$index" git read-tree --empty
  else
    GIT_INDEX_FILE="$index" git read-tree "$old^{tree}"
  fi
  printf '%s\n' "$paths" | sed '/^$/d' | while IFS= read -r path; do
    case "$path" in /*|../*|*/../*|*'/..') echo "Invariant: invalid landing path '$path'" >&2; exit 2 ;; esac
    GIT_INDEX_FILE="$index" git add -A -- "$path"
  done
  tree=$(GIT_INDEX_FILE="$index" git write-tree)
  if [ "$unborn" -eq 0 ]; then
    [ "$tree" != "$(git rev-parse "$old^{tree}")" ] || {
      echo "Invariant: selected paths produce no change" >&2
      exit 2
    }
    candidate=$(git commit-tree "$tree" -p "$old" -F "$tmp/message")
  else
    candidate=$(git commit-tree "$tree" -F "$tmp/message")
  fi
elif [ "$mode" = staged ]; then
  tree=$(git write-tree)
  [ "$tree" != "$(git rev-parse "$old^{tree}")" ] || {
    echo "Invariant: staged index produces no change" >&2
    exit 2
  }
  candidate=$(git commit-tree "$tree" -p "$old" -F "$tmp/message")
else
  merge_output=$(git merge-tree --write-tree "$old" "$branch_ref" 2>&1) || {
    printf '%s\n' "$merge_output" >&2
    echo "Invariant: prospective merge conflicts; integration branch unchanged" >&2
    exit 1
  }
  tree=$(printf '%s\n' "$merge_output" | sed -n '1p')
  candidate=$(git commit-tree "$tree" -p "$old" -p "$branch_ref" -F "$tmp/message")
fi

target_checkout_safe() {
  [ "$mode" != direct ] || return 0
  if [ "$mode" = staged ]; then
    [ "$(git rev-parse -q --verify "refs/heads/$target^{commit}" 2>/dev/null || true)" = "$old" ] || {
      echo "Invariant: integration branch changed during staged landing" >&2
      return 1
    }
    current_index=$(git write-tree 2>/dev/null) || {
      echo "Invariant: staged index changed into an unreadable state during landing" >&2
      return 1
    }
    [ "$current_index" = "$tree" ] || {
      echo "Invariant: staged index changed during landing" >&2
      return 1
    }
    return 0
  fi
  [ -n "$target_worktree" ] || return 0
  tracked_worktree_clean "$target_worktree" || {
    echo "Invariant: integration worktree '$target_worktree' changed during landing" >&2
    return 1
  }
  candidate_paths="$tmp/candidate-paths"
  untracked_paths="$tmp/target-untracked"
  collisions="$tmp/untracked-collisions"
  git ls-tree -r --name-only "$candidate" -- >"$candidate_paths"
  # Include ignored files: a checkout may replace them too, and local build or
  # downloaded artifacts are no less valuable merely because Git ignores them.
  git -C "$target_worktree" ls-files --others -- >"$untracked_paths"
  awk '
    NR==FNR {
      candidate[$0]=1
      parent=$0
      while(sub(/\/[^\/]*$/, "", parent)) candidate_directory[parent]=1
      next
    }
    {
      untracked=$0
      collision=(candidate[untracked] || candidate_directory[untracked])
      parent=untracked
      while(!collision && sub(/\/[^\/]*$/, "", parent)) {
        if(candidate[parent]) collision=1
      }
      if(collision) print untracked
    }
  ' "$candidate_paths" "$untracked_paths" >"$collisions" || {
    echo "Invariant: could not verify untracked integration-file safety" >&2
    return 1
  }
  if [ -s "$collisions" ]; then
    echo "Invariant: untracked integration files collide with the candidate:" >&2
    sed 's/^/  /' "$collisions" >&2
    return 1
  fi
}

target_checkout_safe || exit 2

git worktree add --quiet --detach "$verify_dir" "$candidate"
worktree_added=1

reach_args=""
for domain in $domains; do reach_args="$reach_args --domain $domain"; done
for interface in $interfaces; do reach_args="$reach_args --interface $interface"; done
if [ "$unborn" -eq 1 ]; then
  # shellcheck disable=SC2086
  reach=$(cd "$verify_dir" && sh "$brief_dir/brief-support.sh" reach --root $reach_args)
else
  # shellcheck disable=SC2086
  reach=$(cd "$verify_dir" && sh "$brief_dir/brief-support.sh" reach --history "$reach_base" $reach_args)
fi
printf '%s\n' "$reach"
[ -z "$covers" ] || printf 'COVERAGE: %s\n' "$covers"
verdict=$(printf '%s\n' "$reach" | sed -n 's/^REACH:[[:space:]]*//p')
case "$verdict" in
  local|bounded) ;;
  open)
    if [ "$allow_open" -ne 1 ]; then
      echo "Invariant: open governance boundary requires resolved authority (--allow-open)" >&2
      exit 1
    fi
    ;;
  gated)
    [ "$allow_open" -eq 1 ] || {
      echo "Invariant: gated governance transition requires resolved authority (--allow-open)" >&2
      exit 1
    }
    ;;
  *) echo "Invariant: could not classify prospective reach" >&2; exit 2 ;;
esac
[ "$mode" != staged ] || [ "$verdict" = local ] || {
  echo "Invariant: staged edit has $verdict reach; use normal work-branch landing" >&2
  exit 1
}

(cd "$verify_dir" && GIT_INTENT_INTEGRATION_TARGET="$target" GIT_INTENT_ALLOW_UNBORN="$unborn" sh "$brief_dir/validate-state.sh" --landing)
(cd "$verify_dir" && sh "$brief_dir/brief-support.sh" trailer "$candidate")

governance_exists() {
  ref=$1
  kind=${ref%%:*}
  id=${ref#*:}
  [ "$id" != "$ref" ] && [ -n "$id" ] || return 1
  case "$kind" in
    domain) file=.intent/DOMAINS.yml ;;
    contract) file=.intent/CONTRACTS.yml ;;
    constraint) file=.intent/CONSTRAINTS.yml ;;
    *) return 1 ;;
  esac
  [ -f "$verify_dir/$file" ] &&
    sed -n 's/^  - id:[[:space:]]*//p' "$verify_dir/$file" |
    sed 's/[[:space:]]*#.*$//; s/[[:space:]]*$//' |
    grep -qxF "$id"
}

case "$boundary_review" in
  no-record)
    if printf '%s\n' "$reach" | grep -q '^GOVERNANCE:'; then
      echo "Invariant: governance changed; use --boundary-review recorded with --governance references" >&2
      exit 1
    fi
    echo "BOUNDARY-REVIEW: no-record"
    ;;
  audit:*)
    if printf '%s\n' "$reach" | grep -q '^GOVERNANCE:'; then
      echo "Invariant: governance changed; use --boundary-review recorded with --governance references" >&2
      exit 1
    fi
    audit_id=${boundary_review#audit:}
    audit_file="$verify_dir/.intent/audits/$audit_id.yml"
    [ -f "$audit_file" ] || { echo "Invariant: boundary audit '$audit_id' is absent from the candidate" >&2; exit 1; }
    audit_mode=$(sed -n 's/^mode:[[:space:]]*//p' "$audit_file" | head -1 |
      sed 's/[[:space:]]*#.*$//; s/[[:space:]]*$//')
    [ "$audit_mode" = scope ] || {
      echo "Invariant: boundary review requires a scoped audit" >&2
      exit 1
    }
    if sed -n 's/^    disposition:[[:space:]]*//p' "$audit_file" |
        sed 's/[[:space:]]*#.*$//; s/[[:space:]]*$//' |
        grep -Eq '^(adoptable|needs-authority|needs-verifier)$'; then
      echo "Invariant: boundary audit '$audit_id' has adoptable or unresolved findings" >&2
      exit 1
    fi
    (cd "$verify_dir" && sh "$audit_dir/audit-support.sh" fresh "$audit_id" HEAD) || {
      echo "Invariant: boundary audit '$audit_id' is not fresh for the candidate" >&2
      exit 1
    }
    echo "BOUNDARY-REVIEW: audit:$audit_id — no governance adoption required"
    ;;
  recorded)
    for ref in $governance; do
      governance_exists "$ref" || {
        echo "Invariant: boundary governance '$ref' is not an accepted candidate record" >&2
        exit 1
      }
    done
    echo "BOUNDARY-REVIEW: recorded —$(printf ' %s' $governance)"
    ;;
esac

run_locator() {
  locator=$1
  echo "CHECK: running — $locator"
  case "$locator" in
    command:*)
      path=${locator#command:}
      [ -f "$verify_dir/$path" ] && [ -x "$verify_dir/$path" ] || {
        echo "Invariant: command verifier '$path' is missing or not executable" >&2
        return 1
      }
      (cd "$verify_dir" && "./$path")
      ;;
    test:*)
      spec=${locator#test:}
      path=${spec%%::*}
      case "$path" in
        *.sh) (cd "$verify_dir" && sh "$path") ;;
        *.py) (cd "$verify_dir" && python3 -m pytest "$spec") ;;
        *)
          [ -x "$verify_dir/$path" ] || {
            echo "Invariant: test verifier '$locator' is not directly executable; use a command: wrapper" >&2
            return 1
          }
          (cd "$verify_dir" && "./$path")
          ;;
      esac
      ;;
    schema:*)
      path=${locator#schema:}; path=${path%%#*}
      [ -x "$verify_dir/$path" ] || {
        echo "Invariant: schema verifier '$locator' needs an executable command: wrapper" >&2
        return 1
      }
      (cd "$verify_dir" && "./$path")
      ;;
    *)
      echo "Invariant: unsupported check locator '$locator'" >&2
      return 1
      ;;
  esac
}

executed_checks="$tmp/executed-checks"
: >"$executed_checks"
run_unique_locator() {
  locator=$1
  if grep -qxF "$locator" "$executed_checks"; then return 0; fi
  printf '%s\n' "$locator" >>"$executed_checks"
  run_locator "$locator"
}

if [ "$unborn" -eq 1 ]; then
  # shellcheck disable=SC2086
  verifier_rows=$(cd "$verify_dir" && sh "$brief_dir/brief-support.sh" verifiers --root $reach_args)
else
  # shellcheck disable=SC2086
  verifier_rows=$(cd "$verify_dir" && sh "$brief_dir/brief-support.sh" verifiers --history "$reach_base" $reach_args)
fi
printf '%s\n' "$verifier_rows" | sed -n 's/^VERIFY: [^ ]* //p' | while IFS= read -r locator; do
  [ -n "$locator" ] || continue
  case "$locator" in
    contract:*)
      echo "Invariant: nested contract verifier '$locator' must resolve to an executable verifier before landing" >&2
      exit 1
      ;;
    *) run_unique_locator "$locator" ;;
  esac
done

printf '%s\n' "$verifier_rows" | sed -n 's/^REVIEW: \([^ ]*\) .*/\1/p' | while IFS= read -r constraint; do
  found=0
  for accepted in $reviewed; do [ "$accepted" = "$constraint" ] && found=1; done
  [ "$found" -eq 1 ] || {
    echo "Invariant: affected semantic $constraint requires --reviewed $constraint after prospective-tree review" >&2
    exit 1
  }
  echo "REVIEW: accepted — $constraint"
done

printf '%s\n' "$checks" | sed '/^$/d' | while IFS= read -r locator; do
  run_unique_locator "$locator"
done
check_count=$(wc -l <"$executed_checks" | tr -d ' ')
echo "CHECKS: $check_count unique"

# A coordinated landing must be backed by live leases whose combined claims
# cover the branch, integration target, changed paths, domains, and governance.
if [ -n "$plan" ]; then
  plan_file="$runtime/plans/$plan.yml"
  [ -f "$plan_file" ] || { echo "Invariant: no runtime plan '$plan'" >&2; exit 1; }
  sh "$coordinate_dir/workboard-support.sh" validate "$plan" >/dev/null || exit 1
  lease_files=""
  for unit in $units; do
    lease_file="$runtime/leases/$unit.yml"
    [ -f "$lease_file" ] || { echo "Invariant: coordinated unit '$unit' has no live lease" >&2; exit 1; }
    sh "$coordinate_dir/lease-support.sh" fresh "$unit" >/dev/null || exit 1
    lease_target=$(sed -n 's/^integration_target:[[:space:]]*//p' "$lease_file" | head -1)
    [ "$lease_target" = "$target" ] || { echo "Invariant: lease '$unit' targets '$lease_target', not '$target'" >&2; exit 1; }
    if [ "$mode" = merge ]; then
      lease_branch=$(sed -n 's/^branch:[[:space:]]*//p' "$lease_file" | head -1)
      [ "$lease_branch" = "$merge_branch" ] || { echo "Invariant: lease '$unit' belongs to '$lease_branch', not '$merge_branch'" >&2; exit 1; }
    fi
    lease_files="$lease_files $lease_file"
  done

  actual_paths=$(if [ "$unborn" -eq 1 ]; then git -C "$verify_dir" diff-tree --no-commit-id --name-only -r --root HEAD; else git -C "$verify_dir" diff --name-only "$old" HEAD; fi)
  for changed in $actual_paths; do
    covered=0
    for lease_file in $lease_files; do
      claim_paths=$(sed -n 's/^paths:[[:space:]]*//p' "$lease_file" | head -1 | tr '[],' '   ')
      for claim in $claim_paths; do
        [ "$changed" = "$claim" ] && covered=1
        case "$changed" in "$claim"/*) covered=1 ;; esac
      done
    done
    [ "$covered" -eq 1 ] || { echo "Invariant: coordinated path '$changed' is outside the combined lease claims" >&2; exit 1; }
  done
  for requested in $interfaces; do
    found=0; for lease_file in $lease_files; do
      values=$(sed -n 's/^interfaces:[[:space:]]*//p' "$lease_file" | head -1 | tr '[],' '   ')
      for value in $values; do [ "$value" = "$requested" ] && found=1; done
    done
    [ "$found" -eq 1 ] || { echo "Invariant: interface '$requested' is absent from the combined lease claims" >&2; exit 1; }
  done
  for requested in $domains; do
    found=0; for lease_file in $lease_files; do
      values=$(sed -n 's/^domains:[[:space:]]*//p' "$lease_file" | head -1 | tr '[],' '   ')
      for value in $values; do [ "$value" = "$requested" ] && found=1; done
    done
    [ "$found" -eq 1 ] || { echo "Invariant: domain '$requested' is absent from the combined lease context" >&2; exit 1; }
  done
  for requested in $governance; do
    found=0; for lease_file in $lease_files; do
      values=$(sed -n 's/^governance:[[:space:]]*//p' "$lease_file" | head -1 | tr '[],' '   ')
      for value in $values; do [ "$value" = "$requested" ] && found=1; done
    done
    [ "$found" -eq 1 ] || { echo "Invariant: governance '$requested' is absent from the combined lease claims" >&2; exit 1; }
  done
fi

# Compare-and-swap is the atomic boundary: if another landing advanced the
# target during verification, this fails and the verified candidate remains
# dangling rather than overwriting newer work.
target_checkout_safe || exit 2
if [ "$unborn" -eq 1 ]; then
  zero=0000000000000000000000000000000000000000
  git update-ref "refs/heads/$target" "$candidate" "$zero"
else
  git update-ref "refs/heads/$target" "$candidate" "$old"
fi
if [ -n "$target_worktree" ]; then
  if [ "$mode" = direct ] || [ "$mode" = staged ]; then git -C "$target_worktree" read-tree "$candidate"
  else git -C "$target_worktree" read-tree --reset -u "$candidate"
  fi
fi

for unit in $units; do
  if [ -f "$runtime/leases/$unit.yml" ]; then
    sh "$coordinate_dir/lease-support.sh" release "$unit" >/dev/null
  fi
done

if [ -n "$plan" ] && [ -f "$runtime/plans/$plan.yml" ]; then
  plan_state=$(sh "$coordinate_dir/workboard-status.sh" "$plan" 2>/dev/null || true)
  if ! printf '%s\n' "$plan_state" | grep -Eq ' (active|waiting|dispatchable) '; then
    rm -f "$runtime/plans/$plan.yml"
  fi
fi

echo "LANDED: $candidate -> $target (prospective tree verified before ref update)"

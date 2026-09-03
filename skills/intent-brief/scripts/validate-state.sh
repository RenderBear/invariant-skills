#!/bin/sh
# Validate tracked Invariant state. Domains are semantic: validation checks
# identity, references, and material, never filesystem membership. Ignored
# runtime planning is deliberately outside this validator.

set -u

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
landing_mode=0
case "${1:-}" in
  --landing) landing_mode=1; shift ;;
  --audit) shift ;;
esac

tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/invariant-state.XXXXXX") || exit 2
domains="$tmp_root/domains"
contracts="$tmp_root/contracts"
constraints="$tmp_root/constraints"
observations="$tmp_root/observations"
discoveries="$tmp_root/discoveries"
audits="$tmp_root/audits"
violations="$tmp_root/violations"
files="$tmp_root/files"
: >"$domains"; : >"$contracts"; : >"$constraints"; : >"$observations"; : >"$discoveries"; : >"$audits"; : >"$violations"; : >"$files"
cleanup() { rm -rf "$tmp_root"; }
trap cleanup EXIT HUP INT TERM

fail() {
  printf 'FAIL %s\n' "$*"
  printf '%s\n' "$*" >>"$violations"
}

# The first first-parent commit carrying Intent-Boundary is the adoption
# anchor. Later ordinary commits may remain temporarily unattested, but the
# next attested landing must cover the complete contiguous suffix after the
# preceding attestation. No history rewrite is required.
validate_landing_history() {
  history="$tmp_root/landing-history"
  errors="$tmp_root/landing-history-errors"
  if ! git log --first-parent --reverse \
      --format='%H%x1c%P%x1c%(trailers:key=Intent-Boundary,valueonly,separator=%x1d)%x1c%(trailers:key=Intent-Governance,valueonly,separator=%x1d)%x1c%(trailers:key=Intent-Covers,valueonly,separator=%x1d)' \
      HEAD >"$history" 2>/dev/null; then
    fail "landing history HEAD does not resolve"
    return
  fi
  awk '
    BEGIN { field=sprintf("%c",28); multi=sprintf("%c",29); FS=field }
    {
      commit=$1; parents=$2; boundary=$3; governance=$4; covers=$5
      split(parents, parent, " "); first_parent=parent[1]
      if(!adopted && boundary!="") {
        adopted=1
        if(covers!="") print "landing history adoption commit " substr(commit,1,12) " has unexpected Intent-Covers"
      }
      if(!adopted) next
      label="landing history commit " substr(commit,1,12)
      if(boundary=="") { gap=1; tip=commit; next }
      if(index(boundary,multi)) { print label " has multiple Intent-Boundary trailers"; next }
      if(boundary!="no-record" && boundary!="recorded" && boundary!~/^audit:[a-zA-Z0-9._-]+$/) {
        print label " has an invalid Intent-Boundary disposition"
        next
      }
      if(boundary=="recorded" && governance=="")
        print label " uses Intent-Boundary recorded without Intent-Governance"
      if(last!="") {
        if(gap) {
          expected=last ".." first_parent
          if(covers=="") print label " must cover unattested range " expected
          else if(index(covers,multi)) print label " has multiple Intent-Covers trailers"
          else if(covers!=expected) print label " covers " covers " but expected " expected
        } else if(covers!="") print label " has Intent-Covers without an unattested range"
      }
      last=commit
      gap=0
    }
    END {
      if(adopted && gap) print "unattested integration range " last ".." tip " requires the next landing to carry Intent-Covers"
    }
  ' "$history" >"$errors"
  while IFS= read -r message; do [ -z "$message" ] || fail "$message"; done <"$errors"
}

[ "$landing_mode" -eq 0 ] || validate_landing_history

git ls-files --cached --others --exclude-standard -- '.intent/' 2>/dev/null |
  grep '\.ya\{0,1\}ml$' | sort -u >"$files" || true
for named do printf '%s\n' "$named" >>"$files"; done
sort -u "$files" -o "$files"

if [ ! -s "$files" ]; then
  if [ -s "$violations" ]; then
    count=$(wc -l <"$violations" | tr -d ' ')
    echo "$count intent state violation(s)"
    exit 1
  fi
  echo "no intent state — nothing to validate"
  exit 0
fi

parse_domains() {
  awk -v file="$1" '
    function val(line) { sub(/^[^:]*: */,"",line); sub(/[[:space:]]+#.*$/, "", line); return line }
    function emit() {
      if(id!="") {
        if(responsibility!="" && description!="") print "E|" file "|" id "|use responsibility, not both responsibility and legacy description"
        if(architecture!="" && material!="") print "E|" file "|" id "|use architecture, not both architecture and legacy material"
        if(responsibility=="") responsibility=description
        print "D|" file "|" id "|" responsibility "|" authority "|" parent "|" architecture "|" contracts "|" material
      }
    }
    /^[a-z_]+:/ {
      key=$0; sub(/:.*/,"",key)
      if(key!="version" && key!="domains") print "E|" file "|top|unknown top-level field " key
      next
    }
    /^  - id:/ { emit(); delete seen; id=val($0); responsibility=description=authority=parent=architecture=contracts=material=""; next }
    id!="" && /^    [a-z_]+:/ {
      key=$0; sub(/^    /,"",key); sub(/:.*/,"",key); seen[key]++
      if(seen[key]>1) print "E|" file "|" id "|duplicate field " key
      value=val($0)
      if(key=="responsibility") responsibility=value
      else if(key=="description") description=value
      else if(key=="authority") authority=value
      else if(key=="parent") parent=value
      else if(key=="architecture" || key=="contracts" || key=="material") {
        if(value !~ /^\[.*\]$/) print "E|" file "|" id "|" key " must be an inline list"
        if(key=="architecture") architecture=value
        else if(key=="contracts") contracts=value
        else material=value
      }
      else print "E|" file "|" id "|unknown domain field " key
    }
    END { emit() }
  ' "$1"
}

parse_contracts() {
  awk -v file="$1" '
    function val(line) { sub(/^[^:]*: */,"",line); sub(/[[:space:]]+#.*$/, "", line); return line }
    function emit() {
      if(id!="") {
        if(architecture!="" && material!="") print "E|" file "|" id "|use architecture, not both architecture and legacy material"
        print "C|" file "|" id "|" assertion "|" authority "|" between "|" surfaces "|" architecture "|" verifies "|" material
      }
    }
    /^[a-z_]+:/ {
      key=$0; sub(/:.*/,"",key)
      if(key!="version" && key!="contracts") print "E|" file "|top|unknown top-level field " key
      next
    }
    /^  - id:/ { emit(); delete seen; id=val($0); assertion=authority=between=surfaces=architecture=material=verifies=""; next }
    id!="" && /^    [a-z_]+:/ {
      key=$0; sub(/^    /,"",key); sub(/:.*/,"",key); seen[key]++
      if(seen[key]>1) print "E|" file "|" id "|duplicate field " key
      value=val($0)
      if(key=="assertion") assertion=value
      else if(key=="authority") authority=value
      else if(key=="between" || key=="surfaces" || key=="architecture" || key=="material" || key=="verifies") {
        if(value !~ /^\[.*\]$/) print "E|" file "|" id "|" key " must be an inline list"
        if(key=="between") between=value
        else if(key=="surfaces") surfaces=value
        else if(key=="architecture") architecture=value
        else if(key=="material") material=value
        else verifies=value
      } else print "E|" file "|" id "|unknown contract field " key
    }
    END { emit() }
  ' "$1"
}

parse_constraints() {
  awk -v file="$1" '
    function val(line) { sub(/^[^:]*: */,"",line); sub(/[[:space:]]+#.*$/, "", line); return line }
    function emit() { if(id!="") print "N|" file "|" id "|" assertion "|" authority "|" applies "|" surfaces "|" material "|" verifies }
    /^[a-z_]+:/ {
      key=$0; sub(/:.*/,"",key)
      if(key!="version" && key!="constraints") print "E|" file "|top|unknown top-level field " key
      next
    }
    /^  - id:/ { emit(); delete seen; id=val($0); assertion=authority=applies=surfaces=material=verifies=""; next }
    id!="" && /^    [a-z_]+:/ {
      key=$0; sub(/^    /,"",key); sub(/:.*/,"",key); seen[key]++
      if(seen[key]>1) print "E|" file "|" id "|duplicate field " key
      value=val($0)
      if(key=="assertion") assertion=value
      else if(key=="authority") authority=value
      else if(key=="applies_to" || key=="surfaces" || key=="material" || key=="verifies") {
        if(value !~ /^\[.*\]$/) print "E|" file "|" id "|" key " must be an inline list"
        if(key=="applies_to") applies=value
        else if(key=="surfaces") surfaces=value
        else if(key=="material") material=value
        else verifies=value
      } else print "E|" file "|" id "|unknown constraint field " key
    }
    END { emit() }
  ' "$1"
}

parse_observation() {
  awk -v file="$1" '
    function val(line) { sub(/^[^:]*: */,"",line); sub(/[[:space:]]+#.*$/, "", line); return line }
    /^[a-z_]+:/ {
      key=$0; sub(/:.*/,"",key); seen[key]++
      if(seen[key]>1) print "E|" file "|observation|duplicate field " key
      value=val($0)
      if(key=="id") id=value
      else if(key=="ground") ground=value
      else if(key=="statement") statement=value
      else if(key=="evidence") { evidence=value; if(value !~ /^\[.*\]$/) print "E|" file "|observation|evidence must be an inline list" }
      else if(key=="relates_to") { relates=value; if(value !~ /^\[.*\]$/) print "E|" file "|observation|relates_to must be an inline list" }
      else if(key!="version") print "E|" file "|observation|unknown field " key
    }
    END { print "O|" file "|" id "|" ground "|" statement "|" evidence "|" relates }
  ' "$1"
}

parse_discovery() {
  awk -v file="$1" '
    function val(line) { sub(/^[^:]*: */,"",line); sub(/[[:space:]]+#.*$/, "", line); return line }
    /^[a-z_]+:/ {
      key=$0; sub(/:.*/,"",key); seen[key]++
      if(seen[key]>1) print "E|" file "|discovery|duplicate field " key
      value=val($0)
      if(key=="id") id=value
      else if(key=="status") status=value
      else if(key=="ground") ground=value
      else if(key=="tree") tree=value
      else if(key=="statement") statement=value
      else if(key=="reason") reason=value
      else if(key=="domains" || key=="evidence" || key=="candidates" || key=="resolution") {
        if(value !~ /^\[.*\]$/) print "E|" file "|discovery|" key " must be an inline list"
        if(key=="domains") domains=value
        else if(key=="evidence") evidence=value
        else if(key=="candidates") candidates=value
        else resolution=value
      }
      else if(key!="version") print "E|" file "|discovery|unknown field " key
    }
    END { print "Y|" file "|" id "|" status "|" ground "|" tree "|" domains "|" statement "|" evidence "|" candidates "|" resolution "|" reason }
  ' "$1"
}

parse_audit() {
  awk -v file="$1" '
    function val(line) { sub(/^[^:]*: */,"",line); sub(/[[:space:]]+#.*$/, "", line); return line }
    function emit() { if(fid!="") print "F|" file "|" fid "|" summary "|" evidence "|" proposed "|" disposition "|" authority }
    /^[a-z_]+:/ {
      emit(); fid=""
      key=$0; sub(/:.*/,"",key); seen[key]++; if(seen[key]>1) print "E|" file "|audit|duplicate field " key
      value=val($0)
      if(key=="id") id=value
      else if(key=="ground") ground=value
      else if(key=="tree") tree=value
      else if(key=="mode") mode=value
      else if(key=="domains" || key=="paths") {
        if(value !~ /^\[.*\]$/) print "E|" file "|audit|" key " must be an inline list"
        if(key=="domains") domains=value; else paths=value
      }
      else if(key=="findings") { findings=1; if(value!="" && value!="[]") print "E|" file "|audit|findings must be a list or []" }
      else if(key!="version") print "E|" file "|audit|unknown field " key
      next
    }
    /^  - id:/ { emit(); fid=val($0); summary=evidence=proposed=disposition=authority=""; next }
    fid!="" && /^    [a-z_]+:/ {
      key=$0; sub(/^    /,"",key); sub(/:.*/,"",key); fseen[fid SUBSEP key]++
      if(fseen[fid SUBSEP key]>1) print "E|" file "|" fid "|duplicate field " key
      value=val($0)
      if(key=="summary") summary=value
      else if(key=="evidence") { evidence=value; if(value !~ /^\[.*\]$/) print "E|" file "|" fid "|evidence must be an inline list" }
      else if(key=="proposed") proposed=value
      else if(key=="disposition") disposition=value
      else if(key=="authority") authority=value
      else print "E|" file "|" fid "|unknown finding field " key
    }
    END { emit(); print "A|" file "|" id "|" ground "|" tree "|" mode "|" findings "|" domains "|" paths }
  ' "$1"
}

while IFS= read -r file; do
  [ -n "$file" ] || continue
  [ -f "$file" ] || { fail "$file does not exist"; continue; }
  grep -q '^version: 1$' "$file" || fail "$file must declare version: 1"
  case "$file" in
    .intent/config.yml|*/.intent/config.yml)
      if ! error=$(sh "$script_dir/resolve-config.sh" 2>&1 >/dev/null); then
        fail "$file $(printf '%s' "$error" | sed 's/^Invariant: //')"
      fi
      ;;
    .intent/DOMAINS.yml|*/.intent/DOMAINS.yml)
      grep -q '^domains:$' "$file" || fail "$file must contain a domains list"
      grep -q '^  - id:' "$file" || fail "$file contains no domains; remove it"
      parse_domains "$file" >>"$domains"
      ;;
    .intent/CONTRACTS.yml|*/.intent/CONTRACTS.yml)
      grep -q '^contracts:$' "$file" || fail "$file must contain a contracts list"
      grep -q '^  - id:' "$file" || fail "$file contains no contracts; remove it"
      parse_contracts "$file" >>"$contracts"
      ;;
    .intent/CONSTRAINTS.yml|*/.intent/CONSTRAINTS.yml)
      grep -q '^constraints:$' "$file" || fail "$file must contain a constraints list"
      grep -q '^  - id:' "$file" || fail "$file contains no constraints; remove it"
      parse_constraints "$file" >>"$constraints"
      ;;
    .intent/audits/*.yml|*/.intent/audits/*.yml)
      parse_audit "$file" >>"$audits"
      ;;
    .intent/observations/*.yml|*/.intent/observations/*.yml)
      parse_observation "$file" >>"$observations"
      ;;
    .intent/discoveries/*.yml|*/.intent/discoveries/*.yml)
      parse_discovery "$file" >>"$discoveries"
      ;;
    *) fail "$file is not a version-1 config, domain, contract, legacy constraint, audit, discovery, or observation file" ;;
  esac
done <"$files"

awk -F'|' '$1=="E" { print $2 "|" $3 "|" $4 }' "$domains" "$contracts" "$constraints" "$observations" "$discoveries" "$audits" |
while IFS='|' read -r file id message; do fail "$file:$id $message"; done

normalise_refs() { printf '%s' "$1" | tr -d '[],' | tr ' ' '\n' | sed '/^$/d'; }
valid_id() { case "$1" in ''|.*|*..*|*.) return 1 ;; *[!a-zA-Z0-9._-]*) return 1 ;; *) return 0 ;; esac; }

check_authority() {
  locator=$1 label=$2
  case "$locator" in
    user:task:*|user:url:http://*|user:url:https://*|design:task:*|design:url:http://*|design:url:https://*) ;;
    architecture:repo:*|design:repo:*)
      path=${locator#*:repo:}; path=${path%%#*}; [ -e "$path" ] || fail "$label authority target '$path' does not exist" ;;
    *) fail "$label authority is not an inspectable user:, design:, or architecture: locator" ;;
  esac
}

check_material() {
  locator=$1 label=$2
  case "$locator" in
    repo:*|architecture:*|adr:*|schema:*)
      path=${locator#*:}; path=${path%%#*}; [ -e "$path" ] || fail "$label material '$path' does not exist" ;;
    task:*|url:http://*|url:https://*) ;;
    *) fail "$label material '$locator' must use repo:, architecture:, adr:, schema:, task:, or url:" ;;
  esac
}

architecture_anchor_exists() {
  path=$1; wanted=$2
  awk -v wanted="$wanted" '
    function slug(value) {
      value=tolower(value)
      gsub(/[`*_~]/, "", value)
      gsub(/[^a-z0-9 _-]/, "", value)
      gsub(/[[:space:]]+/, "-", value)
      gsub(/^-+|-+$/, "", value)
      return value
    }
    /^#{1,6}[[:space:]]+/ {
      heading=$0
      sub(/^#{1,6}[[:space:]]+/, "", heading)
      sub(/[[:space:]]+#+[[:space:]]*$/, "", heading)
      if(slug(heading)==wanted) found=1
    }
    END {exit found ? 0 : 1}
  ' "$path"
}

check_architecture() {
  locator=$1 label=$2
  case "$locator" in
    architecture:*#?*)
      path=${locator#architecture:}; anchor=${path#*#}; path=${path%%#*}
      case "$path" in *.md|*.markdown|*.MD|*.MARKDOWN) ;; *) fail "$label architecture '$path' must be Markdown"; return ;; esac
      [ -f "$path" ] || { fail "$label architecture '$path' does not exist"; return; }
      architecture_anchor_exists "$path" "$anchor" || fail "$label architecture anchor '#$anchor' does not exist in $path"
      ;;
    *) fail "$label architecture '$locator' must use architecture:<markdown-path>#<decision-id>" ;;
  esac
}

check_surface() {
  locator=$1 label=$2
  case "$locator" in
    repo:*) path=${locator#repo:}; path=${path%%#*}; [ -e "$path" ] || fail "$label surface '$path' does not exist" ;;
    interface:?*) ;;
    *) fail "$label surface '$locator' must use repo: or interface:" ;;
  esac
}

check_verifier() {
  locator=$1 label=$2
  case "$locator" in
    command:*) path=${locator#command:}; [ -f "$path" ] || fail "$label verifier '$path' does not exist"; [ -x "$path" ] || fail "$label command verifier '$path' is not executable" ;;
    test:*) path=${locator#test:}; path=${path%%::*}; [ -f "$path" ] || fail "$label verifier '$path' does not exist" ;;
    schema:*) path=${locator#schema:}; path=${path%%#*}; [ -f "$path" ] || fail "$label verifier '$path' does not exist" ;;
    *) fail "$label verifier '$locator' must use command:, test:, or schema:" ;;
  esac
}

check_evidence() {
  locator=$1 label=$2 at=${3:-}
  case "$locator" in
    repo:*)
      path=${locator#repo:}; path=${path%%#*}
      if [ -n "$at" ] && [ "$at" != unborn ] && [ "$at" != empty ]; then
        git cat-file -e "$at:$path" 2>/dev/null || fail "$label evidence '$path' does not exist at $at"
      else
        [ -e "$path" ] || fail "$label evidence '$path' does not exist"
      fi
      ;;
    commit:*) ref=${locator#commit:}; git rev-parse -q --verify "$ref^{commit}" >/dev/null 2>&1 || fail "$label evidence commit '$ref' does not resolve" ;;
    interface:?*|task:*|url:http://*|url:https://*) ;;
    *) fail "$label evidence '$locator' must use repo:, commit:, interface:, task:, or url:" ;;
  esac
}

domain_ids="$tmp_root/domain-ids"
awk -F'|' '$1=="D" { print $3 }' "$domains" >"$domain_ids"
sort "$domain_ids" | uniq -d | while IFS= read -r id; do [ -z "$id" ] || fail "duplicate domain '$id'"; done

edges="$tmp_root/domain-edges"; : >"$edges"
awk -F'|' '$1=="D" { print }' "$domains" |
while IFS='|' read -r _ file id responsibility authority parent architecture contracts material; do
  valid_id "$id" || fail "$file invalid domain id '$id'"
  [ -n "$responsibility" ] || fail "$file:$id missing responsibility"
  check_authority "$authority" "$file:$id"
  if [ -n "$parent" ]; then
    grep -qxF "$parent" "$domain_ids" || fail "$file:$id references missing parent '$parent'"
    printf '%s|%s\n' "$id" "$parent" >>"$edges"
  fi
  for locator in $(normalise_refs "$architecture"); do check_architecture "$locator" "$file:$id"; done
  for locator in $(normalise_refs "$material"); do check_material "$locator" "$file:$id"; done
done

awk -F'|' '$1=="A" { print }' "$audits" |
while IFS='|' read -r _ file id ground tree mode findings selected paths; do
  valid_id "$id" || fail "$file invalid audit id '$id'"
  base=$(basename "$file"); base=${base%.*}; [ "$base" = "$id" ] || fail "$file filename must be $id.yml"
  case "$mode" in scope|full) ;; *) fail "$file invalid audit mode '$mode'" ;; esac
  [ "$findings" = 1 ] || fail "$file missing findings"
  [ -n "$ground" ] || fail "$file missing ground"
  [ -n "$tree" ] || fail "$file missing tree"
  if [ "$ground" != unborn ]; then git rev-parse -q --verify "$ground^{commit}" >/dev/null 2>&1 || fail "$file ground '$ground' does not resolve"; fi
  if [ "$tree" != empty ]; then git rev-parse -q --verify "$tree^{tree}" >/dev/null 2>&1 || fail "$file tree '$tree' does not resolve"; fi
  for domain in $(normalise_refs "$selected"); do grep -qxF "$domain" "$domain_ids" || fail "$file references missing domain '$domain'"; done
  count=0
  for path in $(normalise_refs "$paths"); do
    count=$((count + 1))
    case "$path" in /*|../*|*/../*|*'/..') fail "$file has invalid audit path '$path'"; continue ;; esac
    if [ "$tree" != empty ]; then git cat-file -e "$tree:$path" 2>/dev/null || fail "$file audit path '$path' does not exist in tree $tree"; fi
  done
  [ "$mode" != scope ] || [ "$count" -gt 0 ] || fail "$file scoped audit requires at least one path"
done

awk -F'|' '$1=="F" { print }' "$audits" |
while IFS='|' read -r _ file id summary evidence proposed disposition authority; do
  valid_id "$id" || fail "$file invalid finding id '$id'"
  [ -n "$summary" ] || fail "$file:$id missing summary"
  audit_tree=$(awk -F'|' -v f="$file" '$1=="A" && $2==f { print $5; exit }' "$audits")
  count=0; for locator in $(normalise_refs "$evidence"); do count=$((count + 1)); check_evidence "$locator" "$file:$id" "$audit_tree"; done
  [ "$count" -gt 0 ] || fail "$file:$id requires evidence"
  case "$proposed" in domain|contract|architecture|discovery|none|constraint|observation) ;; *) fail "$file:$id invalid proposed value '$proposed'" ;; esac
  case "$disposition" in adoptable|needs-authority|needs-verifier|discovery-only|no-action|observation-only) ;; *) fail "$file:$id invalid disposition '$disposition'" ;; esac
  [ -z "$authority" ] || check_authority "$authority" "$file:$id"
done

if [ -s "$edges" ] && ! awk -F'|' '
  function visit(n, i,v) { if(visiting[n]) return 1; if(done[n]) return 0; visiting[n]=1; for(i=1;i<=count[n];i++){v=edge[n,i]; if(visit(v)) return 1} visiting[n]=0; done[n]=1; return 0 }
  { edge[$1,++count[$1]]=$2; nodes[$1]=nodes[$2]=1 }
  END { for(n in nodes) if(visit(n)) exit 1 }
' "$edges"; then fail "domain parent graph contains a cycle"; fi

contract_ids="$tmp_root/contract-ids"
awk -F'|' '$1=="C" { print $3 }' "$contracts" >"$contract_ids"
sort "$contract_ids" | uniq -d | while IFS= read -r id; do [ -z "$id" ] || fail "duplicate contract '$id'"; done
awk -F'|' '$1=="C" { print }' "$contracts" |
while IFS='|' read -r _ file id assertion authority between surfaces architecture verifies material; do
  valid_id "$id" || fail "$file invalid contract id '$id'"
  [ -n "$assertion" ] || fail "$file:$id missing assertion"
  check_authority "$authority" "$file:$id"
  count=0; seen_between=""
  for domain in $(normalise_refs "$between"); do
    count=$((count + 1)); grep -qxF "$domain" "$domain_ids" || fail "$file:$id references missing domain '$domain'"
    case " $seen_between " in *" $domain "*) fail "$file:$id repeats domain '$domain'" ;; esac; seen_between="$seen_between $domain"
  done
  [ "$count" -ge 2 ] || fail "$file:$id requires at least two domains in between"
  count=0; for locator in $(normalise_refs "$surfaces"); do count=$((count + 1)); check_surface "$locator" "$file:$id"; done
  [ "$count" -gt 0 ] || fail "$file:$id requires at least one surface"
  count=0
  for locator in $(normalise_refs "$architecture"); do count=$((count + 1)); check_architecture "$locator" "$file:$id"; done
  for locator in $(normalise_refs "$material"); do count=$((count + 1)); check_material "$locator" "$file:$id"; done
  [ "$count" -gt 0 ] || fail "$file:$id requires defining material"
  count=0; for locator in $(normalise_refs "$verifies"); do count=$((count + 1)); check_verifier "$locator" "$file:$id"; done
  [ "$count" -gt 0 ] || fail "$file:$id requires executable verification"
done

awk -F'|' '$1=="D" { print }' "$domains" |
while IFS='|' read -r _ file id responsibility authority parent architecture contracts material; do
  for contract in $(normalise_refs "$contracts"); do
    grep -qxF "$contract" "$contract_ids" || fail "$file:$id references missing contract '$contract'"
  done
done

constraint_ids="$tmp_root/constraint-ids"
awk -F'|' '$1=="N" { print $3 }' "$constraints" >"$constraint_ids"
sort "$constraint_ids" | uniq -d | while IFS= read -r id; do [ -z "$id" ] || fail "duplicate constraint '$id'"; done
awk -F'|' '$1=="N" { print }' "$constraints" |
while IFS='|' read -r _ file id assertion authority applies surfaces material verifies; do
  valid_id "$id" || fail "$file invalid constraint id '$id'"
  [ -n "$assertion" ] || fail "$file:$id missing assertion"
  check_authority "$authority" "$file:$id"
  count=0; for domain in $(normalise_refs "$applies"); do count=$((count + 1)); grep -qxF "$domain" "$domain_ids" || fail "$file:$id references missing domain '$domain'"; done
  [ "$count" -gt 0 ] || fail "$file:$id requires at least one domain in applies_to"
  for locator in $(normalise_refs "$surfaces"); do check_surface "$locator" "$file:$id"; done
  count=0; for locator in $(normalise_refs "$material"); do count=$((count + 1)); check_material "$locator" "$file:$id"; done
  [ "$count" -gt 0 ] || fail "$file:$id requires defining material"
  for locator in $(normalise_refs "$verifies"); do check_verifier "$locator" "$file:$id"; done
done

awk -F'|' '$1=="O" { print }' "$observations" |
while IFS='|' read -r _ file id ground statement evidence relates; do
  valid_id "$id" || fail "$file invalid observation id '$id'"
  base=$(basename "$file"); base=${base%.*}; [ "$base" = "$id" ] || fail "$file filename must be $id.yml"
  [ -n "$statement" ] || fail "$file:$id missing statement"
  [ -n "$ground" ] || fail "$file:$id missing ground"
  if [ "$ground" != unborn ]; then git rev-parse -q --verify "$ground^{commit}" >/dev/null 2>&1 || fail "$file:$id ground '$ground' does not resolve"; fi
  count=0; for locator in $(normalise_refs "$evidence"); do count=$((count + 1)); check_evidence "$locator" "$file:$id" "$ground"; done
  [ "$count" -gt 0 ] || fail "$file:$id requires evidence"
  for ref in $(normalise_refs "$relates"); do
    case "$ref" in
      domain:*) grep -qxF "${ref#domain:}" "$domain_ids" || fail "$file:$id relates to missing '$ref'" ;;
      contract:*) grep -qxF "${ref#contract:}" "$contract_ids" || fail "$file:$id relates to missing '$ref'" ;;
      constraint:*) grep -qxF "${ref#constraint:}" "$constraint_ids" || fail "$file:$id relates to missing '$ref'" ;;
      *) fail "$file:$id relates_to '$ref' must name domain:, contract:, or constraint:" ;;
    esac
  done
done

discovery_ids="$tmp_root/discovery-ids"
awk -F'|' '$1=="Y" { print $3 }' "$discoveries" >"$discovery_ids"
sort "$discovery_ids" | uniq -d | while IFS= read -r id; do [ -z "$id" ] || fail "duplicate discovery '$id'"; done
awk -F'|' '$1=="Y" { print }' "$discoveries" |
while IFS='|' read -r _ file id status ground tree selected statement evidence candidates resolution reason; do
  valid_id "$id" || fail "$file invalid discovery id '$id'"
  base=$(basename "$file"); base=${base%.*}; [ "$base" = "$id" ] || fail "$file filename must be $id.yml"
  case "$status" in pending|promoted|dismissed|superseded|stale) ;; *) fail "$file:$id invalid status '$status'" ;; esac
  [ -n "$statement" ] || fail "$file:$id missing statement"
  [ -n "$ground" ] || fail "$file:$id missing ground"
  [ -n "$tree" ] || fail "$file:$id missing tree"
  if [ "$ground" != unborn ]; then git rev-parse -q --verify "$ground^{commit}" >/dev/null 2>&1 || fail "$file:$id ground '$ground' does not resolve"; fi
  if [ "$tree" != empty ]; then git rev-parse -q --verify "$tree^{tree}" >/dev/null 2>&1 || fail "$file:$id tree '$tree' does not resolve"; fi
  for domain in $(normalise_refs "$selected"); do grep -qxF "$domain" "$domain_ids" || fail "$file:$id references missing domain '$domain'"; done
  count=0; for locator in $(normalise_refs "$evidence"); do count=$((count + 1)); check_evidence "$locator" "$file:$id" "$tree"; done
  [ "$count" -gt 0 ] || fail "$file:$id requires evidence"
  candidate_count=0
  for candidate in $(normalise_refs "$candidates"); do
    candidate_count=$((candidate_count + 1))
    case "$candidate" in domain|architecture|contract) ;; *) fail "$file:$id invalid candidate '$candidate'" ;; esac
  done
  [ "$status" != pending ] || [ "$candidate_count" -gt 0 ] || fail "$file:$id pending discovery requires at least one candidate"
  resolution_count=0; superseding=0
  for ref in $(normalise_refs "$resolution"); do
    resolution_count=$((resolution_count + 1))
    case "$ref" in
      domain:*) grep -qxF "${ref#domain:}" "$domain_ids" || fail "$file:$id resolves to missing '$ref'" ;;
      contract:*) grep -qxF "${ref#contract:}" "$contract_ids" || fail "$file:$id resolves to missing '$ref'" ;;
      architecture:*) check_architecture "$ref" "$file:$id" ;;
      discovery:*) superseding=1; grep -qxF "${ref#discovery:}" "$discovery_ids" || fail "$file:$id resolves to missing '$ref'" ;;
      *) fail "$file:$id resolution '$ref' must name domain:, contract:, architecture:, or discovery:" ;;
    esac
  done
  case "$status" in
    pending) [ "$resolution_count" -eq 0 ] || fail "$file:$id pending discovery cannot have a resolution" ;;
    promoted) [ "$resolution_count" -gt 0 ] || fail "$file:$id promoted discovery requires a resolution" ;;
    superseded) [ "$superseding" -eq 1 ] || fail "$file:$id superseded discovery must resolve to discovery:<id>" ;;
    dismissed|stale) [ -n "$reason" ] || fail "$file:$id $status discovery requires a reason" ;;
  esac
done

if [ -s "$violations" ]; then
  count=$(wc -l <"$violations" | tr -d ' ')
  echo "$count intent state violation(s)"
  exit 1
fi
echo "intent state valid"

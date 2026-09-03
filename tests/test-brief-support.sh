#!/bin/sh
# Verify semantic-domain briefing, reach, digests, and trailer containment.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
brief="$root/skills/intent-brief/scripts/brief-support.sh"
fixture=$(mktemp -d "${TMPDIR:-/tmp}/invariant-brief-test.XXXXXX")
cleanup() { rm -rf "$fixture"; }
trap cleanup EXIT HUP INT TERM

git -C "$fixture" init -qb main
git -C "$fixture" config user.name test
git -C "$fixture" config user.email test@example.com
git -C "$fixture" config commit.gpgsign false
mkdir -p "$fixture/.intent/audits" "$fixture/.intent/observations" "$fixture/.hidden" \
  "$fixture/Upper Dir" "$fixture/packages/Fancy App" "$fixture/docs" "$fixture/src/ocr" \
  "$fixture/ui" "$fixture/schemas" "$fixture/checks"
printf '# OCR architecture\n' >"$fixture/docs/architecture.md"
cat >"$fixture/README.md" <<'EOF'
# Example

## Submit and observe a job

Submit work and observe its events.

## Local setup

Run the local service.
EOF
printf '{}\n' >"$fixture/schemas/ocr.json"
printf 'ocr\n' >"$fixture/src/ocr/engine.txt"
printf 'ui\n' >"$fixture/ui/view.txt"
printf 'hidden\n' >"$fixture/.hidden/existing.txt"
printf 'upper\n' >"$fixture/Upper Dir/existing.txt"
printf '{}\n' >"$fixture/packages/Fancy App/package.json"
printf '{}\n' >"$fixture/package.json"
cat >"$fixture/checks/verify.sh" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$fixture/checks/verify.sh"
cat >"$fixture/.intent/config.yml" <<'EOF'
version: 1
resolution: assisted
EOF
cat >"$fixture/.intent/DOMAINS.yml" <<'EOF'
version: 1
domains:
  - id: ocr
    description: OCR capabilities.
    authority: user:task:test#turn-1
    material: [architecture:docs/architecture.md]
  - id: ocr.orchestrator
    description: Selects engines.
    authority: user:task:test#turn-1
    parent: ocr
  - id: ocr.external
    description: Runs an external OCR provider.
    authority: user:task:test#turn-1
    parent: ocr
EOF
cat >"$fixture/.intent/CONTRACTS.yml" <<'EOF'
version: 1
contracts:
  - id: ocr.protocol.v1
    assertion: Engines preserve the shared OCR request and result shape.
    authority: user:task:test#turn-1
    between: [ocr.orchestrator, ocr.external]
    surfaces: [interface:OcrEngine, repo:schemas/ocr.json]
    material: [architecture:docs/architecture.md]
    verifies: [command:checks/verify.sh]
  - id: ocr.submit-doc
    assertion: The submission documentation preserves the public job flow.
    authority: user:task:test#turn-1
    between: [ocr.orchestrator, ocr.external]
    surfaces: [interface:SubmitJob]
    material: [architecture:README.md#submit-and-observe-a-job]
    verifies: [command:checks/verify.sh]
  - id: ocr.setup-doc
    assertion: The setup documentation preserves the supported local workflow.
    authority: user:task:test#turn-1
    between: [ocr.orchestrator, ocr.external]
    surfaces: [interface:LocalSetup]
    material: [architecture:README.md#local-setup]
    verifies: [command:checks/verify.sh]
EOF
cat >"$fixture/.intent/CONSTRAINTS.yml" <<'EOF'
version: 1
constraints:
  - id: ocr.provider-isolation
    assertion: Provider details remain inside engine domains.
    authority: user:task:test#turn-1
    applies_to: [ocr]
    material: [architecture:docs/architecture.md]
EOF
git -C "$fixture" add -A
git -C "$fixture" commit -qm seed

ok() { echo "ok - $1"; }
die() { echo "not ok - $1"; exit 1; }

out=$(cd "$fixture" && sh "$brief" reach --paths ui/view.txt)
printf '%s\n' "$out" | grep -q '^REACH: local$' || die "ordinary UI change gained governance ceremony"
printf '%s\n' "$out" | grep -q '^TOPOLOGY: area.ui$' || die "derived scope missing"
printf '%s\n' "$out" | grep -q '^TOPOLOGY-NEW:' && die "existing UI topology was reported as new"
ok "simple ungoverned UI work remains local"

out=$(cd "$fixture" && sh "$brief" reach --paths .hidden/new.txt "Upper Dir/new.txt" \
  "packages/Fancy App/new.txt" root-new.txt)
printf '%s\n' "$out" | grep -q '^TOPOLOGY: area.root$' || die "root topology missing from committed tree edge case"
printf '%s\n' "$out" | grep -q '^TOPOLOGY: area.upper-dir$' || die "uppercase and spaced area slug changed"
printf '%s\n' "$out" | grep -q '^TOPOLOGY: area.packages$' || die "nested package area missing"
printf '%s\n' "$out" | grep -q '^TOPOLOGY: pkg.fancy-app$' || die "nested package slug changed"
printf '%s\n' "$out" | grep -q '^TOPOLOGY-NEW:' && die "committed tree edge-case topology was reported as new"
ok "committed tree scopes preserve hidden, uppercase, spaced, package, and root-marker behavior"

mkdir -p "$fixture/migrations"
printf 'create table example(id integer);\n' >"$fixture/migrations/001.sql"
out=$(cd "$fixture" && sh "$brief" reach --paths migrations/001.sql)
printf '%s\n' "$out" | grep -q '^TOPOLOGY-NEW: area.migrations$' || die "new area topology was not reported"
printf '%s\n' "$out" | grep -q '^REACH: local$' || die "new topology invented governance reach"
rm -rf "$fixture/migrations"
ok "new topology is advisory and remains semantically local"

out=$(cd "$fixture" && sh "$brief" reach --paths src/ocr/engine.txt --domain ocr.external)
printf '%s\n' "$out" | grep -q '^AFFECTED: contract:ocr.protocol.v1 (bounded)$' || die "domain contract not selected"
printf '%s\n' "$out" | grep -q '^AFFECTED: constraint:ocr.provider-isolation (bounded)$' || die "parent constraint not selected"
printf '%s\n' "$out" | grep -q '^REVIEW: constraint:ocr.provider-isolation' || die "semantic constraint review not emitted"
printf '%s\n' "$out" | grep -q '^REACH: bounded$' || die "accepted domain work is not bounded"
ok "semantic domain selection includes parent constraints and cross-domain contracts"

out=$(cd "$fixture" && sh "$brief" verifiers --paths src/ocr/engine.txt --domain ocr.external)
printf '%s\n' "$out" | grep -q '^VERIFY: contract:ocr.protocol.v1 command:checks/verify.sh$' || die "contract verifier missing"
printf '%s\n' "$out" | grep -q '^REVIEW: constraint:ocr.provider-isolation' || die "constraint review missing"
ok "contracts verify mechanically while constraints retain semantic review"

out=$(cd "$fixture" && sh "$brief" reach --paths schemas/ocr.json)
printf '%s\n' "$out" | grep -q '^AFFECTED: contract:ocr.protocol.v1 (bounded)$' || die "contract surface did not resolve mechanically"
out=$(cd "$fixture" && sh "$brief" reach --paths ui/view.txt --interface OcrEngine)
printf '%s\n' "$out" | grep -q '^AFFECTED: contract:ocr.protocol.v1 (bounded)$' || die "interface surface did not resolve"
ok "contract surfaces remain mechanically discoverable without routes"

out=$(cd "$fixture" && sh "$brief" reach --paths docs/architecture.md --domain ocr.external)
printf '%s\n' "$out" | grep -q '^REACH: open$' || die "defining material change did not open governance"
ok "defining material changes are open"

sed 's/Submit work and observe its events/Submit work and stream its events/' "$fixture/README.md" >"$fixture/README.tmp"
mv "$fixture/README.tmp" "$fixture/README.md"
out=$(cd "$fixture" && sh "$brief" reach --paths README.md)
printf '%s\n' "$out" | grep -q '^AFFECTED: contract:ocr.submit-doc (open)$' || die "changed Markdown section did not reach its contract"
printf '%s\n' "$out" | grep -q 'contract:ocr.setup-doc' && die "unchanged Markdown section reached an unrelated contract"
git -C "$fixture" checkout -q -- README.md
ok "working-tree Markdown hunks route section-specific material"

readme_base=$(git -C "$fixture" rev-parse HEAD)
sed 's/Run the local service/Run the local development service/' "$fixture/README.md" >"$fixture/README.tmp"
mv "$fixture/README.tmp" "$fixture/README.md"
git -C "$fixture" commit -qam "change setup section"
out=$(cd "$fixture" && sh "$brief" reach "$readme_base")
printf '%s\n' "$out" | grep -q '^AFFECTED: contract:ocr.setup-doc (open)$' || die "committed Markdown section did not reach its contract"
printf '%s\n' "$out" | grep -q 'contract:ocr.submit-doc' && die "candidate routing selected an unchanged Markdown section"
ok "candidate-tree Markdown hunks route section-specific material"

out=$(cd "$fixture" && sh "$brief" reach --paths README.md)
printf '%s\n' "$out" | grep -q '^AFFECTED: contract:ocr.submit-doc (open)$' || die "hypothetical path check narrowed without diff evidence"
printf '%s\n' "$out" | grep -q '^AFFECTED: contract:ocr.setup-doc (open)$' || die "hypothetical path check omitted anchored material"
ok "path-only Markdown checks remain conservatively file-wide"

digest=$(cd "$fixture" && sh "$brief" digest ocr.external | sed 's/^DIGEST: //')
printf 'note\n' >"$fixture/.intent/observations/doc-location.yml"
after_observation=$(cd "$fixture" && sh "$brief" digest ocr.external | sed 's/^DIGEST: //')
[ "$digest" = "$after_observation" ] || die "non-authoritative observation entered governing digest"
sed 's/Provider details remain/Provider-specific details remain/' "$fixture/.intent/CONSTRAINTS.yml" >"$fixture/.intent/CONSTRAINTS.tmp"
mv "$fixture/.intent/CONSTRAINTS.tmp" "$fixture/.intent/CONSTRAINTS.yml"
after_constraint=$(cd "$fixture" && sh "$brief" digest ocr.external | sed 's/^DIGEST: //')
[ "$digest" != "$after_constraint" ] || die "constraint change did not change digest"
if (cd "$fixture" && sh "$brief" observe "$digest" ocr.external >/dev/null 2>&1); then die "stale digest was accepted"; fi
git -C "$fixture" checkout -q -- .intent/CONSTRAINTS.yml
rm "$fixture/.intent/observations/doc-location.yml"
ok "digest covers governance and excludes evidence"

printf '  - id: ocr.embedded\n    description: Embedded OCR engine.\n    authority: user:task:test#turn-2\n    parent: ocr\n' >>"$fixture/.intent/DOMAINS.yml"
out=$(cd "$fixture" && sh "$brief" reach --paths .intent/DOMAINS.yml)
printf '%s\n' "$out" | grep -q '^REACH: gated$' || die "working-tree governance edit was not conservative"
git -C "$fixture" checkout -q -- .intent/DOMAINS.yml
ok "existing governance rewrites are conservatively gated"

msg=$(cd "$fixture" && sh "$brief" message "change engine" --unit engine --scope area.src --domain ocr.external)
printf '%s\n' "$msg" | grep -q '^Intent-Domain: ocr.external$' || die "semantic domain trailer missing"
printf 'changed\n' >>"$fixture/src/ocr/engine.txt"
git -C "$fixture" commit -qam "$msg"
(cd "$fixture" && sh "$brief" trailer HEAD >/dev/null) || die "honest derived scope/domain trailers failed"
ok "commit trailers retain mechanical scope and semantic domain separately"

echo "13 brief checks passed"

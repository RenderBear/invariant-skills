#!/bin/sh
# Verify version-1 semantic governance and tracked evidence schemas.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
validator="$root/skills/intent-brief/scripts/validate-state.sh"
fixture=$(mktemp -d "${TMPDIR:-/tmp}/invariant-state-test.XXXXXX")
history="$fixture-history"
cleanup() { rm -rf "$fixture" "$history"; }
trap cleanup EXIT HUP INT TERM

git -C "$fixture" init -qb main
git -C "$fixture" config user.name test
git -C "$fixture" config user.email test@example.com
git -C "$fixture" config commit.gpgsign false
mkdir -p "$fixture/.intent/audits" "$fixture/.intent/observations" "$fixture/docs" "$fixture/src" "$fixture/schemas" "$fixture/checks"
printf '# Architecture\n' >"$fixture/docs/architecture.md"
printf '{}\n' >"$fixture/schemas/ocr.json"
printf 'code\n' >"$fixture/src/ocr.txt"
cat >"$fixture/checks/verify.sh" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$fixture/checks/verify.sh"
git -C "$fixture" add docs src schemas checks
git -C "$fixture" commit -qm seed
ground=$(git -C "$fixture" rev-parse HEAD)
tree=$(git -C "$fixture" rev-parse 'HEAD^{tree}')

cat >"$fixture/.intent/config.yml" <<'EOF'
version: 1
resolution: assisted
integration_branch: main
EOF
cat >"$fixture/.intent/DOMAINS.yml" <<'EOF'
version: 1
domains:
  - id: ocr
    description: OCR execution responsibilities.
    authority: user:task:test#turn-1
    material: [architecture:docs/architecture.md]
  - id: ocr.orchestrator
    description: Selects engines and distributes work.
    authority: user:task:test#turn-1
    parent: ocr
    material: [architecture:docs/architecture.md]
  - id: ocr.external
    description: Executes OCR through an external provider.
    authority: user:task:test#turn-1
    parent: ocr
EOF
cat >"$fixture/.intent/CONTRACTS.yml" <<'EOF'
version: 1
contracts:
  - id: ocr.engine-protocol.v1
    assertion: Engines accept the shared request and return the shared result.
    authority: user:task:test#turn-1
    between: [ocr.orchestrator, ocr.external]
    surfaces: [interface:OcrEngine, repo:schemas/ocr.json]
    material: [architecture:docs/architecture.md]
    verifies: [command:checks/verify.sh]
EOF
cat >"$fixture/.intent/CONSTRAINTS.yml" <<'EOF'
version: 1
constraints:
  - id: ocr.provider-isolation
    assertion: Provider-specific behavior remains inside an engine domain.
    authority: user:task:test#turn-1
    applies_to: [ocr.orchestrator, ocr.external]
    material: [architecture:docs/architecture.md]
EOF
cat >"$fixture/.intent/audits/ocr.yml" <<EOF
version: 1
id: ocr
ground: $ground
tree: $tree
mode: scope
domains: [ocr.orchestrator]
paths: [src]
findings: []
EOF
cat >"$fixture/.intent/observations/adr-location.yml" <<EOF
version: 1
id: adr-location
ground: $ground
statement: Architecture material currently lives in docs.
evidence: [repo:docs/architecture.md]
relates_to: [domain:ocr]
EOF

ok() { echo "ok - $1"; }
die() { echo "not ok - $1"; exit 1; }
expect_pass() { out=$(cd "$fixture" && sh "$validator" 2>&1) || { printf '%s\n' "$out"; die "$1"; }; ok "$1"; }
expect_fail() { if out=$(cd "$fixture" && sh "$validator" 2>&1); then printf '%s\n' "$out"; die "$1"; fi; ok "$1"; }

expect_pass "domains, executable contracts, semantic constraints, audits, and observations validate"

cp "$fixture/.intent/DOMAINS.yml" "$fixture/.intent/DOMAINS.good"
sed 's/    parent: ocr/    parent: missing/' "$fixture/.intent/DOMAINS.good" >"$fixture/.intent/DOMAINS.yml"
expect_fail "domain parent references are checked without validating filesystem membership"
mv "$fixture/.intent/DOMAINS.good" "$fixture/.intent/DOMAINS.yml"

cp "$fixture/.intent/CONTRACTS.yml" "$fixture/.intent/CONTRACTS.good"
sed '/    verifies:/d' "$fixture/.intent/CONTRACTS.good" >"$fixture/.intent/CONTRACTS.yml"
expect_fail "contracts require executable verification"
mv "$fixture/.intent/CONTRACTS.good" "$fixture/.intent/CONTRACTS.yml"

cp "$fixture/.intent/CONSTRAINTS.yml" "$fixture/.intent/CONSTRAINTS.good"
sed 's/ocr.external/missing/' "$fixture/.intent/CONSTRAINTS.good" >"$fixture/.intent/CONSTRAINTS.yml"
expect_fail "constraint domain references are checked"
mv "$fixture/.intent/CONSTRAINTS.good" "$fixture/.intent/CONSTRAINTS.yml"
expect_pass "constraints remain valid without surfaces or verifiers"

cp "$fixture/.intent/observations/adr-location.yml" "$fixture/.intent/observations/adr-location.good"
sed 's/repo:docs\/architecture.md/repo:docs\/missing.md/' "$fixture/.intent/observations/adr-location.good" >"$fixture/.intent/observations/adr-location.yml"
expect_fail "observation evidence must resolve"
mv "$fixture/.intent/observations/adr-location.good" "$fixture/.intent/observations/adr-location.yml"

cp "$fixture/.intent/audits/ocr.yml" "$fixture/.intent/audits/ocr.good"
sed 's/domains: \[ocr.orchestrator\]/domains: [missing]/' "$fixture/.intent/audits/ocr.good" >"$fixture/.intent/audits/ocr.yml"
expect_fail "audit semantic domain references are checked"
mv "$fixture/.intent/audits/ocr.good" "$fixture/.intent/audits/ocr.yml"

cp "$fixture/.intent/audits/ocr.yml" "$fixture/.intent/audits/ocr.good"
sed 's/paths: \[src\]/paths: [missing]/' "$fixture/.intent/audits/ocr.good" >"$fixture/.intent/audits/ocr.yml"
expect_fail "audit paths must exist in the exact audited tree"
mv "$fixture/.intent/audits/ocr.good" "$fixture/.intent/audits/ocr.yml"

cat >"$fixture/.intent/ROUTES.yml" <<'EOF'
version: 1
routes: []
EOF
expect_fail "tracked routes are no longer accepted governance"
rm "$fixture/.intent/ROUTES.yml"

cat >"$fixture/.intent/config.yml" <<'EOF'
version: 1
resolution: manual
EOF
expect_fail "configuration restricts resolution to assisted or auto"

mkdir -p "$history"
git -C "$history" init -qb main
git -C "$history" config user.name test
git -C "$history" config user.email test@example.com
git -C "$history" config commit.gpgsign false
printf 'seed\n' >"$history/file.txt"
git -C "$history" add file.txt
git -C "$history" commit -qm seed
git -C "$history" commit -q --allow-empty -m "adopt landing history" -m "Intent-Unit: adoption
Intent-Scope: area.root
Intent-Boundary: no-record"
attested=$(git -C "$history" rev-parse HEAD)
printf 'ordinary\n' >>"$history/file.txt"
git -C "$history" commit -qam "ordinary integration edit"
unattested=$(git -C "$history" rev-parse HEAD)
if out=$(cd "$history" && sh "$validator" --landing 2>&1); then
  die "unattested integration suffix passed strict landing validation"
fi
printf '%s\n' "$out" | grep -q '^FAIL unattested integration range .* requires the next landing to carry Intent-Covers$' ||
  die "unattested range lacks a precise diagnostic"
ok "ordinary integration commits remain append-only but visibly unattested"

git -C "$history" commit -q --allow-empty -m "bad range attestation" -m "Intent-Unit: bad
Intent-Scope: area.root
Intent-Boundary: no-record
Intent-Covers: wrong..range"
if out=$(cd "$history" && sh "$validator" --landing 2>&1); then
  die "incorrect range attestation passed validation"
fi
printf '%s\n' "$out" | grep -q 'covers wrong..range but expected' || die "incorrect coverage did not report the expected range"
ok "range attestations must cover the exact first-parent suffix"

git -C "$history" switch -qc correct "$unattested"
git -C "$history" commit -q --allow-empty -m "correct range attestation" -m "Intent-Unit: correct
Intent-Scope: area.root
Intent-Boundary: no-record
Intent-Covers: $attested..$unattested"
(cd "$history" && sh "$validator" --landing >/dev/null) || die "exact contiguous range attestation failed"
ok "exact range attestation restores strict landing validity without rewriting"

echo "13 state validation checks passed"

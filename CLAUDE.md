# CLAUDE.md

## Repository purpose

Invariant combines sparse semantic governance with short-lived planning and prospective-tree Git
landing. Read [SPEC.md](SPEC.md) for the design of record.

## Rules

- Branch isolation and governance adoption are independent decisions.
- Missing governance never initializes state or blocks ordinary work.
- Domains are semantic responsibility indexes with architecture and contract pointers, not
  filesystem boundaries.
- Contracts are relied-on cross-domain promises with executable verification.
- Anchored architecture Markdown is canonical for rationale and non-executable decisions; applicable
  decisions always require semantic review.
- Discoveries and audits are tracked evidence, not authority, and never enter governing digests.
- Pending or causally suspect discoveries warn by default and block only when current work depends
  on the unresolved decision.
- Do not create new constraints or observations. Existing files remain readable for migration.
- Runtime contains only ignored plans and leases shared through the primary worktree.
- Reusable brief receipts are disposable Git-local caches; hashes guard reuse and landing never
  trusts them. An advanced integration head alone does not invalidate a receipt.
- Plans validate DAG, reliance order, checks, and unordered claim disjointness mechanically.
- Leases use Git ancestry and intersection for freshness; time only schedules liveness checks.
- Landing validates the exact prospective tree and compare-and-swaps the target ref.
- Ordinary unattested integration commits are covered append-only by the next landing; history is
  never rewritten merely to add trailers.
- Merge landing may run from any worktree. A checked-out target must have no tracked edits, and
  untracked files must not collide with the candidate.
- Landing requires an explicit durable-boundary disposition; new topology is only a review signal.
- Direct integration edits require explicit `no-record` and are allowed only when exact-tree reach
  is mechanically local.
- Failed landing never moves the target.
- Push and other external effects require explicit request authority.

## Write ownership

| Component | Writes |
|---|---|
| `intent-brief` | nothing |
| `intent-coordinate` | ignored `.intent/runtime/` plans and leases |
| `intent-audit` | tracked `.intent/audits/` and worthwhile non-authoritative discoveries |
| `intent-record` | domains, contracts, canonical architecture, and discovery lifecycle updates |
| `intent-land` | local commits, integration refs, and completed runtime cleanup |

## Configuration

Schema version remains `1`:

```yaml
version: 1
resolution: assisted
integration_branch: main
```

Both fields after `version` are optional. Do not add planning autonomy, worker capability,
question timing, docs roots, push authority, or adoption preference to configuration.

## Verification

Run every shell test:

```bash
for test_file in tests/test-*.sh; do sh "$test_file" || exit; done
```

Use POSIX shell for scripts and test deterministic mechanics rather than policy wording.

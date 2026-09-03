---
name: intent-land
description: Construct, review, verify, and atomically land the exact prospective Git tree while authenticating coordinated leases and preserving accepted contracts and constraints.
---

# intent-land

Landing is one convergence operation. It does not invent governance.

Normal repository work lands from `intent/work/<uuid>` through `merge`; `direct` is only valid for
the first commit on an unborn integration branch. Merge landing may run from any worktree and may
target a branch checked out elsewhere. That target worktree must have no tracked edits; non-colliding
untracked files are preserved. A linked worker worktree is optional, and only coordinated work
requires a plan and leases.

Recompute reach against the exact candidate. Run all emitted contract and constraint verifiers.
Never substitute a cached task brief for this recomputation.
Semantically review every affected constraint against the candidate and pass its
`--reviewed constraint:<id>` acknowledgement. Under `resolution: assisted`, ask only when the
candidate conflicts with or changes accepted meaning; under `auto`, resolve within request
authority. Removing or rewriting accepted governance remains gated.

Use `scripts/land-support.sh direct|merge`. Pass every unit, derived scope, selected semantic
domain, explicitly claimed governance item, repository check, and runtime plan id. Pass exactly one
`--boundary-review`: `no-record`, `audit:<id>`, or `recorded`. `recorded` requires one or more
`--governance` references. The script validates audit freshness and rejects audits with adoptable or
unresolved findings, then preserves the disposition and references as `Intent-Boundary` and
`Intent-Governance` trailers. A coordinated landing must have matching fresh leases; the script
validates their branch, target, and combined path/domain/governance coverage.

If ordinary changes were already staged directly on the integration branch, the optional
`scripts/direct-edit.sh` helper accepts them only with an explicit `--no-record` disposition and
only when its exact staged-tree reach is `local`. It never derives a semantic decision from path
classification. Governed work returns to the normal isolated branch flow.

The script constructs a dangling candidate, validates intent and trailers in a detached worktree,
runs checks against that exact tree, and compare-and-swaps the integration ref. Conflict, failed
verification, missing semantic review, stale or mismatched lease, changed target, or unresolved
governance leaves the ref unchanged.

If ordinary first-parent commits advanced the target after its most recent attested landing, the
next landing adds `Intent-Covers: <last-attested>..<previous-head>`. Reach and verifier selection use
the union of paths touched throughout that range plus the candidate, so reverted semantic touches
remain visible. This is append-only attestation; it never rewrites the intervening commits.

After landing, give a short decision-oriented report: durable meaning changed, governance merely
reviewed, unique checks run, landing or divergence result, and anything intentionally unresolved.
Omit empty categories, use human language before identifiers, and do not replay the complete reach
output. Invalidate the task brief receipt after a successful landing when one was used.

`TOPOLOGY-NEW` output means the candidate introduced a mechanical area or package scope absent from
the integration tree. Treat it as a prompt to recheck durable meaning, never as evidence that the
scope is a semantic domain or requires governance by itself.

Use [references/conflict-resolution.md](references/conflict-resolution.md) for actual Git conflicts.
Local landing follows from an implementation request. Push, deployment, publication, destructive
cleanup, and other external effects require explicit request authority.

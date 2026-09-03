# Invariant — design of record

Invariant maintains sparse accepted architecture over a Git repository, a separate short-lived
planning plane for live work, and an atomic local convergence boundary. Git remains the causal
clock and source of implementation truth.

## 1. Operating boundary

The system answers:

1. Which semantic domains matter to this request?
2. Which accepted architecture decisions and executable promises apply?
3. Is adoption required before dependent work diverges?
4. Can useful independent units run concurrently without claim collision?
5. Does the exact prospective tree preserve accepted meaning and pass verification?

It does not inventory a repository, persist ordinary reasoning, equate paths with domains, or add
ceremony merely because governance is absent.

Repository mutation and governance adoption are independent decisions. Every mutation is isolated
on a work branch even when it needs no durable governance. Conversely, a very small implementation
change can require adoption when it changes meaning that future work must preserve.

## 2. Planes and standing

| Plane | Objects | Lifetime | Standing |
|---|---|---|---|
| Governance | domains, architecture Markdown, contracts | durable | accepted authority |
| Evidence | audits, discoveries | durable | observed, non-authoritative |
| Planning | plans, claims, leases | one active context | coordination only |
| Implementation | Git trees and commits | repository history | causal fact |
| Verification | commands and prospective review | one candidate tree | measured evidence |

Governance and planning may reference the same semantic identifiers but never grant each other
authority. Audits and discoveries can motivate adoption but cannot bind work.

## 3. State

```text
.intent/config.yml
.intent/DOMAINS.yml
.intent/CONTRACTS.yml
.intent/audits/<id>.yml
.intent/discoveries/<id>.yml
.intent/runtime/plans/<id>.yml
.intent/runtime/leases/<unit>.yml
```

Runtime is ignored and anchored in the primary worktree so all linked worktrees see the same live
claims. Deleting it cannot change repository meaning, though it can discard active coordination.

Reusable task brief receipts live outside repository state at:

```text
<git-common-dir>/invariant/briefs/<task-id>.yml
```

They are derived caches, not another plane of authority or coordination. A receipt binds its goal,
integration target and head, selected scope, governance digest, and brief and landing package hashes.
It permits reuse of material already retained in the active context; it does not make that material
authoritative and is discarded or rebuilt when any binding input changes.

## 4. Configuration

```yaml
version: 1
resolution: assisted
integration_branch: main
```

Both fields after `version` are optional. Absence means `resolution: assisted` and the branch
current at goal intake.

- `assisted` lets the agent plan and implement normally but sends consequential unresolved
  architecture, compatibility, side-effect, or governance changes to the human.
- `auto` lets the agent resolve those choices within the current request and accepted authority.

Neither mode authorizes incompatible explicit goals, security or money effects, production data,
irreversibility, push, deployment, publication, or other external mutations without exact request
authority. Planning policy, worker availability, and documentation roots are runtime or repository
facts, not configuration.

## 5. Addressing and domains

Every ordinary path has a mechanically derived coordination scope:

- visible top-level directories become `area.<slug>`;
- declared package roots may add `pkg.<slug>`;
- root files and hidden top-level paths belong to `area.root`;
- `.intent/` is outside implementation scope claims.

Derived scopes organize claims and validate commit trailers. They carry no semantics or authority.

There is no tracked path-to-domain route record. Domains are thin semantic routing indexes: they
state responsibility and point to architecture decisions and contracts. These pointers establish
relevance, not truth; the referenced Markdown remains canonical and must still be compared with
current evidence.

A domain is a coherent cluster of responsibility, behavior, and change. It need not be a service,
directory, bounded context, or public interface. Domain selection is semantic model work based on
the request, implementation, discoveries, and architecture material.

```yaml
version: 1
domains:
  - id: ocr.orchestrator
    responsibility: Selects OCR engines and distributes work.
    authority: user:task:ocr-architecture#turn-4
    parent: ocr
    architecture: [architecture:docs/architecture.md#ocr-orchestration]
    contracts: [ocr.engine-protocol.v1]
```

Validation checks identifiers, authority, architecture anchors, contract pointers, parent
references, and cycles. It never tries to prove domain membership from paths. The reverse map from
decisions and contracts to domains is derived rather than maintained as another authority layer.

## 6. Contracts

A contract is an accepted durable promise on which another semantic domain relies.

```yaml
version: 1
contracts:
  - id: ocr.engine-protocol.v1
    assertion: Every engine accepts OcrRequest and returns OcrResult.
    authority: user:task:ocr-architecture#turn-4
    between: [ocr.orchestrator, ocr.engine.external]
    surfaces: [interface:OcrEngine, repo:schemas/ocr-engine.json]
    architecture: [architecture:docs/architecture.md#ocr-engine-protocol]
    verifies: [command:scripts/verify-ocr-engine-protocol]
```

Admission requires accepted authority, at least two domains, identifiable surfaces, referenced
architecture, real reliance, and executable verification. API, event, job, schema, and configuration
contracts use the same shape; their verifier owns format-specific mechanics.

## 7. Architecture decisions

Architecture Markdown is the canonical home for interdomain structure, rationale, philosophy,
critical technology choices, consequences, and revision criteria. A stable heading anchor is the
decision identity used by domains, contracts, reviews, and landing attestations.

```markdown
## OCR engine isolation

Provider-specific behavior remains inside its engine domain because orchestration must stay
provider-neutral. Revisit this if engines no longer share lifecycle or replacement semantics.
```

A critical library belongs here only when the technology choice itself is intentional architecture
with rationale, consequences, compatibility concerns, and replacement conditions. Incidental
dependencies remain implementation detail.

Landing semantically reviews every applicable architecture pointer against the exact candidate and
records it as `Intent-Architecture`. Contracts carry executable checks; architecture remains the
source of non-executable architectural meaning. A separate authoritative constraint registry would
duplicate that meaning, so new constraints are not created. Existing `CONSTRAINTS.yml` files remain
binding and readable only while repositories migrate their assertions into anchored architecture.

## 8. Audits and discoveries

Architecture may live anywhere in the repository, but accepted pointers name exact Markdown
sections. A global docs folder is neither configured nor assumed.

Prefer focused design material over making a shared onboarding README an architecture hub. When a
Markdown section is intentionally authoritative, its locator includes the heading anchor. Actual
changed hunks are routed only to the section containing them; when no diff is available or an anchor
cannot be resolved, matching remains conservatively file-wide. Interface locators remain the
preferred mechanical route for a changed relied-on surface, while domain selection remains semantic.

An audit is a tracked report over a declared commit and exact tree. It contains scope, evidence,
bounded findings, and whether record, authority, verifier work, or no action follows. Audit is
non-authoritative even though it is committed.

```yaml
version: 1
id: audit-2026-09-02-ocr
ground: 8a3e7d2
tree: e1c52f0
mode: scope
domains: [ocr.orchestrator, ocr.engine.external]
paths: [src/ocr, schemas/ocr.json]
findings:
  - id: engine-boundary
    summary: Both engines already depend on a shared request and result shape.
    evidence: [repo:schemas/ocr.json, interface:OcrEngine]
    proposed: contract
    disposition: adoptable
    authority: user:task:ocr-architecture#turn-4
```

`proposed` is `domain`, `contract`, `architecture`, `discovery`, or `none`. `disposition` is
`adoptable`, `needs-authority`, `needs-verifier`, `discovery-only`, or `no-action`. Finding ids
are stable handles within the audit; adoption may name one when several findings exist, but the
normal in-context flow is simply `intent-record adopt`.

A discovery is a tracked, non-authoritative queue item for evidence that may become responsibility,
architecture, or a contract. It is created only when preserving the unresolved evidence will help
future work; ordinary findings remain in the current task or audit.

```yaml
version: 1
id: ocr-provider-layout
status: pending
ground: 8a3e7d2
tree: e1c52f0
domains: [ocr.engine.external]
statement: Provider implementations currently live below src/ocr/providers.
evidence: [repo:src/ocr/providers]
candidates: [architecture]
```

The lifecycle is `pending → promoted | dismissed | superseded | stale`. Promotion atomically updates
the architecture, contract, or domain pointers and records those targets in `resolution`. Dismissed
and stale discoveries record a reason; superseded discoveries point to their replacement. Pending
discoveries appear in relevant briefs as warnings. Evidence changes after the recorded tree produce
`needs-review`, but neither pending nor suspect discoveries change reach or block landing by
themselves. They become blocking only when semantic review determines that the current work depends
on the unresolved decision.

Freshness is causal: broken files, anchors, and identifiers are structural failures; intersecting
changes make evidence suspect; actual contradiction requires interpretation. Legacy
`observations/` files remain readable during migration but new evidence enters `discoveries/`.

## 9. Adoption

Adoption is promotion, not seeding or inventory.

At briefing and again against the prospective tree, ask:

> Could a future change be locally reasonable but systemically wrong unless it knew and preserved
> this decision?

The answer is yes when current work creates or changes a responsibility that needs stable identity;
a relied-on interface, schema, wire, configuration, or storage promise; the owner of authoritative
state; persistence, transaction, consistency, failure, recovery, or migration behavior; rollout or
compatibility ordering; or an architectural restriction on future implementations. Change size and
path layout do not decide this question.

Behavior-preserving implementation substitutions, local refactors, tests, documentation, and
one-consumer details need no new record when every existing promise and operational property remains
unchanged. When durable meaning already has an accepted owner, amend the existing record rather than
creating a parallel one.

```text
brief current work
  → durable-meaning test is negative: record no-record disposition, implement, and land
  → durable meaning and authority are explicit: record minimal governance, re-brief, implement
  → durable meaning is uncertain: scoped audit
      → no record needed: record audit disposition, implement, and land
      → authority or verifier missing: resolve bounded issue before dependent work diverges
      → accepted: promote into architecture, a domain, or a contract; re-brief and implement
```

`intent-audit` writes tracked evidence and queues only discoveries worth carrying forward.
`intent-record` promotes accepted meaning into domains, architecture Markdown, and contracts, and
closes the originating discovery in the same change. A full audit requires an explicit human request
and uses `--assisted` or `--auto` only after that authorization.

Choose the artifact from the meaning, not the technology: a domain gives a responsibility stable
identity and retrieval boundary; architecture Markdown preserves rationale and permitted shape; a
contract protects an executable promise relied on by another domain; and a discovery preserves
unresolved evidence without binding work. A missing contract verifier is a
`VERIFIER REQUIRED` result, not permission to silently omit the contract.

## 10. Briefing

A brief selects semantic domains, then compiles their responsibilities, architecture pointers,
contracts, relevant pending discoveries, and live claims. Contracts may also be reached mechanically
through declared surfaces. Domain selection remains semantic.

Reach is:

- `local` — no accepted binding record intersects;
- `bounded` — applicable architecture or contracts remain unchanged;
- `open` — architecture, verification, or additive governance changes;
- `gated` — accepted governance is removed or rewritten.

The digest covers only selected domain and contract metadata, including their architecture pointers.
Discovery content, audits, configuration, worker availability, Git ancestry, and runtime never enter
it. Referenced architecture content is checked causally and independently rather than copied into
the registry.

After compiling a brief, the agent may write a disposable per-task receipt to Git's shared
administrative directory. Reuse requires the same repository identity, goal digest, integration
target, brief and landing package hashes, selected governance digest, and no expansion of paths,
interfaces, or domains. An advanced integration head is adopted into the receipt when the cached
head remains its ancestor, selected governance and defining material are unchanged, and the task tip
still merges cleanly. A governing change is semantically stale; a content conflict is reported as a
merge problem, not disguised as semantic invalidation. Context compaction still requires reloading
the relevant instructions because the receipt proves freshness, not model retention. Landing ignores
the cache and independently recomputes reach from the exact candidate tree.

## 11. Work branches, parallel planning, and leases

After read-only briefing and before the first repository mutation, create a generated work branch
from the captured integration head. The normal namespace is `intent/work/<uuid>`; names carry no
semantic authority, so feature-versus-fix classification is unnecessary. Governance, documentation,
fixes, refactors, and features all follow the same rule. A linked worktree is recommended for keeping
the integration worktree clean but is not required for an uncoordinated unit. A lease remains specific
to coordinated work.

An uncoordinated work branch may be reused only for the same active goal while its worktree is clean,
its causal base remains an ancestor of the integration head, and it still merges cleanly. Another
integration commit does not alone require a replacement branch or semantic restart. A changed goal,
expanded semantic scope, changed governing meaning, or real content conflict does require attention.
This is causal continuity, not UI-session identity.

One prompt may contain several outcomes. The model decomposes them into units; tooling validates:

- an existing captured target and causal integration ground;
- selected semantic domains and their exact governing digest;
- an acyclic dependency graph;
- meaningful verification for every unit;
- provider-before-consumer `provides` and `relies_on` edges;
- disjoint unordered path, interface, and governance claims.

Sharing a domain does not by itself cause a collision. Plans contain no progress fields. Landed
state derives from first-parent `Intent-Unit` trailers, active from leases, and readiness from the
dependency graph.

A lease records unit, owner, branch, worktree, task, paths, interfaces, claimed governance,
selected domains, governing digest, integration target and ground, causal tip, and expiry. Landings
that intersect path, interface, or governance claims make it stale. Expiry only schedules a
liveness check; ancestry, ref/worktree existence, and tip movement determine dead, renewing, or
quiescent state.

## 12. Prospective landing

Landing may start from any worktree. It captures the integration head, constructs a direct or merge
candidate without moving the target, and checks it out detached. A target checked out elsewhere must
have no tracked changes; non-colliding untracked files are preserved and the checked-out target is
synchronized only after the ref compare-and-swap succeeds. Against that exact tree landing:

1. recomputes semantic reach from actual paths and selected domains;
2. reports newly introduced mechanical topology as a review signal, never as inferred governance;
3. requires an explicit boundary disposition: `no-record`, a fresh scoped audit that concludes no
   adoption, or accepted governance references;
4. resolves open or gated authority;
5. validates all tracked intent;
6. validates derived scope and semantic domain trailers;
7. runs affected contract verifiers plus repository checks;
8. requires acknowledgement of every affected architecture review and records it as
   `Intent-Architecture`;
9. authenticates coordinated leases and their combined claims;
10. compare-and-swaps the integration ref from the captured head;
11. releases landed leases and removes a completed plan.

Normal landing merges a work branch. Direct landing is permitted only to create the first commit on
an unborn integration branch, where no branch can yet be based on a commit. A naked acknowledgement
is not a boundary disposition: the caller must state that the durable-meaning test was negative,
identify the concluding audit, or name the accepted governance that owns the meaning. Landing
preserves that result in `Intent-Boundary` and `Intent-Governance` commit trailers.
The oldest first-parent commit carrying `Intent-Boundary` is the integration history's adoption
anchor. Ordinary first-parent commits after an attested landing may form a temporarily unattested
suffix. The next landing closes it with
`Intent-Covers: <last-attested>..<previous-integration-head>` and applies its explicit boundary
disposition to that range. Reach and verifier discovery use the union of every path touched by those
first-parent commits plus the candidate, not merely the net tree diff, so a reverted architectural
touch cannot disappear. A strict landing-history check rejects an uncovered tip or a malformed or
non-contiguous range. This is append-only accountability: earlier commits are never rewritten merely
to add trailers, and history before the adoption anchor remains outside the invariant.

For a small edit already staged on the integration branch, the optional direct-edit helper builds
and checks an exact staged-tree candidate. It requires the caller to state `--no-record`; local reach
is a mechanical eligibility check and never the source of that semantic decision. Only `local`
changes can use the helper. Bounded, open, or gated work uses the normal isolated work branch.

Any failure before the ref update leaves the target unchanged. If another landing wins the race,
compare-and-swap fails rather than overwriting it.

## 13. Mechanical and semantic ownership

Mechanics owns schemas, pointer and anchor integrity, derived scopes, plan DAGs, reliance order,
claim overlap, causal freshness, governing digests, discovery warning selection, affected verifier
selection, exact-tree construction, trailer checks, boundary-disposition shape and references, lease
authentication, and atomic ref updates.

Model judgment owns outcome decomposition, domain selection, distinguishing architecture from
contracts and incidental implementation, interpreting discovery evidence, authoring accepted
meaning, reviewing architecture compliance, the durable-meaning decision, and resolving
incompatible meaning under configured authority.

The governing rule remains: isolate every mutation, then use the smallest governance and
coordination lifecycle that safely completes the request.

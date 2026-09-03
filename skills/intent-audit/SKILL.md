---
name: intent-audit
description: Inspect a task scope or explicitly requested repository for missing, stale, or conflicting domains, architecture, contracts, and discoveries, then write bounded non-authoritative evidence.
---

# intent-audit

Audit writes `.intent/audits/<id>.yml` and may queue a worthwhile unresolved finding in
`.intent/discoveries/<id>.yml`; neither grants authority or changes accepted governance. Do not
create a discovery for facts that can be resolved or discarded in the current task. Use a scoped
audit when the durable meaning exposed by current work is
uncertain or the user requests discovery. Clear accepted meaning may proceed directly to
`intent-record`; do not manufacture an audit merely to add a record. A full audit requires an
explicit repository-wide request.

Run `scripts/audit-support.sh scope --paths ...`, or after full-audit authorization run
`full --assisted|--auto`. Read [references/discovery.md](references/discovery.md) for scoped work,
[references/full-audit.md](references/full-audit.md) for full work, and
[references/orientation.md](references/orientation.md) only in an unfamiliar repository.

Write the inspected `ground` commit and exact `tree`, semantic scope, paths, evidence, and bounded
findings. Classify each finding for the reader as adoptable, needing authority, needing a verifier,
discovery-only, or no action. Existing implementation and history are evidence, never normative
authority.

End the user-facing result with a short closeout: group findings by what is ready, what needs a
decision or verifier, and what needs no action; recommend one next step; and say what follows from
it. Lead with plain-language meaning and put finding or governance ids in parentheses. When human
authority is required, ask one direct question that contrasts the concrete behaviors and recommends
one of them. Do not leave the user with only a command or transition label.

Finish with exactly one existing transition:

- `NO RECORD NEEDED`;
- `RECORD READY — intent-record adopt`;
- `RESOLUTION REQUIRED`;
- `VERIFIER REQUIRED`.

`NO RECORD NEEDED` means future work remains correct without preserving a new responsibility,
relied-on promise, authoritative-state choice, operational property, or architecture decision.
It is a conclusive boundary disposition, not a synonym for missing governance.

`scripts/audit-support.sh fresh <audit>` derives freshness from ancestry and intersecting evidence,
never timestamps. Accepted findings and promoted discoveries flow naturally to `intent-record`; no
`candidate` selector is required for the current audit context.

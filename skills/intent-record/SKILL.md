---
name: intent-record
description: Promote, amend, or retire accepted domain responsibilities, architecture decisions, and executable cross-domain contracts. Use after a discovery, audit finding, or complete direct instruction has authority.
---

# intent-record

Record is the governance promotion transaction. It consumes the current accepted discovery or audit
finding by default; name an id only when resuming or selecting part of a larger audit.

```text
intent-record adopt
intent-record adopt --audit <id>
intent-record adopt --audit <id> --finding <id>
intent-record adopt --discovery <id>
intent-record amend
intent-record retire
```

## Write protocol

1. Recheck the audit's causal freshness when one is used.
2. Resolve authority according to `resolution: assisted | auto` and the request's hard limits.
3. Create or update the canonical anchored architecture section when the accepted meaning is not
   already explicit.
4. Change only the smallest domain responsibility/pointers or contract metadata needed for routing
   and executable protection.
5. When promoting a discovery, set it to `promoted` with `resolution` pointers in this same change.
6. Run `../intent-brief/scripts/validate-state.sh`, every affected contract verifier, and semantic
   review of the affected architecture.
7. Recompile the brief before dependent units diverge. Leave changes unstaged unless the invoking
   task owns landing.

Domains are semantic responsibility and retrieval indexes. Do not add filesystem membership merely
to make them discoverable. Architecture Markdown owns rationale and non-executable decisions. A
contract is a relied-on promise between at least two domains and requires executable evidence.

Do not create new constraint or observation records. Existing files remain readable while their
meaning is migrated into anchored architecture or lifecycle discoveries. A discovery is a queue for
unresolved evidence, not a second source of accepted architecture.

Prefer amending the record that already owns a responsibility or promise. Create a new record only
when the durable meaning cannot be expressed coherently by an existing one. Record operational
meaning rather than incidental technology: for example, authoritative durable state, restart
survival, transactionality, recovery, or migration compatibility rather than merely "uses
PostgreSQL."

Treat accepted ids and architecture anchors as stable keys. Name domains with stable responsibility
nouns and contracts after the relied-on surface, including a version when compatibility identity
matters. Name architecture headings for the decision or ownership boundary they preserve.
Rename an accepted id only as an explicit governance migration, never as cosmetic cleanup; update
all live references and preserve the old name in defining material because commit history is
immutable.

For incompatible concurrent governance edits, read
[references/reconciliation.md](references/reconciliation.md).

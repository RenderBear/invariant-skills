# Invariant — preserve accepted meaning across agentic change

Invariant keeps architectural meaning durable while agents and people change a repository together.

- **Governed autonomy:** Accepted responsibilities, contracts, and architecture decisions travel with
  the repository and are verified where possible.
- **Progressive discovery:** Ordinary work stays ordinary; audits and governance appear only when
  durable meaning needs to be discovered or preserved.
- **Causal coordination:** Git ancestry orders work, disposable leases coordinate it, and exact-tree
  landing converges it atomically.

![A read-only brief leads to an isolated work branch, an exact candidate tree, and verification against that tree before a compare-and-swap advances the integration ref. Tracked governance sits inside Git and feeds both the brief and verification; the ignored planning runtime sits outside it.](.github/assets/lifecycle.svg)

The complete model is documented in [SPEC.md](SPEC.md).

The `.intent/` state directory, `intent-*` skill names, and `Intent-*` commit trailers remain stable
protocol names under the Invariant framework.

## Install

Install from the current source repository:

```bash
npx skills add RenderBear/git-intent --all
```

Copy the fenced block from [AGENTS.example.md](AGENTS.example.md) into the repository's
always-loaded agent instructions.

## Full audit in a mature repo (optional)

Ordinary work does not require repository-wide setup. When inheriting an existing repository or
wanting a deliberate architecture review, run:

```text
/intent-audit full
```

The audit records causal evidence without making it authoritative. Its closeout tells you exactly
what to do next:

- `NO RECORD NEEDED` — continue normal work; no governance adoption is required.
- `RECORD READY` — run `/intent-record adopt` to record the recommended responsibility, promise, or
  architecture decision.
- `RESOLUTION REQUIRED` — answer the single behavior question before adoption.
- `VERIFIER REQUIRED` — implement the named executable check before recording the contract.

Use auto mode only when the current request already gives the agent authority to resolve
consequential ambiguity.

## Skills

| Skill | Responsibility |
|---|---|
| `intent-brief` | Select semantic domains and compile applicable governance and live claims. |
| `intent-coordinate` | Validate parallel plans and manage causal leases. |
| `intent-audit` | Discover evidence and queue worthwhile unresolved discoveries. |
| `intent-record` | Promote discoveries into domains, architecture, or contracts. |
| `intent-land` | Review and verify a prospective tree, then atomically converge it. |

## Configuration

Configuration is optional:

```yaml
version: 1
resolution: assisted
integration_branch: main
```

`resolution` controls who resolves consequential architectural ambiguity:

| Mode | Behavior |
|---|---|
| `assisted` | The agent handles routine work within recorded intent, but asks the user before resolving an ambiguous architectural change, compatibility promise, or consequential side effect. |
| `auto` | The agent may resolve those questions itself when the current request and recorded authority provide enough evidence. It still reports the resolution and records durable consequences when needed. |

Both modes enforce recorded contracts and referenced architecture. Neither mode grants permission to contradict
explicit requirements or perform external actions such as pushing, deploying, publishing, or
destructive cleanup.

`integration_branch` optionally fixes the local convergence target. Without it, Invariant captures
the current branch when work begins.

## Repository state

```text
.intent/config.yml             optional resolution and integration target
.intent/DOMAINS.yml            responsibilities plus architecture/contract pointers
.intent/CONTRACTS.yml          accepted executable cross-domain promises
.intent/discoveries/<id>.yml   tracked non-authoritative discovery queue
.intent/audits/<id>.yml        tracked non-authoritative audit evidence
.intent/runtime/plans/         ignored active coordination graphs
.intent/runtime/leases/        ignored live ownership claims
```

Architecture prose is canonical in anchored Markdown sections. Domains establish relevance by
pointing to those decisions and to contracts; pointers do not make a document true. Pending
discoveries are visible warnings, not governance. 

Runtime is shared by linked worktrees through the primary worktree. It may be removed without
changing repository meaning, although doing so discards active coordination state.

Repeated turns may reuse a hash-validated brief receipt stored under Git's shared administrative
directory at `<git-common-dir>/invariant/briefs/`. The receipt contains no authority and never
replaces reach recomputation or exact-tree verification at landing. An unrelated, mergeable advance
of the integration branch refreshes the receipt in place; changed governing material, expanded
semantic scope, or a real merge conflict requires attention.



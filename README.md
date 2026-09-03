# Invariant — Durable intent and causal coordination for agentic work

Invariant uses Git's own mechanics to keep accepted architectural meaning durable, active coordination disposable, and both progressively informed by the repository itself.

- **Governance:** Stable responsibilities, relied-on promises, and architectural limits are discovered progressively, accepted explicitly, tracked with the repository, and verified mechanically where possible.
- **Coordination:** Plans, claims, and leases coordinate active branch work locally, then may disappear after the work safely converges.

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

## Optional full audit

Ordinary work does not require repository-wide setup. When inheriting an existing repository or
wanting a deliberate architecture review, run:

```text
/intent-audit full
```

The audit records causal evidence without making it authoritative. Its closeout tells you exactly
what to do next:

- `NO RECORD NEEDED` — continue normal work; no governance adoption is required.
- `RECORD READY` — run `/intent-record adopt` to record the recommended responsibility, promise, or
  constraint.
- `RESOLUTION REQUIRED` — answer the single behavior question before adoption.
- `VERIFIER REQUIRED` — implement the named executable check before recording the contract.

Use auto mode only when the current request already gives the agent authority to resolve
consequential ambiguity.

## Skills

| Skill | Responsibility |
|---|---|
| `intent-brief` | Select semantic domains and compile applicable governance and live claims. |
| `intent-coordinate` | Validate parallel plans and manage causal leases. |
| `intent-audit` | Discover and persist non-authoritative findings. |
| `intent-record` | Adopt accepted domains, contracts, constraints, and defining material. |
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

Both modes enforce recorded contracts and constraints. Neither mode grants permission to contradict
explicit requirements or perform external actions such as pushing, deploying, publishing, or
destructive cleanup.

`integration_branch` optionally fixes the local convergence target. Without it, Invariant captures
the current branch when work begins.

## Repository state

```text
.intent/config.yml             optional resolution and integration target
.intent/DOMAINS.yml            accepted semantic responsibilities
.intent/CONTRACTS.yml          accepted cross-domain promises
.intent/CONSTRAINTS.yml        accepted architectural constraints
.intent/audits/<id>.yml        tracked non-authoritative audit evidence
.intent/observations/<id>.yml  tracked non-authoritative facts
.intent/runtime/plans/         ignored active coordination graphs
.intent/runtime/leases/        ignored live ownership claims
```

Runtime is shared by linked worktrees through the primary worktree. It may be removed without
changing repository meaning, although doing so discards active coordination state.

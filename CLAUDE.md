# CLAUDE.md

## Repository purpose

Read [SPEC.md](SPEC.md) for the design of record.

## Critical rules

- **Never push to the remote.** No `git push` under any circumstances. Committing locally is fine; publishing is the user's decision.

## Verification

Run every shell test:

```bash
for test_file in tests/test-*.sh; do sh "$test_file" || exit; done
```

Use POSIX shell for scripts and test deterministic mechanics rather than policy wording.

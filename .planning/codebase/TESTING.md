# Testing Patterns

**Analysis Date:** 2026-04-14

## Test Framework

**Runner:**
- Not detected.
- Config: Not detected (`jest`, `vitest`, `bats`, and CI workflow files are not present).

**Assertion Library:**
- Not detected.

**Run Commands:**
```bash
bash -n setup.sh cleanup.sh scripts/*.sh      # Syntax check for all shell scripts
./cleanup.sh --dry-run                         # Safe functional simulation of cleanup flow
bash -x ./setup.sh                             # Trace installer execution (use in disposable environment)
```

## Test File Organization

**Location:**
- No automated test directory detected.

**Naming:**
- No `*.test.sh` or `*.spec.sh` files detected.

**Structure:**
```
No formal test tree exists in the repository.
```

## Test Structure

**Suite Organization:**
```bash
# Current verification is script-driven, not suite-driven.
# Representative manual checks:
bash -n cleanup.sh
./cleanup.sh --dry-run
```

**Patterns:**
- Setup pattern: Source shared helpers and user variables before actions (`scripts/utils.sh`, `scripts/user.sh`).
- Teardown pattern: Cleanup is executed by `setup.sh` and `cleanup.sh` directly, not by tests.
- Assertion pattern: Human-readable terminal output and exit status are used as validation.

## Mocking

**Framework:** Not used.

**Patterns:**
```bash
# Not implemented. Validation currently relies on dry-run and command presence checks.
```

**What to Mock:**
- For future tests, mock external commands with side effects: `sudo`, `apt`, `git clone`, `curl`, `ssh-keygen`, `journalctl`.

**What NOT to Mock:**
- Pure shell helpers (`human_size`, argument parsing) should be tested directly when extracted to deterministic functions.

## Fixtures and Factories

**Test Data:**
```bash
# Not implemented. No fixture directories or factory scripts detected.
```

**Location:**
- Not applicable.

## Coverage

**Requirements:**
- None enforced.

**View Coverage:**
```bash
# Not available; no coverage tooling configured.
```

## Test Types

**Unit Tests:**
- Not present.

**Integration Tests:**
- Not present as automated suites.
- Manual integration behavior is implicit in `setup.sh` orchestration and `cleanup.sh` live execution.

**E2E Tests:**
- Not used.

## Common Patterns

**Async Testing:**
```bash
# Not applicable; no async test framework in use.
```

**Error Testing:**
```bash
# Current manual pattern:
# 1) Run with invalid flag and expect usage output.
./cleanup.sh --unknown

# 2) Run dry-run and confirm no removals are executed.
./cleanup.sh --dry-run
```

## Verification Coverage Summary

- Covered manually: argument parsing and dry-run reporting in `cleanup.sh`.
- Covered indirectly: setup flow ordering in `setup.sh` and sourced script execution.
- Not covered automatically: idempotency of installers, failure paths for network/package manager commands, and SSH/GPG generation flows in `scripts/ssh.sh` and `scripts/gpg.sh`.

## Actionable Baseline To Add

- Add a lightweight shell test harness with `bats` for `cleanup.sh` function behavior and flag parsing.
- Add static checks in a CI workflow: `shellcheck` + `bash -n` for `setup.sh`, `cleanup.sh`, and `scripts/*.sh`.
- Add a non-destructive smoke command in CI: `./cleanup.sh --dry-run`.
- Add fixture-based tests for parsing helpers and size-format conversion in `cleanup.sh`.

---

*Testing analysis: 2026-04-14*

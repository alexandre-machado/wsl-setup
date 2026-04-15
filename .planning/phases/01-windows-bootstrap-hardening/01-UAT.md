---
status: testing
phase: 01-windows-bootstrap-hardening
source: [ROADMAP.md success criteria fallback]
started: 2026-04-15T01:22:10Z
updated: 2026-04-15T01:22:10Z
---

## Current Test

number: 1
name: Preflight State Is Shown Before Destructive Action
expected: |
  When bootstrap starts on a machine with existing WSL state, it should show detected state
  and available paths before any uninstall/reset command is eligible to run.
awaiting: user response

## Tests

### 1. Preflight State Is Shown Before Destructive Action
expected: When bootstrap starts on a machine with existing WSL state, it should show detected state and available paths before any uninstall/reset command is eligible to run.
result: [pending]

### 2. Replace Path Requires Explicit Confirmation
expected: Destructive replace path should ask for explicit Y/N confirmation and must not run unregister/reset unless confirmation is Y.
result: [pending]

### 3. Declining Replacement Continues Non-Destructively
expected: If replace confirmation is declined, bootstrap should continue using a non-destructive path and not unregister an existing distro.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps

[]

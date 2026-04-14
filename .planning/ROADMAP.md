# Roadmap: WSL Setup Revamp

## Overview

This milestone roadmap delivers a safer and simpler Windows-first setup experience by hardening the bootstrap entrypoint, making Linux setup reruns converge safely, and documenting the fastest successful path for new users.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Windows Bootstrap Hardening** - Add non-destructive state detection and confirmation gates before reset actions.
- [ ] **Phase 2: Script Consolidation and Dependency Refresh** - Make reruns idempotent and set Node to a supported LTS default.
- [ ] **Phase 3: Documentation and Recovery Validation** - Publish a Windows-first guide where the fastest successful path is unmistakable.

## Phase Details

### Phase 1: Windows Bootstrap Hardening
**Goal**: Users can safely start setup from Windows without accidental destructive actions.
**Depends on**: Nothing (first phase)
**Requirements**: BOOT-01, BOOT-02
**Success Criteria** (what must be TRUE):
  1. When the bootstrap starts on a machine with existing WSL state, the user is shown the detected state before any uninstall or reset action is available.
  2. Any uninstall or reset path requires an explicit user confirmation step before execution.
  3. A user who does not confirm a destructive option can continue with a non-destructive setup path.
**Plans**: TBD

### Phase 2: Script Consolidation and Dependency Refresh
**Goal**: Users can rerun setup safely and receive a current Node LTS default without cleanup work.
**Depends on**: Phase 1
**Requirements**: SAFE-01, DEPS-01
**Success Criteria** (what must be TRUE):
  1. Rerunning setup does not create duplicate side effects in shell configuration or module-managed state.
  2. After setup, Node is installed through NVM and defaults to a currently supported LTS release.
  3. A user can rerun setup after an interrupted or partial run and finish successfully without manual rollback steps.
**Plans**: TBD

### Phase 3: Documentation and Recovery Validation
**Goal**: New Windows users can identify and complete the fastest successful setup path from documentation alone.
**Depends on**: Phase 2
**Requirements**: DOCS-01
**Success Criteria** (what must be TRUE):
  1. The Windows-first install guide presents one clearly labeled primary path that users can follow end-to-end.
  2. Required steps are clearly separated from optional steps so users can complete the fastest successful setup without guesswork.
  3. A first-time user can complete setup using the Windows-first guide without needing to stitch instructions from multiple documents.
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Windows Bootstrap Hardening | 0/TBD | Not started | - |
| 2. Script Consolidation and Dependency Refresh | 0/TBD | Not started | - |
| 3. Documentation and Recovery Validation | 0/TBD | Not started | - |

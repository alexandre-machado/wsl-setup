# Requirements: WSL Setup Revamp v1.1

**Defined:** 2026-04-14
**Core Value:** A Windows user should be able to run one guided path and end with a working, modern WSL developer environment with minimal manual fixes.

## v1 Requirements

### Windows Bootstrap

- [ ] **BOOT-01**: Windows bootstrap detects existing WSL/install state before any destructive action.
- [ ] **BOOT-02**: Windows bootstrap requires explicit confirmation before uninstall/reset operations.

### Dependencies

- [ ] **DEPS-01**: Node setup defaults to a current supported LTS release through NVM.

### Setup Safety

- [ ] **SAFE-01**: Setup modules can be rerun without duplicate side effects.

### Documentation

- [ ] **DOCS-01**: Windows-first installation docs make the fastest successful setup path obvious.

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Windows Bootstrap

- **BOOT-03**: Windows bootstrap supports automatic recovery from interrupted setup runs.

### Dependencies

- **DEPS-02**: Refresh Windows-side bootstrap dependencies and package sources where needed.
- **DEPS-03**: Remove legacy Node/Yarn installation paths if they are no longer required.

### Setup Safety

- **SAFE-02**: Setup failures are categorized and surfaced with actionable recovery guidance.
- **SAFE-03**: Optional SSH and GPG steps are clearly separated from the main path.

### Documentation

- **DOCS-02**: Recovery and rerun behavior is documented for repeat installations.
- **DOCS-03**: Cleanup and maintenance guidance is updated for the new bootstrap flow.

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| GUI installer | Not needed for the shell-first Windows onboarding flow |
| Multi-distro support | Current project supports Debian/Ubuntu-based WSL only |
| Shell rewrite in another language | Unnecessary for this milestone and adds migration risk |
| Forced WSL uninstall on rerun | Contradicts the safer Windows-first flow |
| Mandatory SSH/GPG setup | Optional setup should remain user-driven |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BOOT-01 | Phase 1 | Pending |
| BOOT-02 | Phase 1 | Pending |
| SAFE-01 | Phase 2 | Pending |
| DEPS-01 | Phase 2 | Pending |
| DOCS-01 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 5 total
- Mapped to phases: 5
- Unmapped: 0 ⚠️

---
*Requirements defined: 2026-04-14*
*Last updated: 2026-04-14 after milestone scoping*

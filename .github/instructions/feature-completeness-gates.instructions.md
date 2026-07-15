---
description: "Quality gates for feature completeness. Use when: verifying a new feature or bugfix is truly done, pre-commit review, checking CRUD parity (create vs edit), state cleanup, domain isolation, side-effect impact, acceptance criteria verification, regression checks."
applyTo:
  - "lib/**/*.dart"
  - "test/**/*.dart"
---

# Feature Completeness Gates

Six mandatory quality gates. Apply in order before marking any feature or fix as complete. A task is **not done** until all 6 gates pass.

## Gate 1: CRUD Parity (Create/Edit Equality)

**Rule:** For any data model, every field and operation available in the Create screen must also exist in the Edit screen — unless explicitly stated otherwise.

- Prefer shared components over duplicated create/edit code.
- When adding a new field/feature, update both create and edit modes simultaneously.
- Before marking done, ask: "This works in create mode. Does it also work in edit mode?"

**Checklist:**
- [ ] All form fields present in create mode are present in edit mode
- [ ] All operations (add, delete, edit, upload/remove) work in both modes
- [ ] Validation rules are identical in both modes

## Gate 2: State Cleanup

**Rule:** When leaving a screen/menu, all temporary state (warning messages, form data, selected items, error text) must be reset. No leftover state carries over.

- Each screen/component manages its own local state; avoid unnecessary writes to global/shared state.
- When a component unmounts or the menu changes, related state must be reset.
- Dismissal of a message/warning must clear the underlying state/flag, not just the visible element.

**Checklist:**
- [ ] Warning messages clear when leaving the menu
- [ ] Form data resets on screen exit
- [ ] Selected items/selections reset on navigation
- [ ] Error text clears on re-entry
- [ ] No stale data from previous screen appears

## Gate 3: Data/Domain Isolation

**Rule:** Data belonging to different domains must be clearly separated and must not mix in shared/global variables.

- Each domain has its own state/store/API calls.
- When a process completes, results must be presented separately, without mixing.
- If menus are nested/entangled, clarify which menu belongs to which domain and split into separate components if needed.

**Checklist:**
- [ ] Different domain data displayed separately
- [ ] Role-specific data does not leak into unauthorized views
- [ ] Each domain has its own provider/state management
- [ ] No cross-domain data in shared global variables

## Gate 4: Impact Check (Side-Effect Scan)

**Rule:** After making a change, related screens/components must be reviewed.

- At the end of every change, state: "This change affected the following files/screens: [list]. I have / have not checked them."
- A task is not complete until related screens have been checked.

**Checklist:**
- [ ] Related screens identified and listed
- [ ] Related providers checked for breakage
- [ ] Shared widgets verified
- [ ] Impact statement documented

## Gate 5: Acceptance Criteria Verification

**Rule:** For every new feature or fix, define concrete acceptance criteria before coding, and verify each one after.

- Before coding: define 3-7 concrete, testable acceptance criteria.
- After coding: verify each criterion one by one.
- A criterion is only "met" if it can be demonstrated working.

**Example Criteria:**
- [ ] [Feature] works in create mode
- [ ] [Feature] works in edit mode
- [ ] [Feature] handles empty/error state correctly
- [ ] Warning/error messages clear when leaving the screen
- [ ] Related screens still function correctly

## Gate 6: Regression Check

**Rule:** When adding a new feature, verify that existing features are not broken.

- Before finishing, ask: "Does this change affect X?" for each related module.
- Where possible, run existing tests to confirm no regressions.
- Manually verify key flows that touch the changed code paths.

**Checklist:**
- [ ] Existing tests pass
- [ ] Static analysis passes
- [ ] Key user flows verified manually
- [ ] No unintended changes in unrelated files

---

**Execution Order:** Gate 1 → Gate 2 → Gate 3 → Gate 4 → Gate 5 → Gate 6. Do not proceed until current gate passes.

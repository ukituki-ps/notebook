# s14 unit quality — notebook-search-ui

- Unit: `notebook-search-ui` · Execution `E0809-s20.sde_5fexecution-u02`
- Verified HEAD: `edd0fec8e0887b33d29cf969aa1774733d042726`
- Role: `architect` (independent of the `sde-frontend` executor)

## crutch_density_grew: **false**

## Reasoning

The change adds behaviour through the existing structure rather than through
workarounds, duplicated paths, or new local abstractions:

- **One render/filter path.** `renderNotes(query)` is defined once
  (`web/app.js:437`) and is the only place DOM rows are rebuilt
  (`appendChild(makeNote(` at 450, one occurrence). Load, create, delete,
  reload/boot, input, and clear all funnel through it (526, 537, 576, 600, 656,
  689, 696). There is no second conditional rendering path.
- **State ownership is explicit, not patched ad hoc.** Load/error/offline/
  collection state lives in four booleans (`notesBusy`, `notesFailed`,
  `notesOfflineState`, `notesLocked`, `web/app.js:328-331`) and is projected by
  `syncNotesState()` (343-382) and `syncFormState()` (384-390). The previous
  `setNotesEnabled()` was replaced by these two projections, so search, clear,
  form, list, retry, and banner visibility cannot drift independently.
- **No duplicated empty-state logic.** `notes-empty` wins via
  `notesEmpty.hidden = !noNotes` (454) and `notes-search-empty` is gated by
  `hasQuery && !noNotes && !blocked` (457-459); `notes-search-count` uses the
  same `hasQuery`/`noNotes`/`blocked` facts (460-463). No fallback branch or
  special-case copy duplicates the empty state.
- **No swallowed errors or fake data.** The non-200 and network branches set
  `notesFailed` and the `role="alert"` copy (511-548); offline keeps loaded
  notes and the banner rather than pretending the list is empty (528-538).
  Notes still come only from `GET /api/notes`.
- **No new dependency, bundler, CDN, local CSS, or design-system fork.**
  `web/app.css` is unchanged (`git diff --quiet f5943f5 HEAD -- web/app.css`
  exit 0); new markup reuses DS selectors (`button`, `.note-item`,
  `.note-text`, `.muted`, `.notes-search*`, state testids). No `design/**` or
  Kubiki change. The offline banner reuses `patterns/note-item` rather than
  adding a fifth local pattern.
- **Oracle strengthened, not weakened.** `web_ui_test.go` gains count/retry/
  offline testids, a11y/role checks, in-memory-query and disabled-state
  assertions, and the token-aware R-1 rule. No pre-existing assertion was
  deleted or weakened; the only replacement is `min-height: 44px` →
  `min-height: var(--control-height)` + `--control-height: 44px`, which keeps
  the same 44px contract and removes the oracle/CSS mismatch.
- **No persistence crutch.** The query lives only in `searchQuery`; the old
  `sessionStorage["notebook.search"]` read/write is removed and only legacy
  cleanup remains (`removeStorage`), which is the narrowest safe migration.

Minor duplication (`notesRetry` and `notesOfflineCheck` share the same
check-`navigator.onLine`-then-`loadNotes` handler at 701-723) is a small DRY
nit, not a crutch and not a new behavioural path. It does not increase crutch
density.

## Residual quality notes (non-blocking)

- The count is not refreshed by the `offline` transition (only by
  `renderNotes`); cosmetic stale count while the offline banner and disabled
  search already explain the state.
- Offline recovery is explicit via `Проверить сеть` (intentional per §3.2).
- `ui-audit-check.py` and `web/e2e/**` are later-step oracles (s22a / U03).

Verdict: **crutch_density_grew = false**.

- accepted: s14.unit_quality (E0809-u02)

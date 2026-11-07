# Feature brief finalization — f-v4-note-search (s06.feature_brief_final, E1546)

- **Step:** `s06.feature_brief_final`
- **Execution:** `E1546`
- **Input:** expertise report (s05).

## Verdict

**PASS** — `feature-brief.md` is finalized (API contract table, search
semantics, UX, 10 wireframe states, AC 1–6, invariants summary) and
`invariants.json` carries the machine-readable list.

## Invariants

- Active core search: `INV-SEARCH-OWNER-SCOPE`, `INV-SEARCH-CASE-INSENSITIVE`,
  `INV-SEARCH-EMPTY-Q`, `INV-SEARCH-NOT-FOUND`, `INV-SEARCH-ENCODING`,
  `INV-SEARCH-AUTH-REQUIRED`, `INV-SEARCH-UI-FILTER`, `INV-SEARCH-UI-EMPTY`,
  `INV-SEARCH-UI-TESTIDS`.
- Existing auth/wire/UI invariants remain active and unchanged.
- Proposed (oracle materializes later): `INV-UI-ORACLE` (s22a),
  `INV-UI-E2E-PREVIEW` (s20c) — published with `proposed` status as required.

## Gate readiness

- `test_ref` entries are runnable commands (`go test -run …`).
- No active invariant points at an oracle that does not yet exist.
- Proceed to s07 requirements reconcile.

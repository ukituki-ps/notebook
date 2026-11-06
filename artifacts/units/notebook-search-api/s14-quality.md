# s14 quality — notebook-search-api

- Feature: `f-v4-note-search`
- Execution: `E8363-s20.sde_5fexecution-u01`
- Unit: `notebook-search-api`
- Worktree: `/workspace/projects/notebook-e8363-u01`
- Branch: `orc-exec-E8363-s20.sde_5fexecution-u01`
- HEAD reviewed: `f6396ad42f913b4fba70882d2dbba66e03f48515`; branch tip at
  report time `94daa77` (artifacts-only s15 commit, source unchanged)
- Verdict: **PASS** — `crutch_density_grew: false`

## Maintainability

- **Smallest viable shape.** Search is a handler-local filter over the existing
  owner-scoped `ListNotes` snapshot (`main.go:538-548`). `Store` gains no search
  API, no new dependency, and no second owner predicate.
- **Single source of owner scoping.** `ListNotes` (`main.go:194-205`) remains the
  only place the owner predicate is applied; the comment at `main.go:536-537`
  documents why filtering cannot widen scope.
- **Readability.** Query normalization happens once before the loop; the filter
  uses a pre-sized `make([]Note, 0, len(notes))` and preserves insertion order.
  No mutation of stored note text.
- **Test helpers.** `decodeNotes` / `assertNoteTexts` keep the oracles compact and
  focused on result-set identity and order.

## Scope discipline

- This unit made **no source change**. `git diff --stat 9ceafdb..HEAD` touches
  only `artifacts/units/notebook-search-api/{s10,s11,s12}`.
- No auth/session/token, persistence, lifecycle, `POST`/`DELETE`, dependency, or
  build-tag change.
- No unrelated or drive-by refactoring.

## Test strength

- Oracles run through the real `httptest.Server` transport, not direct store
  calls (`INV-REAL-TRANSPORT`).
- Not-found is asserted against the exact body `[]`, not a decoded nil/empty
  equivalence.
- Isolation is proven bidirectionally (A cannot see B and vice versa) and
  additionally checks for `UserID` leakage in the response body.
- Auth ordering and `WWW-Authenticate: Bearer` are asserted independently of the
  happy-path search tests.
- Encoding covers percent, space, ampersand, and literal-plus cases without
  panic/500.
- Non-blocking nuance: C-08 mentions raw `+`; the suite covers `%20` and `%2B`
  but not a literal `+` query. `net/http` decoding is shared, so this is a minor
  oracle literalization gap, not a behavior gap.

## Residual risks

- Non-ASCII case folding follows Go `strings.ToLower` (ASCII is the contract
  guarantee); no locale/collation promise is made.
- Per-request lower-casing is O(notes × text) in memory, acceptable for the
  in-memory store and outside any performance acceptance criterion.
- The UI filter is implemented separately in `notebook-search-ui`; both use the
  same trim/lower/substring semantics, and the UI only filters the already
  owner-scoped loaded list.

## Conclusion

The implementation is minimal, contract-faithful, and well covered at the tested
HEAD. No defect, no regression, and no spec change required.

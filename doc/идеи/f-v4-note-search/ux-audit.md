# UX audit — note-search (E1868, s22e)

- Stand: test2 (`https://test2.nexus.ukituki.tech`), build `5785dc0`,
  commit `5785dc0aefbb2ba3e46f42095e5c8d34d6e052f6`, execution E1868.
- Scope: `note-search`, viewports 390x844 and 1200x900.
- Audit role: product/UX auditor independent of the UI author
  (`ses_e4433e6faffeDGXVi4lKO4t3W8`); auditor session
  `ses_e44094ddfffeZsHroFCFnDiUWh`.
- Result: **pass** — 22 items, 0 blockers, 0 open critical/high, 0 majors,
  2 residual minors.

## What was verified

- **Task fit** — an authenticated user can locate a note by text without scanning
  the full list; the filter is owner-scoped and user B cannot surface user A's
  note (SEARCH-E2E-1, SEARCH-E2E-20).
- **IA** — the final order is composer -> search -> count -> list (AOD-7);
  search sits directly above its results and the count sits between them.
- **State truth** — idle, results, no-results, zero-notes, loading, error,
  offline-loaded, and offline-zero are visually and semantically distinct.
  The base empty state wins for a zero-note collection; offline-zero does not
  masquerade as search-empty.
- **Recovery** — Очистить restores the full list and returns focus; Повторить
  reloads after an error; Проверить сеть re-checks connectivity and restores the
  online state.
- **Texts and clarity** — Russian product copy for search, clear, count, both
  empty states, offline, and retry; per-row `Удалить` with a note-specific
  accessible name; `Add`/`Logout` retained by the documented DS-term policy.
- **Count semantics** — `Найдено N` is hidden for empty/whitespace queries,
  shown for a non-empty trimmed query, includes `Найдено 0`, and is a polite
  live region.
- **Responsive hierarchy** — 390px stacks the search row with 44px controls and
  no horizontal overflow; 1200px uses an inline search + clear row in a centered
  card.
- **Keyboard/focus** — visible label and accessible name, `type=search`,
  `aria-controls`, visible focus ring, Tab from the input reaches Очистить, and
  count/search-empty/error/loading carry the intended live-region roles.
- **512-byte cap** — the UI never sends `q`; it filters the already loaded
  owner-scoped list client-side, so the server cap creates no hidden UI limit,
  no 400 path, and no dead end for long input (SEARCH-E2E-17 covers the server
  contract separately).
- **No dead ends** — no-results keeps the search field, Очистить, and composer
  usable; zero and error states expose a visible next action.

## Residual minors

1. **Offline transition with an active query (minor).** If the user goes offline
   while a query is active, the offline banner appears and both the search field
   and Очистить are disabled, so the loaded list stays filtered until the network
   returns. This follows the mandated "search disabled offline" rule and the
   loaded notes are real, but the active filter cannot be cleared offline. It is
   an infrequent transient state, not a blocker; reconnect or reload recovers.
2. **Weak disabled styling at zero notes (minor).** A zero-note collection
   correctly disables the search field and shows the base empty state, but the
   disabled input differs from enabled mainly by muted text/border (the accepted
   GAP-2 for `primitives/input` has no disabled visual state). The base empty
   text explains why, so users are not left without context; the affordance is
   still easy to miss.

Cosmetic observations, not counted as minors: the native `type=search` cancel
"x" coexists with the visible Очистить button (two clear affordances); the
no-results state shows both `Найдено 0` and the explanatory empty copy, which is
explicitly required by AOD-5 and reads as confirmation rather than duplication.

## Evidence

Screenshots: `doc/идеи/f-v4-note-search/screenshots/SEARCH-E2E-1.png`,
`-2`, `-9`, `-10`, `-12`, `-13`, `-14`, `-16`, `-18`, `-19`, `-20`.
Scenario contract: `scenario-evidence.json` (20/20 pass on test2, 5785dc0) and
`preview-verdict.json` (pass, evaluated_sha 5785dc0...). Executable oracles are
`web/e2e/notes-search.spec.js` scenarios and repo-level `grep` checks; the audit
JSON records one oracle and one existing evidence ref per item.

## Re-audit (after s23, build 9c1763c)
- E2E 20/20 re-run; UX product unchanged; verdict pass, 0 blockers, 2 accepted minors remain.

# Adversarial code review — f-v4-note-search (s22c)

- Execution E8363 · base 5935e148 · head eeec54c · platform web
- Author session ses_e4cffab3effecevpjqsiAV9qT2 (deepseek-flash/deepseek)
- Reviewer session ses_e4cdcb1bdffeb0BYuxDKmeRynq (qwen3.8-fast/llama-proxy)

## Scope

The reviewed implementation is the notes search: `GET /api/notes?q=` in main.go, the search UI in web/index.html + web/app.js, and the tests in main_test.go/web_ui_test.go/web/e2e/notes-search.spec.js. The diff 5935e148..eeec54c changes only the E2E screenshot code plus docs/evidence; application code is byte-identical to the base.

## Checks

- `C1` go build/vet/test: go build ./... and go vet ./... exit 0; go test -count=1 ./... ok (2.7s)
- `C2` focused search contract: 8/8 TestNotesSearch* pass (finds/notfound/case/isolation/auth/empty/whitespace/encoding)
- `C3` UI semantics: TestUISemantics pass; notes-search input/clear/empty guard and create/delete/reload filter re-apply
- `C4` diff scope: 5935e148..eeec54c changes only web/e2e/notes-search.spec.js plus docs/evidence; no app/auth/storage/status/deploy/package changes
- `C5` security: owner filter first via ListNotes(session.UserID); no SQL/LIKE; textContent rendering (no innerHTML); no secret/log leakage
- `C6` method/id/status: 401 before method/query; 405+Allow on unsupported methods; invalid/foreign/missing delete 400/404; unknown /api 404 JSON

## Findings

No critical/high/medium/low findings. Cosmetic only: `.notes-search-empty` CSS selector is unused (the status element uses the shared `muted` class).

## Verdict

**pass** — owner-scoped, case-insensitive substring search; auth before query; no wildcard broadening; no injection/DOM-XSS; tests exercise the HTTP transport, isolation, encoding and UI semantics; no unrelated or platform changes.

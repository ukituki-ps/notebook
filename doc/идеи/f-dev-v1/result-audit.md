# Result audit — f-dev-v1 (delete note)

## Verdict: PASS

## Acceptance criteria
- AC-DELETE-204: `DELETE /api/notes/{id}` removes an existing note and returns 204.
- AC-DELETE-404: a missing note returns 404.
- AC-DELETE-400: a non-integer id returns 400.
- AC-DELETE-ISOLATION: deleting one note does not change other notes; List/Add unchanged.

## Oracles / proof
- AC-DELETE-204/404/400: `go test ./...` (`TestDeleteNote`) — pass.
- AC-DELETE-ISOLATION: `TestDeleteNote` asserts the remaining note after delete.
- Deployed identity: `preview-deploy.json` evaluated_sha `c20a0551…`, test2 `/healthz`
  build_ref `c20a055`; API smoke `preview-verdict.json` status `verified`.

## New findings
None.

## Notes
- Backend-only increment; UI graph/mobile probe are N/A (skipped by process).
- No contract drift (no OpenAPI modules in this app repo).

## Re-audit after s23 (2026-11-04)

- Review findings CR-1/CR-2/CR-3 (and RT-1/RT-2) closed: named tests added;
  oracles split to falsifiable tests; 405 and error-envelope asserted.
- Unit suite green; preview e2e verified on test2 (`be5a077`, API mode).
- Verdict: pass.

# f-dev-v1 — unit integration report (s20a)

- Unit: `go test ./...` green; `go vet ./...` clean (commit 2ab74626).
- Feature: `DELETE /api/notes/{id}` + `Store.Delete`, 204/400/404/405 per spec/core.md.
- s23 refinement closed the independent review findings:
  - CR-1/RT-1: docs' named tests now exist (TestAddNote, TestDeleteExisting,
    TestDeleteMissing, TestDeleteInvalidID, TestListAfterDelete).
  - CR-2/RT-2: audit oracles split to distinct falsifiable tests
    (TestDeleteErrorEnvelope for error-envelope, TestNotesMethodNotAllowed for 405).
  - CR-3: added 405/negative-id/error-envelope unit tests.
- Integration: `deploy/path1/e2e-preview.sh` on test2 (GET/POST/healthz).
- Contract parity: drift_count=0.

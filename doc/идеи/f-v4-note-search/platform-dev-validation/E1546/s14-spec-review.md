# Spec generation — f-v4-note-search (s14.spec_generation, E1546)

- **Step:** `s14.spec_generation`
- **Execution:** `E1546`
- **Artifacts:** `spec/core.md`, `spec/contract-matrix.md`
- **Nexus:** `f-v4-note-search/spec/core.md` (approved, v1)

## Verdict

**PASS** — the spec defines `GET /api/notes?q=` (optional, trimmed,
case-insensitive substring, owner-scoped, `[]` not null, 401 before query) and
the web search UI (`notes-search`, clear, `notes-search-empty`), with a contract
matrix covering positive, negative, auth and method cases.

## OpenAPI

This app repo does not use OpenAPI (`openapi/modules/*.yaml` absent); core.md +
contract-matrix.md + test names are the source of truth. Contract parity: 0
drift (no generated API layer to diff).

## Matrix

Contract matrix lists the endpoint/method/status/envelope/test rows, including
`q=milk`, `q=MILK`, `q=zzz` ([]), `q=`, whitespace, owner scope, URL-encoding
(`q=a%26b%2Bc`), missing bearer → 401, PUT/DELETE → 405.

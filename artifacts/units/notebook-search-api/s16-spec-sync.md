# s16 spec sync — notebook-search-api

- synced: **true**
- The change is additive: optional `q` on `GET /api/notes`; no new endpoint,
  status code, envelope, or field. `spec/core.md` and
  `spec/contract-matrix.md` remain accurate; no spec edit required.
- Wire contract (`{id,text}`, `[]` not null, `UserID` hidden) unchanged.

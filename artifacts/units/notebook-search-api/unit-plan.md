# Unit plan — notebook-search-api (f-v4-note-search)

## Goal

Add an optional `q` query parameter to `GET /api/notes` that performs a
case-insensitive substring search over the authenticated user's notes only,
without changing existing behavior, auth order, envelopes, or status codes.

## Steps

1. `main.go` — extend the `http.MethodGet` branch of `api.handleNotes`:
   - Read `r.URL.Query().Get("q")` and `strings.TrimSpace` it.
   - Empty/whitespace-only query keeps the existing `ListNotes(session.UserID)`
     result unchanged.
   - Non-empty query: lowercase query, then filter the already owner-scoped
     `ListNotes` result with `strings.Contains(strings.ToLower(note.Text), query)`.
   - Build the filtered slice with `make([]Note, 0, len(notes))` so the wire
     form stays `[]` and never `null`.
2. `main_test.go` — add eight focused tests covering find, not-found,
   case-insensitivity, A/B isolation, 401, empty query, whitespace query, and
   URL-encoded/special characters. Add two small helpers (`decodeNotes`,
   `assertNoteTexts`) to keep the tests readable.
3. Run `gofmt`, `go build ./...`, `go vet ./...`, `go test -count=1 ./...`
   from the worktree root with `GOWORK=off`.
4. Record plan + evidence under `artifacts/units/notebook-search-api/`.

## Decisions

- **Filter after owner predicate.** The filter is applied to the result of
  `ListNotes(session.UserID)`, which already enforces `note.UserID == userID`.
  A search can therefore only narrow, never widen, the owner scope.
- **Case-insensitive via `strings.ToLower` on both sides**, per the unit
  contract; no locale-specific collation or new dependencies.
- **No store API change.** The handler is the single call site and the filter
  is a presentation concern over an owner-scoped list; keeping it in
  `handleNotes` keeps the change minimal and the owner predicate untouched.
- **Wire contract preserved.** `Note.UserID` stays `json:"-"`; the response
  remains `[{id,text}]`; empty results remain `[]`; auth still runs before
  method dispatch, so unauthenticated searches still return 401 first.
- **Encoding handled by `net/url`.** `r.URL.Query().Get` decodes `%xx` and
  `+`; tests pin percent, space, ampersand, and literal-plus behavior.

## Out of scope (per assignment)

Auth/session/token changes, persistence, new dependencies, build tags,
status/envelope changes, deploy scripts, and any git writes.

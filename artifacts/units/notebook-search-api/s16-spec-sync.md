# s16 spec sync — notebook-search-api

- Execution: E6636 (E6636-s20.sde_5fexecution-u01), unit `notebook-search-api`
- Step: s16.unit_spec_sync (architect)
- HEAD before sync: 5e470e7415eff74e873438e6f15f5b46522607eb
- Evidence: PR-427f687b0369, exit 0 (sha256:af2de066e45b3bec7f10db5f6ae1b06b7a3c2b7eae9cfabdeb56e22d81b9494b)

## Что проверено

Спека фичи (`doc/идеи/f-v4-note-search/spec/`) уже описывает контракт
`GET /api/notes?q=` идентично реализации (`main.go`, не менялся):
auth-first, cap 512 байт до скана (ровно 512 — 200, 513+ — 400 `query too long`,
cap по байтам, до trim), trim/empty/whitespace → все свои заметки,
case-insensitive substring, owner predicate до text predicate, `[]` не `null`,
`UserID` не сериализуется.

Расхождение было в **тестовых ссылках** спеки, не в контракте:

| Drift | Было | Стало |
|---|---|---|
| несуществующий тест | `contract-matrix.md`: `TestNotesList` | `TestNotesLifecycle` (реальное имя, `main_test.go:161`) |
| новые тесты юнита не отражены | — | `TestNotesSearchTrimsQuery`, `TestNotesSearchEmptyStore`, `TestNotesSearchDoesNotMatchOtherOwner` добавлены в matrix/edge-cases |

## Правки

- `doc/идеи/f-v4-note-search/spec/contract-matrix.md`
  - строка `/api/notes` GET: `TestNotesList` → `TestNotesLifecycle`;
  - строка `/api/notes?q=`: + `TestNotesSearchTrimsQuery`;
  - edge cases: trim-around-term, cross-owner unique term → `[]`, zero-notes store → `[]`.
- `doc/идеи/f-v4-note-search/spec/core.md` (§4 invariants)
  - `INV-USER-ISOLATION`/`INV-SEARCH-OWNER-SCOPE` + `TestNotesSearchDoesNotMatchOtherOwner`;
  - `INV-SEARCH-EMPTY-Q` + `TestNotesSearchTrimsQuery`;
  - `INV-SEARCH-NOT-FOUND` + `TestNotesSearchEmptyStore`.

Контракт, статусы, envelope и data model не менялись; `main.go` не тронут.

## Проверка синхронности

Каждое имя `Test*`, упомянутое в `contract-matrix.md` и `core.md`, существует как
`func <Test>(` в `main_test.go` или `web_ui_test.go` (frontend `TestUISemantics`).
Харнесс: `for t in $(grep -oE 'Test[A-Za-z0-9_]+' spec/...); do grep -q "^func $t(" ...; done`
→ 0 MISSING. Плюс `GOWORK=off go build ./...` и `go test ./...` — PASS (8.848s).

## Вердикт

`synced: true` — спека соответствует реализации, тестовые ссылки валидны,
pre-existing drift `TestNotesList` устранён.

# note-search — state matrix

Screen: `note-search` · Unit: `note-search` · Platform: web
Notebook DS 1.0.0 (`web/app.css`, `design/tokens.json`, `design/registry.json`)
Proto: `proto.html?state=<state>` — one state per render. `normal` is an alias of `idle`.

The note form (`.note-form` with a visible `<label for="note-text">Новая заметка</label>`, `textarea`, and `Add`) is visible in **all** states, above the search field, matching `web/index.html`. `Add` is natively disabled with `aria-disabled="true"` while the textarea is empty and in `loading`/`error`/`offline`. Count (`Найдено N`, `aria-live="polite"`) is visible only in `results` and `no-results`.

| State | What the user sees | Primary action | A11y notes |
|---|---|---|---|
| `normal` / `idle` | Note form visible; search field with label «Поиск заметок», empty query, placeholder «Поиск по тексту...»; Очистить hidden; count hidden; 3 saved notes in `.notes-list`. | Type a query or add a note. | Search field is a labelled `input[type=search]` inside `role="search"`; list is `role="list"` with `role="listitem"` rows; Очистить is not tabbable while hidden. |
| `results` | Note form visible; query «план»; Очистить («Очистить», aria-label «Очистить поиск») visible; count «Найдено 3»; 3 matching notes filtered client-side. | Clear the query with Очистить, edit it to refine, or add a note. | Client-side filter over the loaded list (no per-keystroke request); count is visible text; Очистить has an accessible name. |
| `no-results` | Note form visible; query «план»; Очистить visible; count «Найдено 0»; `.notes-list` hidden; message «Ничего не найдено.». | Clear the query or edit it to broaden the match. | `notes-search-empty` is `role="status" aria-live="polite"`; search input stays enabled and focused. |
| `empty` | Note form visible; empty query; Очистить hidden; count hidden; list hidden; message «Пока нет заметок. Добавьте первую выше.». | Add the first note via the form. | `notes-empty` is muted text (not an alert); no phantom `note-item` rows are rendered. |
| `loading` | Note form visible; muted message «Загрузка...» with `role="status" aria-live="polite"`; search disabled with `aria-disabled="true"` and `aria-describedby="notes-loading"`; count and list hidden; list carries `aria-busy="true"`. | Wait for the notes request to complete. | Disabled search removes interaction; the loading status is announced politely; list is marked busy. |
| `error` | Note form visible; `.error` alert «Не удалось загрузить заметки. Повторите позже.» (`role="alert"`) and button «Повторить»; search disabled with `aria-disabled="true"` and `aria-describedby="notes-error"`; count and list hidden. | Press «Повторить» to retry the load. | `role="alert" aria-live="assertive"` announces the failure; retry is the next focusable action; disabled search points at the error text. |
| `offline` | Note form visible; banner composed from DS `.note-item` `role="status"` with `.note-text.muted` text «Нет сети — показаны сохранённые заметки.» and a single-line `44px` button «Проверить сеть»; search disabled with placeholder «Поиск недоступен без сети», `aria-disabled="true"`, `aria-describedby="notes-offline"`; count hidden; 3 saved notes still listed. | Press «Проверить сеть» to re-check connectivity. | Banner uses DS `note-item` border and `muted` text (no custom colors); `.note-text` lets the paragraph flex, and a non-breaking space (plus `aria-label="Проверить сеть"`) keeps the button at its one-line 45px height without local CSS; search disabled because search is unavailable; saved notes remain readable. |

## Coverage notes

- 7 renderable states (`idle`, `results`, `no-results`, `empty`, `loading`, `error`, `offline`) plus the `normal` alias of `idle`.
- Search contract: owner-scoped client-side filter over `{id, text}` notes; `q` capped at 512 bytes upstream; no per-keystroke request.
- UI-review fixes applied: local `<style>` removed (no local CSS, no testid-based styling); count uses `.muted` with `aria-live="polite"`; offline banner is a DS composition (`.note-item` + `.note-text.muted` + `button`) with the button kept on one line; Clear text is «Очистить»; loading/empty/search-empty use `.muted`; count only in `results`/`no-results`; loading has `role="status"`; list sets `aria-busy` while loading; the note form has a visible label and disables `Add` while empty or in `loading`/`error`/`offline`.
- DS drift: `n-count` `[data-testid=notes-search-count]` remains a `path6_required` gap (no dedicated registry component; styled only by `.muted`). `n-note-form` is a composition of `primitives/textarea` + `primitives/button` with no `registry_id` (the registry has no standalone form component; `web/app.css` defines `.note-form`). Retry and offline-check buttons reuse `primitives/button`.
- No Kubiki, no `frontend/src/ui/kit`, no v6 imports; only Notebook DS classes from `web/app.css`.

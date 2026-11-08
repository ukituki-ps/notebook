# note-search — state matrix

Screen: `note-search` · Unit: `note-search` · Platform: web
Notebook DS 1.0.0 (`web/app.css`, `design/tokens.json`, `design/registry.json`)
Proto: `proto.html?state=<state>` — one state per render.

| State | What the user sees | Primary action | A11y notes |
|---|---|---|---|
| `idle` | Search field with label «Поиск заметок», empty query, placeholder «Поиск по тексту...»; Clear hidden; count «Найдено 3»; 3 saved notes in `.notes-list`. | Type into the search field (or scan the full owner-scoped list). | Search field is a labelled `input[type=search]` inside `role="search"`; list is `role="list"` with `role="listitem"` rows; Clear is not in the tab order while hidden. |
| `results` | Query «план»; Clear («Clear», aria-label «Очистить поиск») visible; count «Найдено 3»; 3 matching notes filtered client-side. | Clear the query with Clear, or keep typing to refine matches. | Filtering happens on the loaded list (no request); count is exposed as text; Clear has an accessible name. |
| `no-results` | Query «план»; Clear visible; count «Найдено 0»; `.notes-list` hidden; message «Ничего не найдено.». | Clear the query or edit it to broaden the match. | `notes-search-empty` is `role="status" aria-live="polite"` so the empty result is announced; search input stays enabled and focused. |
| `empty` | Empty query; Clear hidden; count «Найдено 0»; list hidden; message «Пока нет заметок. Добавьте первую выше.». | Add the first note above / clear search context. | `notes-empty` is plain text (not an alert); no phantom `note-item` rows are rendered. |
| `loading` | Message «Загрузка...»; search field disabled; count and list hidden. | Wait for the notes request to complete. | Loading text is visible text; disabled search removes it from interaction; no live-region spam. |
| `error` | `.error` alert «Не удалось загрузить заметки. Повторите позже.» (`role="alert"`) and button «Повторить»; search disabled; count and list hidden. | Press «Повторить» to retry the load. | `role="alert"` with `aria-live="assertive"` announces the failure; retry is the next focusable action. |
| `offline` | Banner «Нет сети — поиск недоступен. Показаны сохранённые заметки.», button «Проверить сеть»; search disabled; count «Найдено 3»; 3 saved notes still listed. | Press «Проверить сеть» to re-check connectivity. | Banner is `role="status"`; search is disabled because search is unavailable; saved notes remain readable. |

## Coverage notes

- 7 states covered: `idle`, `results`, `no-results`, `empty`, `loading`, `error`, `offline`.
- Search contract: owner-scoped client-side filter over `{id, text}` notes; `q` is capped at 512 bytes upstream; no per-keystroke request.
- DS gaps (marked `path6_required` in `proto.json`): count line `[data-testid=notes-search-count]` and offline banner `[data-testid=notes-offline]` are not in `design/registry.json`. Retry and offline-check buttons reuse `primitives/button`.
- No Kubiki, no `frontend/src/ui/kit`, no v6 imports; only Notebook DS selectors from `web/app.css`.

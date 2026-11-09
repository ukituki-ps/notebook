# note-search — state matrix

Screen: `note-search` · Unit: `note-search` · Platform: web
Notebook DS 1.0.1 (`web/app.css`, `design/tokens.json`, `design/registry.json`)
Proto: `proto.html?state=<state>` — one state per render. `normal` is an alias of `idle`.

Dataset: 4 loaded notes. Query `план` matches exactly 2 (`#12 План на неделю`, `#13 Утренний план тренировок`); `#14 Список покупок` and `#15 Позвонить маме` do not match. `no-results` uses the visibly different query `отпуск` (0 matches).

The note form (`.note-form` with a visible `<label for="note-text">Новая заметка</label>`, `textarea`, and `Add`) is visible in **all** states, above the search field (the prototype label/placeholder wording differs from `web/index.html`; accepted minor, see Coverage notes). `Add` is natively disabled with `aria-disabled="true"` while the textarea is empty and in `loading`/`error`/`offline`. Count (`Найдено N`, `aria-live="polite"`) is visible only in `results` and `no-results`.

| State | What the user sees | Primary action | A11y / behavior notes |
|---|---|---|---|
| `normal` / `idle` | Note form visible; search field with label «Поиск заметок», empty query, placeholder «Поиск по тексту...»; Очистить hidden; count hidden; all 4 loaded notes in `.notes-list`, each with a `.delete-note` «Удалить» button. | Type a query, add a note, or delete a note. | Search field is a labelled `input[type=search]` inside `role="search"`; list is `role="list"` with `role="listitem"` rows; each Удалить has `aria-label="Удалить заметку #<id>"`; Очистить is not tabbable while hidden. |
| `results` | Note form visible; query «план»; Очистить («Очистить», aria-label «Очистить поиск») visible; count «Найдено 2»; exactly 2 matching rows with Удалить; the 2 non-matching rows are removed from the visible list. | Удалить a matching note, clear the query, or refine it. | Client-side filter over the loaded list (no per-keystroke request); count is visible text; Удалить is a real DS `.delete-note` danger button. **Удалить action:** removes that note, re-applies the active query, and updates the count; deleting the last match shows `no-results`. |
| `no-results` | Note form visible; query «отпуск»; Очистить visible; count «Найдено 0»; `.notes-list` hidden; message «Ничего не найдено. Сократите запрос или очистите поиск.». | Clear the query or edit it to broaden the match. | `notes-search-empty` is `role="status" aria-live="polite"`; search input stays enabled (no autofocus); query text is visibly different from `results`. |
| `empty` | Note form visible; search **disabled** (there is nothing to filter); empty query; Очистить hidden; count hidden; list hidden; message «Пока нет заметок. Добавьте первую выше.». | Add the first note via the form. | `notes-empty` is muted text (not an alert); search is disabled with `aria-disabled="true"` and `aria-describedby="notes-empty"`; no phantom `note-item` rows are rendered. |
| `loading` | Note form visible; muted message «Загрузка...» with `role="status" aria-live="polite"`; search disabled with `aria-disabled="true"` and `aria-describedby="notes-loading"`; count and list hidden; list carries `aria-busy="true"`. | Wait for the notes request to complete. | Disabled search removes interaction; the loading status is announced politely; list is marked busy. |
| `error` | Note form visible; `.error` alert «Не удалось загрузить заметки. Попробуйте ещё раз.» (`role="alert"`) and button «Повторить»; search disabled with `aria-disabled="true"` and `aria-describedby="notes-error"`; count and list hidden. | Press «Повторить» to retry the load. | `role="alert" aria-live="polite"` announces the failure; retry is the next focusable action; error copy matches the retry affordance. |
| `offline-zero` | Note form visible; offline banner «Нет сети — нет загруженных заметок.» and base empty message «Пока нет заметок. Добавьте первую выше.»; search disabled; count/list/clear hidden. | Re-check connectivity. | Distinct from `empty`: the offline banner explains why no notes are shown; `notes-empty` stays visible. |
| `offline` | Note form visible; banner composed from DS `.note-item` `role="status"` with `.note-text.muted` text «Нет сети — показаны загруженные заметки.» and a single-line 44px `min-height` button «Проверить сеть»; search disabled with placeholder «Поиск недоступен без сети», `aria-disabled="true"`, `aria-describedby="notes-offline"`; count hidden; all 4 loaded notes with Удалить visible but disabled (DELETE needs the network). | Press «Проверить сеть» to re-check connectivity. | **«Проверить сеть» behavior:** re-check connectivity and return to the loaded list; the prototype simulates a successful re-check by switching to `idle`. The banner has a 16px DS spacing class above the list. Banner uses DS `note-item` border and `muted` text (no custom colors); `.note-text` lets the paragraph flex, and a non-breaking space (plus `aria-label="Проверить сеть"`) keeps the button on one line without local CSS; saved loaded notes remain readable. |

## Brief coverage (screen_brief → proto)

| screen_brief item | Proto state(s) | Nodes |
|---|---|---|
| search field | `normal`/`idle`, `results`, `no-results`, `loading`, `error`, `offline`, `offline-zero` | `n-search-field`, `n-search-clear` |
| clear | `results`, `no-results` | `n-search-clear` |
| idle | `normal`/`idle` | `n-notes-header`, `n-note-form`, `n-search-field`, `n-notes-list`, `n-note-item`, `n-delete` |
| results | `results` | `n-search-field`, `n-search-clear`, `n-count`, `n-notes-list`, `n-note-item`, `n-delete` |
| empty | `empty`, `offline-zero` | `n-empty` |
| loading | `loading` | `n-loading` |
| error | `error` | `n-error`, `n-retry` |
| offline | `offline`, `offline-zero` | `n-offline`, `n-offline-check` |
| read-only notes list with delete | `normal`/`idle`, `results`, `offline` | `n-notes-list`, `n-note-item`, `n-delete` |

No unlabeled state: every `states[]` entry has a `state_matrix` row. `blocked` and
`over-budget` do not apply to this screen (see `proto.json.domain_states`): auth
failure redirects to login with no rendered blocked screen, and the only budget
limit is the API `q` 512-byte cap (`400`, not a screen state). `offline` is an
explicit domain state with two variants (`offline`, `offline-zero`).

Every `nodes[]` entry has a `component-map.yaml` entry; `n-count` and `n-delete`
are marked `path6_required: true` (no 1:1 DS registry id).

## Breakpoints / exports

| Width | Layout | Exports |
|---|---|---|
| 390 | Mobile: search row stacked, full-width 44px controls, no horizontal scroll; note rows wrap with delete aligned right. | `exports/export-390-{idle,results,no-results,empty,loading,error,offline}.png` |
| 1200 | Desktop: centered column/card, inline search field + clear, count above the list. | `exports/export-1200-{idle,results,no-results,empty,loading,error,offline}.png` |

`offline-zero` is renderable via `proto.html?state=offline-zero` but has no
exported PNG in `units/note-search/exports/` (only `offline` is exported).

## Coverage notes

- 8 renderable states (`idle`, `results`, `no-results`, `empty`, `loading`, `error`, `offline`, `offline-zero`) plus the `normal` alias of `idle`.
- Search contract: owner-scoped client-side filter over `{id, text}` notes; `q` capped at 512 bytes upstream; no per-keystroke request.
- UX fixes applied: 4-note dataset with 2 `план` matches; `results` count 2; `no-results` uses `отпуск`; offline copy says «загруженные заметки»; error copy aligned with retry; no-results message suggests shortening/clearing; real note rows include the DS `.delete-note` danger button.
- DS drift: `n-count` `[data-testid=notes-search-count]` remains a `path6_required` gap (no dedicated registry component; styled only by `.muted`). `n-delete` `.delete-note` is also `path6_required`: the danger variant exists in `web/app.css` but is absent from `design/registry.json` (real DS registry omission). `n-note-form` is a composition of `primitives/textarea` + `primitives/button` with no `registry_id`. Retry and offline-check buttons reuse `primitives/button`.
- No Kubiki, no `frontend/src/ui/kit`, no v6 imports; only Notebook DS classes from `web/app.css`; no local CSS.
- State-per-render limitation: the search input is not live-wired in the static prototype (typing does not filter); `web/app.js` implements the live filter. Prototype label/placeholder («Новая заметка»/«Текст заметки») intentionally differs from the app («Текст заметки»/«Введите заметку...»); accepted minor.

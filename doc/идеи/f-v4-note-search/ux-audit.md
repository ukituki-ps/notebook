# UX audit — note-search (E6636, s22e)

- Stand: test2 (`https://test2.nexus.ukituki.tech`), build **`c988c08`**,
  commit `c988c0828830ffb2d43a9008f6344a001687d21d`, image
  `sha256:1981fae5…`, execution E6636. Код идентичен проверенному на s20c
  (`6503f66..c988c08` — только docs/arch), E2E перепрогнан на `c988c08`:
  **30/30**, сценарии **20/20**.
- Scope: `note-search`, viewports 390x844 and 1200x900.
- Audit role: product/UX auditor независим от автора UI-кода
  (`ses_e4433e6faffeDGXVi4lKO4t3W8`); сессия аудитора
  `ses_ci_notebook_path10_15`.
- Result: **pass** — 22 items, 0 blockers, 0 open critical/high, 0 majors,
  **1 residual minor** (было 2).

## What was verified

- **Task fit** — аутентифицированный пользователь находит заметку по тексту,
  не просматривая весь список; фильтр owner-scoped, B не видит заметку A
  (SEARCH-E2E-1, SEARCH-E2E-20).
- **IA** — итоговый порядок composer → search → count → list (AOD-7); поиск
  прямо над результатами, счётчик между ними.
- **State truth** — idle, results, no-results, zero-notes, loading, error,
  offline-loaded, offline-zero различимы визуально и семантически; базовый
  empty выигрывает при пустой коллекции; offline-zero не маскируется под
  search-empty.
- **Recovery** — `Очистить` возвращает полный список и фокус; `Повторить`
  перезагружает после ошибки; `Проверить сеть` восстанавливает online.
  CR-03: `Очистить` работает офлайн при активном запросе (disabled только при
  401-блокировке) — прежний minor снят.
- **Texts and clarity** — русские тексты совпадают со `spec/core.md §3`
  (`Очистить`, `Найдено N`, `Ничего не найдено. Сократите запрос или очистите
  поиск.`, `Пока нет заметок. Добавьте первую выше.`, `Нет сети — показаны
  загруженные заметки.` / `…нет загруженных заметок.`, `Проверить сеть`,
  `Сессия истекла. Перенаправление на вход...`); у `Удалить` доступное имя с
  номером заметки; `Add`/`Logout` сохранены по DS-term policy.
- **Count semantics** — `Найдено N` скрыт для пустого/whitespace-запроса,
  показан для непустого trimmed, включает `Найдено 0`, `aria-live=polite`.
- **Responsive hierarchy** — 390px: стек composer/search/clear (44px), без
  горизонтального скролла; 1200px: центрированная карточка, inline-поиск+clear.
- **Keyboard/focus** — видимый label и accessible name, `type=search`,
  `aria-controls`, видимый focus ring, Tab до `Очистить`, live-region роли.
- **512-byte cap** — UI не отправляет `q`, фильтрует уже загруженный список;
  серверный cap не создаёт скрытого лимита/400/тупика (SEARCH-E2E-17).
- **No dead ends** — no-results оставляет поле, `Очистить` и композер; zero и
  error состояния дают видимое следующее действие.

## Residual minor (accepted)

1. **Слабое disabled-оформление при пустой коллекции.** При нуле заметок поле
   поиска корректно disabled, но отличается от активного в основном muted
   текстом/бордером (принятый GAP-2: у `primitives/input` нет disabled-стейта).
   Базовый empty-текст объясняет причину, поэтому контекста не теряется;
   аффорданс всё же легко пропустить. Не блокер.

Cosmetic: нативный `type=search` крестик сосуществует с `Очистить`; no-results
показывает и `Найдено 0`, и поясняющий empty-текст — требование AOD-5, читается
как подтверждение, не дубль.

## Evidence

Скриншоты (per-run, вне git): `.orc-eval/E6636/doc/идеи/f-v4-note-search/screenshots/SEARCH-E2E-{1,2,9,10,12,13,14,16,18,19,20}.png`
+ CR-03; `scenario-evidence.json` (20/20 pass, `c988c08`), `preview-verdict.json`
(pass, evaluated_sha `c988c08…`), evidence-manifest `sha256:f40df89a…`.
Исполнимые oracle — сценарии `web/e2e/notes-search.spec.js` и repo-level `grep`;
в JSON у каждого item один oracle и существующая evidence-ссылка.

## Re-audit history

- E1868 (build `9c1763c`): pass, 2 minors — offline clear и disabled-стейл.
- **E6636 (build `c988c08`)**: pass, offline-clear снят (CR-03), остаётся
  1 accepted minor (disabled-оформление, GAP-2).

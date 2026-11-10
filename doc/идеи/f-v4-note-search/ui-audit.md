# UI audit — note-search (E6636, s22a)

- Stand: **test2** (`https://test2.nexus.ukituki.tech`), build **`c988c08`**,
  image `sha256:1981fae5…`, gate bundle `sha256:042082ac…`, execution `E6636`.
  `/healthz` подтверждает `build_ref=c988c08`, `commit=c988c082…`,
  `image_digest`, `build_args_hash` — аудит снят с выкаченного билда, не с
  прекеша/чужого образа (`preview-deploy.json` + `preview-verdict.json`).
  Код идентичен проверенному на s20c (`6503f66..c988c08` — только docs/arch
  артефакты), поэтому аудит действителен и для прежнего кадра; E2E перепрогнан
  на `c988c08`: **30/30**, сценарии **20/20**.
- DS: Notebook DS **1.0.1** (`ds/v1.0.1`, manifest `sha256:dbc2983b…`,
  digest `sha256:4e0ef105…`), 14/14 registry-компонентов, 0 Kubiki-импортов,
  0 локальных инстансов; path6 приняты: count (GAP-1), search-field state
  (GAP-2), delete (GAP-3, registry omission), offline banner, retry.
- Блоки **A–L** покрыты **24 items**, у каждого — исполнимый oracle и реальное
  доказательство (Playwright `SEARCH-E2E-*` скриншоты, live-DOM/asset проверки
  стенда, репозиторные команды). `na`-позиций нет.
- Машинные проверки: `gate-ui-audit` PASS (platform=web),
  `ds-token-drift` PASS (20 token checks), `ds-drift` PASS, `ds-usage` PASS,
  `pngdiff` OK (20 скриншотов, near-duplicate нет, thresh 0.005),
  `go test TestUISemantics` + search/auth/isolation — `ok`.
- Live-проверка стенда (26 assertions, независимо от E2E): `html lang=ru`,
  viewport `width=device-width`, `data-screen="notes"`, `role="search"` +
  `aria-controls="notes-list"`, label `for="notes-search"`,
  `aria-label` у clear/offline-check/delete, `role=status` у loading/
  search-empty/offline, `role=alert` у error, `role=list` + `aria-busy` у
  списка, `textContent` для текста заметки (XSS), `:focus-visible`,
  `--control-height: 44px`, `@media (max-width: 640px)`, фичевый CSS — только
  `var(--…)` (34 токен-ссылки; raw-hex только в `:root`-токенах DS).
- Итог: **0 blockers, 0 open critical/high**, 0 DS-usage violations; verdict
  `pass` (`blockers: 0, majors_open: 0`).
- Скриншоты (per-run, вне git): `.orc-eval/E6636/doc/идеи/f-v4-note-search/screenshots/SEARCH-E2E-1..20.png`
  (+CR-01..03), evidence-manifest `sha256:f40df89a…`.
- ORC evidence: `PR-8a1b2c45e639` (live DOM + gates + pngdiff),
  `PR-727c42e9b6e8` (gate-ui-audit PASS + go UI tests),
  `PR-32b5b8f5b623` (redeploy c988c08), `PR-fa35089b5707` (artifact proof).

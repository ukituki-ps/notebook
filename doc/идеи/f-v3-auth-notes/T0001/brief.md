# T0001 — brief

- unit_id: **notebook-auth-api**
- domain: **notebook-api**
- sde: **sde-backend**
- change_class: **security**
- task: Store-модель users/sessions/notes + PBKDF2 + bearer-сессии
- files: `main.go`, `main_test.go`
- depends_on: —

## Scope

1. **Данные и Store.** Расширить единственный in-memory `Store`:
   `User{ID, Username, PasswordHash, Salt}`, `Session{Token, UserID, ExpiresAt}`,
   `Note{ID, UserID, Text}`; карты `usersByID`, `usersByName`, `sessions`,
   `notes`; `nextUser`, `nextNote`; один `mu sync.Mutex` на users/sessions/notes
   и `regMu sync.Mutex` на регистрацию; `now func() time.Time` с дефолтом
   `time.Now` для детерминированных TTL-тестов. Поля `PasswordHash`, `Salt`,
   `Session.Token`, `Session.UserID`, `Session.ExpiresAt`, `Note.UserID` —
   `json:"-"`.
2. **Пароли.** PBKDF2-HMAC-SHA256 только на stdlib (`crypto/hmac`,
   `crypto/sha256`, `encoding/binary`): соль 16B `crypto/rand`, итерации
   210 000 (package-level `var`, тесты могут понижать и восстанавливать),
   ключ 32B, сверка `crypto/subtle.ConstantTimeCompare`. Хэширование и verify —
   **вне** `Store.mu`. Для несуществующего username login выполняет
   dummy-PBKDF2 с теми же параметрами.
3. **Токен и сессия.** 32 случайных байта `crypto/rand`,
   `base64.RawURLEncoding` (~43 символа), непрозрачный (не JWT); TTL 24h fixed от
   логина; lookup по `map[token]`; истёкшая сессия удаляется лениво при
   обращении и даёт 401; `crypto/rand` failure → 500 `internal error` без
   предсказуемой соли/токена. Sliding/refresh нет.
4. **Owner-scoped примитивы Store** (без HTTP-обвязки): `List(userID)` отдаёт
   не-nil `[]` только своих заметок; `Add(userID, text)`; `Delete(userID,
   noteID)` возвращает `false` и для несуществующей, и для чужой заметки; id
   заметок глобально монотонные и не переиспользуются.
5. **Тесты на этот слой** (в `main_test.go`): `TestPasswordHashed` (PBKDF2
   детерминизм в рамках соли, разные соли у разных пользователей, неверный
   пароль → false, сверка constant-time), `TestTokenExpiry` (инъекция `now`:
   до TTL доступ есть, после TTL — 401 и сессия удалена). Тесты — через
   HTTP-транспорт (`httptest`), где применимо; прямые вызовы Store допустимы
   только для unit-проверки хэша/токена.

## Acceptance / оракулы

```sh
go build ./...
go vet ./...
go test -count=1 -run 'TestPasswordHashed|TestTokenExpiry' ./...
go test -race ./...
grep -n 'pbkdf2' main.go                        # PBKDF2 реализован в main.go
grep -n 'ConstantTimeCompare' main.go           # constant-time сверка
git diff --exit-code go.mod                     # без новых зависимостей
```

- Пароль нигде не хранится открыто; в `User` только `Salt` + `PasswordHash`.
- 210k итераций не выполняются под `Store.mu` (проверяется ревью; поведение —
  `go test -race`).
- Токен ровно 32 случайных байта → 43 символа base64url без padding.
- TTL 24h fixed, lazy expiry, без refresh/sliding.
- `go test -race ./...` зелёный (без гонок на users/sessions/notes).

## Зависимости

- Нет. T0002 и T0003 опираются на этот слой; задачи U01 выполняются
  последовательно в одном worktree (общий `main.go`/`main_test.go`).

## Что НЕ делать

- Не добавлять endpoints `register`/`login`/notes и auth-guard — это T0002/T0003.
- Не добавлять зависимости в `go.mod` (`golang.org/x/crypto`, JWT и т.п.).
- Не выполнять PBKDF2 под `Store.mu`; не логировать пароли/хэши/соли/токены.
- Не добавлять БД/DSN/миграции, refresh/sliding TTL, `POST /api/logout`.
- Не менять `go.mod`, `deploy/*`, adapter-файлы, `web/*`.
- Не переносить DELETE-обработчик и литерал `http.StatusNoContent` из `main.go`
  (canary `CANARY-DELETE-STATUS`).
- Не добавлять build-теги `integration/e2e/manual`.
- Не трогать E1320 и артефакты других исполнений.

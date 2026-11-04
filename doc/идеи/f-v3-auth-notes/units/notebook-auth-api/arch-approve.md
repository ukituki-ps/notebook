# s11a — ARCH-APPROVE: notebook-auth-api (U01)

- verdict: **approved**
- reviewed_commit: d15186e2efd22c86e22a775bafa9dce13aa7c19b
- base: e2436c9d022cf66240ecbba15b4c82d6f13a6605

## Проверено

- Секреты не утекают: `json:"-"` на Salt/PasswordHash/UserID/Session-полях;
  login отдаёт только `{"token":...}`; TestNoSecretLeak/TestWireContract.
- PBKDF2-HMAC-SHA256 stdlib: salt 16B, key 32B, 210000 итераций,
  constant-time compare, dummy-PBKDF2 для unknown user.
- Порядок auth → method → id → body; 401 + WWW-Authenticate; 405 + Allow.
- Owner-scope: List по session.UserID (`[]`, не null); DELETE чужой/отсутствующей
  → 404; 204 без тела.
- Единый JSON-envelope; неизвестный `/api/*` → JSON 404.
- `http.StatusNoContent` остаётся в main.go (canary).
- go.mod не изменён, build-тегов нет; имена TestDeleteNote/
  TestDeleteErrorEnvelope/TestNotesMethodNotAllowed сохранены.
- Тяжёлые проверки: `go build ./... && go vet ./... && go test -count=1 ./...`
  — PASS (E4312-s20...-u01, PR-ea6b4aa32597).

## Замечания

Нет блокирующих. Race-прогон выполняется на стенде/CI (в authoring-окружении
нет cgo-компилятора).

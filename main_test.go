package main

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

type testServer struct {
	t     *testing.T
	store *Store
	srv   *httptest.Server
}

type httpResult struct {
	code   int
	header http.Header
	body   string
}

func newTestServer(t *testing.T) *testServer {
	t.Helper()
	store := NewStore()
	srv := httptest.NewServer(handler(store))
	t.Cleanup(srv.Close)
	return &testServer{t: t, store: store, srv: srv}
}

func (ts *testServer) do(method, path, body string, headers map[string]string) httpResult {
	ts.t.Helper()
	var reader io.Reader
	if body != "" {
		reader = strings.NewReader(body)
	}
	req, err := http.NewRequest(method, ts.srv.URL+path, reader)
	if err != nil {
		ts.t.Fatalf("new request: %v", err)
	}
	for name, value := range headers {
		req.Header.Set(name, value)
	}
	resp, err := ts.srv.Client().Do(req)
	if err != nil {
		ts.t.Fatalf("%s %s: %v", method, path, err)
	}
	defer resp.Body.Close()
	payload, err := io.ReadAll(resp.Body)
	if err != nil {
		ts.t.Fatalf("read %s %s: %v", method, path, err)
	}
	return httpResult{code: resp.StatusCode, header: resp.Header, body: string(payload)}
}

func (ts *testServer) authed(method, path, body, token string) httpResult {
	ts.t.Helper()
	headers := map[string]string{}
	if token != "" {
		headers["Authorization"] = "Bearer " + token
	}
	return ts.do(method, path, body, headers)
}

func (ts *testServer) post(path string, payload any) httpResult {
	ts.t.Helper()
	return ts.do(http.MethodPost, path, jsonBody(ts.t, payload), nil)
}

func (ts *testServer) seedUser(username string) string {
	ts.t.Helper()
	res := ts.post("/api/register", credentials{Username: username, Password: "password123"})
	if res.code != http.StatusCreated {
		ts.t.Fatalf("seed register %q: %d %s", username, res.code, res.body)
	}
	res = ts.post("/api/login", credentials{Username: username, Password: "password123"})
	if res.code != http.StatusOK {
		ts.t.Fatalf("seed login %q: %d %s", username, res.code, res.body)
	}
	var token tokenResponse
	if err := json.Unmarshal([]byte(res.body), &token); err != nil {
		ts.t.Fatalf("seed token %q: %v", username, err)
	}
	return token.Token
}

func (ts *testServer) seedNote(token, text string) Note {
	ts.t.Helper()
	res := ts.authed(http.MethodPost, "/api/notes", jsonBody(ts.t, noteRequest{Text: text}), token)
	if res.code != http.StatusCreated {
		ts.t.Fatalf("seed note %q: %d %s", text, res.code, res.body)
	}
	var note Note
	if err := json.Unmarshal([]byte(res.body), &note); err != nil {
		ts.t.Fatalf("seed note decode %q: %v", text, err)
	}
	return note
}

func (ts *testServer) useClock(clock func() time.Time) {
	ts.store.mu.Lock()
	ts.store.now = clock
	ts.store.mu.Unlock()
}

func (ts *testServer) sessionCount() int {
	ts.store.mu.Lock()
	defer ts.store.mu.Unlock()
	return len(ts.store.sessions)
}

func (ts *testServer) user(username string) *User {
	ts.store.mu.Lock()
	defer ts.store.mu.Unlock()
	return ts.store.usersByName[username]
}

func jsonBody(t *testing.T, v any) string {
	t.Helper()
	body, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("marshal request body: %v", err)
	}
	return string(body)
}

func decodeObject(t *testing.T, body string) map[string]json.RawMessage {
	t.Helper()
	var obj map[string]json.RawMessage
	if err := json.Unmarshal([]byte(body), &obj); err != nil {
		t.Fatalf("decode object %q: %v", body, err)
	}
	return obj
}

func assertKeys(t *testing.T, body string, want ...string) map[string]json.RawMessage {
	t.Helper()
	obj := decodeObject(t, body)
	if len(obj) != len(want) {
		t.Fatalf("keys in %q: got %d want %d %v", body, len(obj), len(want), want)
	}
	for _, key := range want {
		if _, ok := obj[key]; !ok {
			t.Fatalf("missing key %q in %q", key, body)
		}
	}
	return obj
}

func isBase64URL(r rune) bool {
	return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '-' || r == '_'
}

func TestNotesLifecycle(t *testing.T) {
	ts := newTestServer(t)
	if res := ts.do(http.MethodGet, "/healthz", "", nil); res.code != http.StatusOK {
		t.Fatalf("healthz: %d", res.code)
	}
	token := ts.seedUser("lifecycle")
	res := ts.authed(http.MethodGet, "/api/notes", "", token)
	if res.code != http.StatusOK || strings.TrimSpace(res.body) != "[]" {
		t.Fatalf("empty list: %d %s", res.code, res.body)
	}

	note := ts.seedNote(token, "купить хлеб")
	if note.ID != 1 || note.Text != "купить хлеб" {
		t.Fatalf("note: %+v", note)
	}

	res = ts.authed(http.MethodGet, "/api/notes", "", token)
	if res.code != http.StatusOK {
		t.Fatalf("list: %d %s", res.code, res.body)
	}
	var notes []Note
	if err := json.Unmarshal([]byte(res.body), &notes); err != nil {
		t.Fatalf("decode list: %v", err)
	}
	if len(notes) != 1 || notes[0] != note {
		t.Fatalf("notes: %+v", notes)
	}
}

func TestDeleteNote(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("deleter")
	keep := ts.seedNote(token, "оставить меня")
	drop := ts.seedNote(token, "удалить меня")

	res := ts.authed(http.MethodDelete, "/api/notes/"+strconv.Itoa(drop.ID), "", token)
	if res.code != http.StatusNoContent {
		t.Fatalf("delete existing: %d %s", res.code, res.body)
	}
	if res.body != "" {
		t.Fatalf("204 body: %q", res.body)
	}
	if ct := res.header.Get("Content-Type"); ct != "" {
		t.Fatalf("204 content-type: %q", ct)
	}

	if res := ts.authed(http.MethodDelete, "/api/notes/"+strconv.Itoa(drop.ID), "", token); res.code != http.StatusNotFound {
		t.Fatalf("delete twice: %d %s", res.code, res.body)
	}
	if res := ts.authed(http.MethodDelete, "/api/notes/abc", "", token); res.code != http.StatusBadRequest {
		t.Fatalf("delete non-numeric: %d %s", res.code, res.body)
	}

	res = ts.authed(http.MethodGet, "/api/notes", "", token)
	var notes []Note
	if err := json.Unmarshal([]byte(res.body), &notes); err != nil {
		t.Fatal(err)
	}
	if len(notes) != 1 || notes[0].ID != keep.ID || notes[0].Text != keep.Text {
		t.Fatalf("list after delete: %+v", notes)
	}
}

func TestDeleteErrorEnvelope(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("envelope")
	for _, tc := range []struct {
		path string
		code int
		body string
	}{
		{"/api/notes/abc", http.StatusBadRequest, `{"error":"invalid id"}`},
		{"/api/notes/999", http.StatusNotFound, `{"error":"not found"}`},
	} {
		res := ts.authed(http.MethodDelete, tc.path, "", token)
		got := strings.TrimSpace(res.body)
		if res.code != tc.code || got != tc.body {
			t.Fatalf("delete %s: %d %q (want %d %q)", tc.path, res.code, got, tc.code, tc.body)
		}
		if ct := res.header.Get("Content-Type"); ct != "application/json" {
			t.Fatalf("delete %s content-type: %q", tc.path, ct)
		}
		for _, leak := range []string{"strconv", "panic", "goroutine", "main.go"} {
			if strings.Contains(got, leak) {
				t.Fatalf("delete %s leaks %q: %q", tc.path, leak, got)
			}
		}
	}
}
func TestNotesMethodNotAllowed(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("verbs")
	note := ts.seedNote(token, "x")

	for _, method := range []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodPatch} {
		res := ts.authed(method, "/api/notes/"+strconv.Itoa(note.ID), "", token)
		if res.code != http.StatusMethodNotAllowed {
			t.Fatalf("%s item: %d %s", method, res.code, res.body)
		}
		if allow := res.header.Get("Allow"); allow != "DELETE" {
			t.Fatalf("%s Allow: %q", method, allow)
		}
		if got := strings.TrimSpace(res.body); got != `{"error":"method not allowed"}` {
			t.Fatalf("%s body: %q", method, got)
		}
	}

	for _, method := range []string{http.MethodPut, http.MethodPatch, http.MethodDelete} {
		res := ts.authed(method, "/api/notes", "", token)
		if res.code != http.StatusMethodNotAllowed {
			t.Fatalf("%s collection: %d %s", method, res.code, res.body)
		}
		if allow := res.header.Get("Allow"); allow != "GET, POST" {
			t.Fatalf("%s Allow: %q", method, allow)
		}
	}
}

func TestRegister(t *testing.T) {
	ts := newTestServer(t)

	res := ts.post("/api/register", credentials{Username: "alice", Password: "password123"})
	if res.code != http.StatusCreated {
		t.Fatalf("register: %d %s", res.code, res.body)
	}
	obj := assertKeys(t, res.body, "id", "username")
	var username string
	if err := json.Unmarshal(obj["username"], &username); err != nil || username != "alice" {
		t.Fatalf("register username: %q err=%v", username, err)
	}
	if ct := res.header.Get("Content-Type"); ct != "application/json" {
		t.Fatalf("register content-type: %q", ct)
	}
	for _, secret := range []string{"password", "hash", "salt"} {
		if strings.Contains(res.body, secret) {
			t.Fatalf("register leaks %q: %s", secret, res.body)
		}
	}

	res = ts.post("/api/register", credentials{Username: "alice", Password: "password123"})
	if res.code != http.StatusConflict || strings.TrimSpace(res.body) != `{"error":"username taken"}` {
		t.Fatalf("duplicate: %d %s", res.code, res.body)
	}

	res = ts.post("/api/register", credentials{Username: "Alice", Password: "password123"})
	if res.code != http.StatusCreated {
		t.Fatalf("case-sensitive register: %d %s", res.code, res.body)
	}

	for _, tc := range []struct {
		name     string
		username string
		password string
		code     int
		err      string
	}{
		{"empty", "", "", 400, "username and password required"},
		{"blank username", "   ", "password123", 400, "username and password required"},
		{"empty password", "carol", "", 400, "username and password required"},
		{"short username", "ab", "password123", 400, "invalid username"},
		{"space username", "a b", "password123", 400, "invalid username"},
		{"non-ascii username", "юзер", "password123", 400, "invalid username"},
		{"long username", strings.Repeat("a", 33), "password123", 400, "invalid username"},
		{"short password", "carol", "short7", 400, "invalid password"},
		{"long password", "carol", strings.Repeat("p", 129), 400, "invalid password"},
	} {
		res := ts.post("/api/register", credentials{Username: tc.username, Password: tc.password})
		want := `{"error":"` + tc.err + `"}`
		if res.code != tc.code || strings.TrimSpace(res.body) != want {
			t.Fatalf("%s: %d %s (want %d %s)", tc.name, res.code, res.body, tc.code, want)
		}
	}

	for _, body := range []string{`{"username":`, `{"username":123,"password":"password123"}`} {
		res := ts.do(http.MethodPost, "/api/register", body, nil)
		if res.code != http.StatusBadRequest || strings.TrimSpace(res.body) != `{"error":"invalid request body"}` {
			t.Fatalf("register malformed %q: %d %s", body, res.code, res.body)
		}
	}

	oversized := `{"username":"dave","password":"` + strings.Repeat("x", maxBodyBytes) + `"}`
	res = ts.do(http.MethodPost, "/api/register", oversized, nil)
	if res.code != http.StatusBadRequest || strings.TrimSpace(res.body) != `{"error":"invalid request body"}` {
		t.Fatalf("register oversized: %d %s", res.code, res.body)
	}

	res = ts.do(http.MethodGet, "/api/register", "", nil)
	if res.code != http.StatusMethodNotAllowed {
		t.Fatalf("register method: %d", res.code)
	}
	if allow := res.header.Get("Allow"); allow != "POST" {
		t.Fatalf("register Allow: %q", allow)
	}
	if got := strings.TrimSpace(res.body); got != `{"error":"method not allowed"}` {
		t.Fatalf("register method body: %q", got)
	}
}

func TestLogin(t *testing.T) {
	ts := newTestServer(t)
	if res := ts.post("/api/register", credentials{Username: "loginuser", Password: "password123"}); res.code != http.StatusCreated {
		t.Fatalf("register: %d %s", res.code, res.body)
	}

	res := ts.post("/api/login", credentials{Username: "loginuser", Password: "password123"})
	if res.code != http.StatusOK {
		t.Fatalf("login: %d %s", res.code, res.body)
	}
	obj := assertKeys(t, res.body, "token")
	var token string
	if err := json.Unmarshal(obj["token"], &token); err != nil {
		t.Fatalf("token decode: %v", err)
	}
	if len(token) != 43 {
		t.Fatalf("token length: %d", len(token))
	}
	for _, r := range token {
		if !isBase64URL(r) {
			t.Fatalf("token character %q is not base64url", r)
		}
	}

	res = ts.post("/api/login", credentials{})
	if res.code != http.StatusBadRequest || strings.TrimSpace(res.body) != `{"error":"username and password required"}` {
		t.Fatalf("login empty: %d %s", res.code, res.body)
	}

	res = ts.do(http.MethodPost, "/api/login", `{`, nil)
	if res.code != http.StatusBadRequest || strings.TrimSpace(res.body) != `{"error":"invalid request body"}` {
		t.Fatalf("login malformed: %d %s", res.code, res.body)
	}

	res = ts.do(http.MethodGet, "/api/login", "", nil)
	if res.code != http.StatusMethodNotAllowed {
		t.Fatalf("login method: %d", res.code)
	}
	if allow := res.header.Get("Allow"); allow != "POST" {
		t.Fatalf("login Allow: %q", allow)
	}
}

func TestLoginInvalid(t *testing.T) {
	ts := newTestServer(t)
	if res := ts.post("/api/register", credentials{Username: "realuser", Password: "password123"}); res.code != http.StatusCreated {
		t.Fatalf("register: %d %s", res.code, res.body)
	}

	wrongPassword := ts.post("/api/login", credentials{Username: "realuser", Password: "wrongpassword"})
	unknownUser := ts.post("/api/login", credentials{Username: "ghostuser", Password: "password123"})
	for name, res := range map[string]httpResult{
		"wrong password": wrongPassword,
		"unknown user":   unknownUser,
	} {
		if res.code != http.StatusUnauthorized {
			t.Fatalf("%s: %d %s", name, res.code, res.body)
		}
		if got := strings.TrimSpace(res.body); got != `{"error":"unauthorized"}` {
			t.Fatalf("%s body: %q", name, got)
		}
		if www := res.header.Get("WWW-Authenticate"); www != "Bearer" {
			t.Fatalf("%s WWW-Authenticate: %q", name, www)
		}
	}
	if wrongPassword.body != unknownUser.body {
		t.Fatalf("login failures differ: %q vs %q", wrongPassword.body, unknownUser.body)
	}
}

func TestAuthRequired(t *testing.T) {
	ts := newTestServer(t)
	valid := ts.seedUser("guard")
	paths := []struct {
		method string
		path   string
	}{
		{http.MethodGet, "/api/notes"},
		{http.MethodPost, "/api/notes"},
		{http.MethodPut, "/api/notes"},
		{http.MethodDelete, "/api/notes"},
		{http.MethodGet, "/api/notes/1"},
		{http.MethodDelete, "/api/notes/1"},
		{http.MethodDelete, "/api/notes/abc"},
		{http.MethodPost, "/api/notes/1"},
	}
	for _, header := range []string{"", "Basic dXNlcjpwYXNz", "Bearer", "Bearer a b"} {
		for _, tc := range paths {
			headers := map[string]string{}
			if header != "" {
				headers["Authorization"] = header
			}
			res := ts.do(tc.method, tc.path, "", headers)
			if res.code != http.StatusUnauthorized {
				t.Fatalf("%q %s %s: %d %s", header, tc.method, tc.path, res.code, res.body)
			}
			if www := res.header.Get("WWW-Authenticate"); www != "Bearer" {
				t.Fatalf("%q %s %s WWW-Authenticate: %q", header, tc.method, tc.path, www)
			}
			if got := strings.TrimSpace(res.body); got != `{"error":"unauthorized"}` {
				t.Fatalf("%q %s %s body: %q", header, tc.method, tc.path, got)
			}
		}
	}

	res := ts.authed(http.MethodGet, "/api/notes", "", "not-a-real-token")
	if res.code != http.StatusUnauthorized {
		t.Fatalf("unknown token: %d %s", res.code, res.body)
	}
	if res := ts.authed(http.MethodGet, "/api/notes", "", valid); res.code != http.StatusOK {
		t.Fatalf("valid token: %d %s", res.code, res.body)
	}
}

func TestNotesIsolation(t *testing.T) {
	ts := newTestServer(t)
	tokenA := ts.seedUser("isoa")
	tokenB := ts.seedUser("isob")
	noteA := ts.seedNote(tokenA, "note A")
	noteB := ts.seedNote(tokenB, "note B")

	var listA []Note
	res := ts.authed(http.MethodGet, "/api/notes", "", tokenA)
	if err := json.Unmarshal([]byte(res.body), &listA); err != nil {
		t.Fatalf("decode A: %v", err)
	}
	if len(listA) != 1 || listA[0].ID != noteA.ID || listA[0].Text != noteA.Text {
		t.Fatalf("list A: %+v", listA)
	}
	for _, note := range listA {
		if note.ID == noteB.ID {
			t.Fatalf("A sees B's note: %+v", note)
		}
	}

	var listB []Note
	res = ts.authed(http.MethodGet, "/api/notes", "", tokenB)
	if err := json.Unmarshal([]byte(res.body), &listB); err != nil {
		t.Fatalf("decode B: %v", err)
	}
	if len(listB) != 1 || listB[0].ID != noteB.ID || listB[0].Text != noteB.Text {
		t.Fatalf("list B: %+v", listB)
	}

	if res := ts.authed(http.MethodDelete, "/api/notes/"+strconv.Itoa(noteA.ID), "", tokenB); res.code != http.StatusNotFound {
		t.Fatalf("B deletes A's note: %d %s", res.code, res.body)
	}
	res = ts.authed(http.MethodGet, "/api/notes", "", tokenA)
	if err := json.Unmarshal([]byte(res.body), &listA); err != nil {
		t.Fatal(err)
	}
	if len(listA) != 1 || listA[0].ID != noteA.ID {
		t.Fatalf("A's note disappeared: %+v", listA)
	}
}

func TestDeleteForeignNote(t *testing.T) {
	ts := newTestServer(t)
	owner := ts.seedUser("owner")
	intruder := ts.seedUser("intruder")
	note := ts.seedNote(owner, "private")

	res := ts.authed(http.MethodDelete, "/api/notes/"+strconv.Itoa(note.ID), "", intruder)
	if res.code != http.StatusNotFound || strings.TrimSpace(res.body) != `{"error":"not found"}` {
		t.Fatalf("foreign delete: %d %s", res.code, res.body)
	}
	if res := ts.authed(http.MethodDelete, "/api/notes/"+strconv.Itoa(note.ID), "", owner); res.code != http.StatusNoContent {
		t.Fatalf("owner delete: %d %s", res.code, res.body)
	}
}

func TestNoSecretLeak(t *testing.T) {
	ts := newTestServer(t)
	register := ts.post("/api/register", credentials{Username: "nosecret", Password: "password123"})
	if register.code != http.StatusCreated {
		t.Fatalf("register: %d %s", register.code, register.body)
	}
	login := ts.post("/api/login", credentials{Username: "nosecret", Password: "password123"})
	if login.code != http.StatusOK {
		t.Fatalf("login: %d %s", login.code, login.body)
	}
	var token tokenResponse
	if err := json.Unmarshal([]byte(login.body), &token); err != nil {
		t.Fatal(err)
	}
	created := ts.authed(http.MethodPost, "/api/notes", jsonBody(t, noteRequest{Text: "secret note"}), token.Token)
	if created.code != http.StatusCreated {
		t.Fatalf("add: %d %s", created.code, created.body)
	}
	listed := ts.authed(http.MethodGet, "/api/notes", "", token.Token)
	unauthorized := ts.authed(http.MethodGet, "/api/notes", "", "bad-token")
	badLogin := ts.post("/api/login", credentials{Username: "nosecret", Password: "wrongpassword"})

	responses := []string{
		register.body,
		login.body,
		created.body,
		listed.body,
		unauthorized.body,
		badLogin.body,
	}
	for _, body := range responses {
		for _, secret := range []string{"password", "PasswordHash", `"hash"`, `"salt"`, "user_id", "expires_at"} {
			if strings.Contains(body, secret) {
				t.Fatalf("response leaks %q: %s", secret, body)
			}
		}
	}
	for name, body := range map[string]string{
		"register":     register.body,
		"notes create": created.body,
		"notes list":   listed.body,
		"unauthorized": unauthorized.body,
	} {
		if strings.Contains(body, "token") {
			t.Fatalf("%s body exposes token: %s", name, body)
		}
	}
	if !strings.Contains(login.body, `"token"`) {
		t.Fatalf("login body has no token: %s", login.body)
	}
}
func TestPasswordHashed(t *testing.T) {
	vector := pbkdf2Key([]byte("password"), []byte("salt"), 1, 32)
	if got := hex.EncodeToString(vector); got != "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b" {
		t.Fatalf("pbkdf2 test vector: %s", got)
	}

	salt, hash, err := hashPassword("correct horse battery")
	if err != nil {
		t.Fatalf("hash: %v", err)
	}
	if len(salt) != saltLen || len(hash) != keyLen {
		t.Fatalf("salt/hash lengths: %d/%d", len(salt), len(hash))
	}
	if !verifyPassword("correct horse battery", salt, hash) {
		t.Fatal("correct password rejected")
	}
	if verifyPassword("wrong password", salt, hash) {
		t.Fatal("wrong password accepted")
	}
	if again := pbkdf2Key([]byte("correct horse battery"), salt, pbkdf2Iterations, keyLen); !bytes.Equal(again, hash) {
		t.Fatal("pbkdf2 is not deterministic for the same salt")
	}

	salt2, hash2, err := hashPassword("correct horse battery")
	if err != nil {
		t.Fatalf("hash 2: %v", err)
	}
	if bytes.Equal(salt, salt2) {
		t.Fatal("salt reused")
	}
	if bytes.Equal(hash, hash2) {
		t.Fatal("hash reused across salts")
	}

	ts := newTestServer(t)
	ts.seedUser("hashed")
	ts.seedUser("hashed2")
	first := ts.user("hashed")
	second := ts.user("hashed2")
	if first == nil || second == nil {
		t.Fatal("seeded users missing")
	}
	if len(first.Salt) != saltLen || len(first.PasswordHash) != keyLen {
		t.Fatalf("stored salt/hash: %d/%d", len(first.Salt), len(first.PasswordHash))
	}
	if bytes.Equal(first.Salt, second.Salt) {
		t.Fatal("users share a salt")
	}
	if bytes.Contains(first.PasswordHash, []byte("password123")) || string(first.PasswordHash) == "password123" {
		t.Fatal("plaintext password stored")
	}
}

func TestTokenExpiry(t *testing.T) {
	ts := newTestServer(t)
	var offset atomic.Int64
	base := time.Now()
	ts.useClock(func() time.Time { return base.Add(time.Duration(offset.Load())) })

	token := ts.seedUser("expiry")
	if res := ts.authed(http.MethodGet, "/api/notes", "", token); res.code != http.StatusOK {
		t.Fatalf("fresh token: %d %s", res.code, res.body)
	}

	offset.Store(int64(23 * time.Hour))
	if res := ts.authed(http.MethodGet, "/api/notes", "", token); res.code != http.StatusOK {
		t.Fatalf("token before TTL: %d %s", res.code, res.body)
	}

	offset.Store(int64(24 * time.Hour))
	res := ts.authed(http.MethodGet, "/api/notes", "", token)
	if res.code != http.StatusUnauthorized {
		t.Fatalf("expired token: %d %s", res.code, res.body)
	}
	if www := res.header.Get("WWW-Authenticate"); www != "Bearer" {
		t.Fatalf("expired WWW-Authenticate: %q", www)
	}
	if count := ts.sessionCount(); count != 0 {
		t.Fatalf("expired session not removed: %d", count)
	}
	if res := ts.authed(http.MethodGet, "/api/notes", "", token); res.code != http.StatusUnauthorized {
		t.Fatalf("expired token reuse: %d %s", res.code, res.body)
	}
}

func TestWireContract(t *testing.T) {
	ts := newTestServer(t)
	register := ts.post("/api/register", credentials{Username: "wire", Password: "password123"})
	assertKeys(t, register.body, "id", "username")

	login := ts.post("/api/login", credentials{Username: "wire", Password: "password123"})
	obj := assertKeys(t, login.body, "token")
	var token string
	if err := json.Unmarshal(obj["token"], &token); err != nil {
		t.Fatal(err)
	}

	created := ts.authed(http.MethodPost, "/api/notes", jsonBody(t, noteRequest{Text: "wire note"}), token)
	assertKeys(t, created.body, "id", "text")

	listed := ts.authed(http.MethodGet, "/api/notes", "", token)
	var items []map[string]json.RawMessage
	if err := json.Unmarshal([]byte(listed.body), &items); err != nil {
		t.Fatalf("decode list: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("items: %d", len(items))
	}
	if len(items[0]) != 2 {
		t.Fatalf("note keys: %v", items[0])
	}
	for _, key := range []string{"id", "text"} {
		if _, ok := items[0][key]; !ok {
			t.Fatalf("note missing %q: %s", key, listed.body)
		}
	}

	emptyToken := ts.seedUser("wireempty")
	if got := strings.TrimSpace(ts.authed(http.MethodGet, "/api/notes", "", emptyToken).body); got != "[]" {
		t.Fatalf("empty list wire form: %q", got)
	}

	errorBody := ts.authed(http.MethodDelete, "/api/notes/nope", "", token)
	assertKeys(t, errorBody.body, "error")
}

func TestHTTPTransport(t *testing.T) {
	ts := newTestServer(t)
	if !strings.HasPrefix(ts.srv.URL, "http://") {
		t.Fatalf("test server URL: %q", ts.srv.URL)
	}

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(ts.srv.URL + "/healthz")
	if err != nil {
		t.Fatalf("healthz over HTTP: %v", err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("read healthz: %v", err)
	}
	if resp.StatusCode != http.StatusOK || strings.TrimSpace(string(body)) != "ok" {
		t.Fatalf("healthz: %d %q", resp.StatusCode, body)
	}

	register := ts.post("/api/register", credentials{Username: "transport", Password: "password123"})
	if register.code != http.StatusCreated {
		t.Fatalf("register over HTTP: %d %s", register.code, register.body)
	}
}

func TestNotesPrefixBoundary(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("prefix")
	note := ts.seedNote(token, "boundary")

	for _, path := range []string{
		"/api/notes/",
		"/api/notes/" + strconv.Itoa(note.ID) + "/extra",
	} {
		res := ts.authed(http.MethodDelete, path, "", token)
		if res.code != http.StatusBadRequest || strings.TrimSpace(res.body) != `{"error":"invalid id"}` {
			t.Fatalf("delete %q: %d %s", path, res.code, res.body)
		}
	}

	res := ts.authed(http.MethodGet, "/api/notes", "", token)
	var notes []Note
	if err := json.Unmarshal([]byte(res.body), &notes); err != nil {
		t.Fatal(err)
	}
	if len(notes) != 1 || notes[0].ID != note.ID {
		t.Fatalf("prefix boundary removed a note: %+v", notes)
	}
}

func TestAuthMethodOrder(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("order")
	note := ts.seedNote(token, "ordered")

	for _, tc := range []struct {
		method string
		path   string
	}{
		{http.MethodPut, "/api/notes"},
		{http.MethodPost, "/api/notes"},
		{http.MethodDelete, "/api/notes/abc"},
		{http.MethodGet, "/api/notes/abc"},
		{http.MethodPost, "/api/notes/" + strconv.Itoa(note.ID)},
	} {
		res := ts.do(tc.method, tc.path, "", nil)
		if res.code != http.StatusUnauthorized {
			t.Fatalf("%s %s without auth: %d %s", tc.method, tc.path, res.code, res.body)
		}
		if www := res.header.Get("WWW-Authenticate"); www != "Bearer" {
			t.Fatalf("%s %s WWW-Authenticate: %q", tc.method, tc.path, www)
		}
	}

	res := ts.authed(http.MethodPut, "/api/notes", "", token)
	if res.code != http.StatusMethodNotAllowed || res.header.Get("Allow") != "GET, POST" {
		t.Fatalf("authed PUT collection: %d Allow=%q", res.code, res.header.Get("Allow"))
	}
	res = ts.authed(http.MethodGet, "/api/notes/abc", "", token)
	if res.code != http.StatusMethodNotAllowed || res.header.Get("Allow") != "DELETE" {
		t.Fatalf("authed GET item: %d Allow=%q", res.code, res.header.Get("Allow"))
	}
	res = ts.authed(http.MethodDelete, "/api/notes/abc", "", token)
	if res.code != http.StatusBadRequest || strings.TrimSpace(res.body) != `{"error":"invalid id"}` {
		t.Fatalf("authed DELETE invalid id: %d %s", res.code, res.body)
	}
}

func TestDeleteInvalidID(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("badid")
	for _, raw := range []string{"abc", "", "999999999999999999999999"} {
		res := ts.authed(http.MethodDelete, "/api/notes/"+raw, "", token)
		if res.code != http.StatusBadRequest || strings.TrimSpace(res.body) != `{"error":"invalid id"}` {
			t.Fatalf("delete %q: %d %s", raw, res.code, res.body)
		}
	}
	res := ts.authed(http.MethodDelete, "/api/notes/-1", "", token)
	if res.code != http.StatusBadRequest && res.code != http.StatusNotFound {
		t.Fatalf("delete negative: %d %s", res.code, res.body)
	}
}

func TestDeleteMissing(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("missing")
	res := ts.authed(http.MethodDelete, "/api/notes/999", "", token)
	if res.code != http.StatusNotFound || strings.TrimSpace(res.body) != `{"error":"not found"}` {
		t.Fatalf("delete missing: %d %s", res.code, res.body)
	}
}

func TestDeleteExisting(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("existing")
	note := ts.seedNote(token, "x")
	res := ts.authed(http.MethodDelete, "/api/notes/"+strconv.Itoa(note.ID), "", token)
	if res.code != http.StatusNoContent {
		t.Fatalf("delete existing: %d %s", res.code, res.body)
	}
	res = ts.authed(http.MethodGet, "/api/notes", "", token)
	if got := strings.TrimSpace(res.body); got != "[]" {
		t.Fatalf("list after delete: %q", got)
	}
}

func TestListAfterDelete(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("listdel")
	keep := ts.seedNote(token, "keep")
	drop := ts.seedNote(token, "drop")

	res := ts.authed(http.MethodDelete, "/api/notes/"+strconv.Itoa(drop.ID), "", token)
	if res.code != http.StatusNoContent {
		t.Fatalf("delete: %d %s", res.code, res.body)
	}
	res = ts.authed(http.MethodGet, "/api/notes", "", token)
	var notes []Note
	if err := json.Unmarshal([]byte(res.body), &notes); err != nil {
		t.Fatal(err)
	}
	if len(notes) != 1 || notes[0].ID != keep.ID || notes[0].Text != "keep" {
		t.Fatalf("list after delete: %+v", notes)
	}
}

func TestAddNote(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("addnote")

	res := ts.authed(http.MethodPost, "/api/notes", jsonBody(t, noteRequest{Text: "a"}), token)
	if res.code != http.StatusCreated {
		t.Fatalf("add: %d %s", res.code, res.body)
	}
	var note Note
	if err := json.Unmarshal([]byte(res.body), &note); err != nil {
		t.Fatal(err)
	}
	if note.ID != 1 || note.Text != "a" {
		t.Fatalf("note: %+v", note)
	}

	for _, body := range []string{
		`{"text":""}`,
		`{"text":"   "}`,
		`{"text":"\n\t"}`,
		jsonBody(t, noteRequest{Text: strings.Repeat("a", maxTextBytes+1)}),
	} {
		res := ts.authed(http.MethodPost, "/api/notes", body, token)
		if res.code != http.StatusBadRequest || strings.TrimSpace(res.body) != `{"error":"text required"}` {
			t.Fatalf("add %q: %d %s", body, res.code, res.body)
		}
	}

	if res := ts.authed(http.MethodPost, "/api/notes", jsonBody(t, noteRequest{Text: strings.Repeat("a", maxTextBytes)}), token); res.code != http.StatusCreated {
		t.Fatalf("add max length: %d %s", res.code, res.body)
	}

	for _, body := range []string{`{}`, `{`, `{"text":123}`} {
		res := ts.authed(http.MethodPost, "/api/notes", body, token)
		if res.code != http.StatusBadRequest {
			t.Fatalf("add malformed %q: %d %s", body, res.code, res.body)
		}
	}

	oversized := `{"text":"` + strings.Repeat("a", maxBodyBytes) + `"}`
	res = ts.authed(http.MethodPost, "/api/notes", oversized, token)
	if res.code != http.StatusBadRequest || strings.TrimSpace(res.body) != `{"error":"invalid request body"}` {
		t.Fatalf("add oversized: %d %s", res.code, res.body)
	}
}

func TestUnknownAPINotFound(t *testing.T) {
	ts := newTestServer(t)
	res := ts.do(http.MethodGet, "/api/unknown", "", nil)
	if res.code != http.StatusNotFound || strings.TrimSpace(res.body) != `{"error":"not found"}` {
		t.Fatalf("unknown api: %d %s", res.code, res.body)
	}
	if ct := res.header.Get("Content-Type"); ct != "application/json" {
		t.Fatalf("unknown api content-type: %q", ct)
	}
}

// decodeNotes parses a notes collection response into typed notes.
func decodeNotes(t *testing.T, body string) []Note {
	t.Helper()
	var notes []Note
	if err := json.Unmarshal([]byte(body), &notes); err != nil {
		t.Fatalf("decode notes %q: %v", body, err)
	}
	return notes
}

// assertNoteTexts checks the filtered result set and its insertion order.
func assertNoteTexts(t *testing.T, notes []Note, want ...string) {
	t.Helper()
	if len(notes) != len(want) {
		t.Fatalf("notes: got %d %+v, want %d %v", len(notes), notes, len(want), want)
	}
	for i, text := range want {
		if notes[i].Text != text {
			t.Fatalf("note %d: got %q, want %q", i, notes[i].Text, text)
		}
	}
}

func TestNotesSearchFinds(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("searchfind")
	ts.seedNote(token, "buy bread")
	ts.seedNote(token, "buy milk")
	ts.seedNote(token, "call mom")

	res := ts.authed(http.MethodGet, "/api/notes?q=bread", "", token)
	if res.code != http.StatusOK {
		t.Fatalf("search: %d %s", res.code, res.body)
	}
	assertNoteTexts(t, decodeNotes(t, res.body), "buy bread")
}

func TestNotesSearchNotFound(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("searchmiss")
	ts.seedNote(token, "buy bread")

	res := ts.authed(http.MethodGet, "/api/notes?q=absent", "", token)
	if res.code != http.StatusOK {
		t.Fatalf("search miss: %d %s", res.code, res.body)
	}
	if got := strings.TrimSpace(res.body); got != "[]" {
		t.Fatalf("search miss body: %q (want [])", got)
	}
}

func TestNotesSearchCaseInsensitive(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("searchcase")
	ts.seedNote(token, "Hello World")
	ts.seedNote(token, "hello there")
	ts.seedNote(token, "GO lang")

	res := ts.authed(http.MethodGet, "/api/notes?q=HeLLo", "", token)
	if res.code != http.StatusOK {
		t.Fatalf("case-insensitive search: %d %s", res.code, res.body)
	}
	assertNoteTexts(t, decodeNotes(t, res.body), "Hello World", "hello there")
}

func TestNotesSearchIsolation(t *testing.T) {
	ts := newTestServer(t)
	tokenA := ts.seedUser("searchisoa")
	tokenB := ts.seedUser("searchisob")
	noteA := ts.seedNote(tokenA, "alpha shared")
	noteB := ts.seedNote(tokenB, "beta shared")

	resA := ts.authed(http.MethodGet, "/api/notes?q=shared", "", tokenA)
	if resA.code != http.StatusOK {
		t.Fatalf("search A: %d %s", resA.code, resA.body)
	}
	notesA := decodeNotes(t, resA.body)
	assertNoteTexts(t, notesA, noteA.Text)
	for _, note := range notesA {
		if note.ID == noteB.ID {
			t.Fatalf("A's search leaked B's note: %+v", note)
		}
	}

	resB := ts.authed(http.MethodGet, "/api/notes?q=shared", "", tokenB)
	if resB.code != http.StatusOK {
		t.Fatalf("search B: %d %s", resB.code, resB.body)
	}
	notesB := decodeNotes(t, resB.body)
	assertNoteTexts(t, notesB, noteB.Text)
	for _, note := range notesB {
		if note.ID == noteA.ID {
			t.Fatalf("B's search leaked A's note: %+v", note)
		}
	}

	// UserID must stay out of the wire payload even when filtering.
	for _, leak := range []string{"user_id", "UserID", `"userId"`} {
		if strings.Contains(resA.body, leak) {
			t.Fatalf("search response leaks %q: %s", leak, resA.body)
		}
	}
}

func TestNotesSearchAuthRequired(t *testing.T) {
	ts := newTestServer(t)
	res := ts.do(http.MethodGet, "/api/notes?q=secret", "", nil)
	if res.code != http.StatusUnauthorized {
		t.Fatalf("search without auth: %d %s", res.code, res.body)
	}
	if www := res.header.Get("WWW-Authenticate"); www != "Bearer" {
		t.Fatalf("search WWW-Authenticate: %q", www)
	}
	if got := strings.TrimSpace(res.body); got != `{"error":"unauthorized"}` {
		t.Fatalf("search body: %q", got)
	}

	res = ts.authed(http.MethodGet, "/api/notes?q=secret", "", "not-a-real-token")
	if res.code != http.StatusUnauthorized {
		t.Fatalf("search with unknown token: %d %s", res.code, res.body)
	}
}

func TestNotesSearchEmptyQuery(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("searchempty")
	ts.seedNote(token, "first note")
	ts.seedNote(token, "second note")

	res := ts.authed(http.MethodGet, "/api/notes?q=", "", token)
	if res.code != http.StatusOK {
		t.Fatalf("empty q: %d %s", res.code, res.body)
	}
	assertNoteTexts(t, decodeNotes(t, res.body), "first note", "second note")

	base := ts.authed(http.MethodGet, "/api/notes", "", token)
	if base.body != res.body {
		t.Fatalf("empty q changed output: %q vs %q", res.body, base.body)
	}
}

func TestNotesSearchWhitespaceQuery(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("searchspace")
	ts.seedNote(token, "first note")
	ts.seedNote(token, "second note")

	for _, path := range []string{
		"/api/notes?q=%20%20%09",
		"/api/notes?q=%20",
	} {
		res := ts.authed(http.MethodGet, path, "", token)
		if res.code != http.StatusOK {
			t.Fatalf("whitespace q %q: %d %s", path, res.code, res.body)
		}
		assertNoteTexts(t, decodeNotes(t, res.body), "first note", "second note")
	}
}

func TestNotesSearchEncoding(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("searchenc")
	ts.seedNote(token, "100% juice & tea")
	ts.seedNote(token, "a+b test")

	for _, tc := range []struct {
		name  string
		query string
		want  string
	}{
		{"percent", "/api/notes?q=100%25", "100% juice & tea"},
		{"space", "/api/notes?q=100%25%20juice", "100% juice & tea"},
		{"ampersand", "/api/notes?q=%26", "100% juice & tea"},
		{"plus", "/api/notes?q=a%2Bb", "a+b test"},
	} {
		res := ts.authed(http.MethodGet, tc.query, "", token)
		if res.code != http.StatusOK {
			t.Fatalf("%s: %d %s", tc.name, res.code, res.body)
		}
		assertNoteTexts(t, decodeNotes(t, res.body), tc.want)
	}
}

func TestNotesSearchQueryTooLong(t *testing.T) {
	ts := newTestServer(t)
	token := ts.seedUser("searchlong")
	ts.seedNote(token, "buy bread")

	res := ts.authed(http.MethodGet, "/api/notes?q="+strings.Repeat("a", maxQueryBytes+1), "", token)
	if res.code != http.StatusBadRequest {
		t.Fatalf("long query: %d %s", res.code, res.body)
	}
	if !strings.Contains(res.body, "query too long") {
		t.Fatalf("long query body: %q", res.body)
	}
}

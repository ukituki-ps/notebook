package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
)

func TestNotesLifecycle(t *testing.T) {
	s := NewStore()
	h := handler(s)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("health: %d", rec.Code)
	}

	body := bytes.NewBufferString(`{"text":"купить хлеб"}`)
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/api/notes", body))
	if rec.Code != http.StatusCreated {
		t.Fatalf("post: %d %s", rec.Code, rec.Body.String())
	}
	var n Note
	if err := json.Unmarshal(rec.Body.Bytes(), &n); err != nil {
		t.Fatal(err)
	}
	if n.ID != 1 || n.Text != "купить хлеб" {
		t.Fatalf("note: %+v", n)
	}

	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/notes", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("list: %d", rec.Code)
	}
	var notes []Note
	if err := json.Unmarshal(rec.Body.Bytes(), &notes); err != nil {
		t.Fatal(err)
	}
	if len(notes) != 1 {
		t.Fatalf("notes: %+v", notes)
	}
}

func TestDeleteNote(t *testing.T) {
	s := NewStore()
	h := handler(s)
	seed := func(text string) int {
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/api/notes", bytes.NewBufferString(`{"text":"`+text+`"}`)))
		if rec.Code != http.StatusCreated {
			t.Fatalf("seed: %d %s", rec.Code, rec.Body.String())
		}
		var n Note
		if err := json.Unmarshal(rec.Body.Bytes(), &n); err != nil {
			t.Fatal(err)
		}
		return n.ID
	}
	id := seed("удалить меня")
	seed("оставить меня")

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodDelete, "/api/notes/"+strconv.Itoa(id), nil))
	if rec.Code != http.StatusNoContent {
		t.Fatalf("delete existing: %d %s", rec.Code, rec.Body.String())
	}

	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodDelete, "/api/notes/"+strconv.Itoa(id), nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("delete missing: %d", rec.Code)
	}

	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodDelete, "/api/notes/abc", nil))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("delete non-numeric: %d", rec.Code)
	}

	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/notes", nil))
	var notes []Note
	if err := json.Unmarshal(rec.Body.Bytes(), &notes); err != nil {
		t.Fatal(err)
	}
	if len(notes) != 1 || notes[0].Text != "оставить меня" {
		t.Fatalf("list after delete: %+v", notes)
	}
}
// mustSeedNote creates one note and returns its id.
func mustSeedNote(t *testing.T, h http.Handler, text string) int {
	t.Helper()
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/api/notes", bytes.NewBufferString(`{"text":"`+text+`"}`)))
	if rec.Code != http.StatusCreated {
		t.Fatalf("seed: %d %s", rec.Code, rec.Body.String())
	}
	var n Note
	if err := json.Unmarshal(rec.Body.Bytes(), &n); err != nil {
		t.Fatal(err)
	}
	return n.ID
}

// TestAddNote pins the POST /api/notes contract (201 + Note body).
func TestAddNote(t *testing.T) {
	h := handler(NewStore())
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/api/notes", bytes.NewBufferString(`{"text":"a"}`)))
	if rec.Code != http.StatusCreated {
		t.Fatalf("add: %d %s", rec.Code, rec.Body.String())
	}
	var n Note
	if err := json.Unmarshal(rec.Body.Bytes(), &n); err != nil {
		t.Fatal(err)
	}
	if n.ID != 1 || n.Text != "a" {
		t.Fatalf("note: %+v", n)
	}
}

// TestDeleteExisting pins DELETE existing -> 204 and absence from List.
func TestDeleteExisting(t *testing.T) {
	h := handler(NewStore())
	id := mustSeedNote(t, h, "x")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodDelete, "/api/notes/"+strconv.Itoa(id), nil))
	if rec.Code != http.StatusNoContent {
		t.Fatalf("delete existing: %d %s", rec.Code, rec.Body.String())
	}
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/notes", nil))
	var notes []Note
	if err := json.Unmarshal(rec.Body.Bytes(), &notes); err != nil {
		t.Fatal(err)
	}
	if len(notes) != 0 {
		t.Fatalf("list after delete: %+v", notes)
	}
}

// TestDeleteMissing pins DELETE unknown -> 404 with the documented envelope.
func TestDeleteMissing(t *testing.T) {
	h := handler(NewStore())
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodDelete, "/api/notes/999", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("delete missing: %d", rec.Code)
	}
	if got := strings.TrimSpace(rec.Body.String()); got != `{"error":"not found"}` {
		t.Fatalf("missing body: %q", got)
	}
}

// TestDeleteInvalidID pins 400 for non-numeric/empty/overflow ids, and
// 400/404 (no panic) for negative ids, with the documented error envelope.
func TestDeleteInvalidID(t *testing.T) {
	h := handler(NewStore())
	for _, raw := range []string{"abc", "", "999999999999999999999999"} {
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest(http.MethodDelete, "/api/notes/"+raw, nil))
		if rec.Code != http.StatusBadRequest {
			t.Fatalf("delete %q: %d", raw, rec.Code)
		}
		if got := strings.TrimSpace(rec.Body.String()); got != `{"error":"invalid id"}` {
			t.Fatalf("delete %q body: %q", raw, got)
		}
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodDelete, "/api/notes/-1", nil))
	if rec.Code != http.StatusNotFound && rec.Code != http.StatusBadRequest {
		t.Fatalf("delete negative: %d", rec.Code)
	}
}

// TestListAfterDelete pins that List returns exactly the remaining notes.
func TestListAfterDelete(t *testing.T) {
	h := handler(NewStore())
	id := mustSeedNote(t, h, "keep")
	mustSeedNote(t, h, "drop")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodDelete, "/api/notes/"+strconv.Itoa(id+1), nil))
	if rec.Code != http.StatusNoContent {
		t.Fatalf("delete: %d", rec.Code)
	}
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/notes", nil))
	var notes []Note
	if err := json.Unmarshal(rec.Body.Bytes(), &notes); err != nil {
		t.Fatal(err)
	}
	if len(notes) != 1 || notes[0].Text != "keep" {
		t.Fatalf("list after delete: %+v", notes)
	}
}

// TestNotesMethodNotAllowed pins write-verb rejection (405) on the item path.
func TestNotesMethodNotAllowed(t *testing.T) {
	h := handler(NewStore())
	id := mustSeedNote(t, h, "x")
	for _, m := range []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodPatch} {
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest(m, "/api/notes/"+strconv.Itoa(id), nil))
		if rec.Code != http.StatusMethodNotAllowed {
			t.Fatalf("%s item: %d", m, rec.Code)
		}
		if got := strings.TrimSpace(rec.Body.String()); got != `{"error":"method not allowed"}` {
			t.Fatalf("%s body: %q", m, got)
		}
	}
}

// TestDeleteErrorEnvelope pins that error bodies are the documented generic
// strings (no internal detail/stack leak) for 400 and 404.
func TestDeleteErrorEnvelope(t *testing.T) {
	h := handler(NewStore())
	for _, tc := range []struct {
		path string
		code int
		body string
	}{
		{"/api/notes/abc", http.StatusBadRequest, `{"error":"invalid id"}`},
		{"/api/notes/999", http.StatusNotFound, `{"error":"not found"}`},
	} {
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest(http.MethodDelete, tc.path, nil))
		got := strings.TrimSpace(rec.Body.String())
		if rec.Code != tc.code || got != tc.body {
			t.Fatalf("delete %s: %d %q (want %d %q)", tc.path, rec.Code, got, tc.code, tc.body)
		}
		for _, leak := range []string{"strconv", "panic", "goroutine", "main.go"} {
			if strings.Contains(got, leak) {
				t.Fatalf("delete %s leaks %q: %q", tc.path, leak, got)
			}
		}
	}
}

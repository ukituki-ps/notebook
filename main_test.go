package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestNotesLifecycle(t *testing.T) {
	s := NewStore()
	h := handler(s)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if rec.Code != http.StatusOK { t.Fatalf("health: %d", rec.Code) }

	body := bytes.NewBufferString(`{"text":"купить хлеб"}`)
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/api/notes", body))
	if rec.Code != http.StatusCreated { t.Fatalf("post: %d %s", rec.Code, rec.Body.String()) }
	var n Note
	if err := json.Unmarshal(rec.Body.Bytes(), &n); err != nil { t.Fatal(err) }
	if n.ID != 1 || n.Text != "купить хлеб" { t.Fatalf("note: %+v", n) }

	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/notes", nil))
	if rec.Code != http.StatusOK { t.Fatalf("list: %d", rec.Code) }
	var notes []Note
	if err := json.Unmarshal(rec.Body.Bytes(), &notes); err != nil { t.Fatal(err) }
	if len(notes) != 1 { t.Fatalf("notes: %+v", notes) }
}

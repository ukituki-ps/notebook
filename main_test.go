package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
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

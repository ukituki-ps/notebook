package main

import (
	"embed"
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"strings"
	"sync"
)

// Static UI assets. Explicit patterns (not "web/") keep web/e2e and any
// tooling files out of the binary.
//
//go:embed web/index.html web/app.js web/app.css
var webFS embed.FS

type Note struct {
	ID   int    `json:"id"`
	Text string `json:"text"`
}

type Store struct {
	mu    sync.Mutex
	next  int
	notes []Note
}

func NewStore() *Store { return &Store{next: 1} }

func (s *Store) List() []Note {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]Note, len(s.notes))
	copy(out, s.notes)
	return out
}

func (s *Store) Add(text string) Note {
	s.mu.Lock()
	defer s.mu.Unlock()
	n := Note{ID: s.next, Text: text}
	s.next++
	s.notes = append(s.notes, n)
	return n
}

// Delete removes the note with the given id. It reports whether a note was
// removed; the id space is not reused (next stays monotonic).
func (s *Store) Delete(id int) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i, n := range s.notes {
		if n.ID == id {
			s.notes = append(s.notes[:i], s.notes[i+1:]...)
			return true
		}
	}
	return false
}

func handler(s *Store) http.Handler {
	mux := http.NewServeMux()

	// ---- static UI (embed only; API paths are untouched) ----
	serveAsset := func(name, contentType string) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			if r.Method != http.MethodGet && r.Method != http.MethodHead {
				w.Header().Set("Allow", "GET, HEAD")
				http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
				return
			}
			data, err := webFS.ReadFile(name)
			if err != nil {
				http.NotFound(w, r)
				return
			}
			w.Header().Set("Content-Type", contentType)
			w.Header().Set("Cache-Control", "no-store")
			w.WriteHeader(http.StatusOK)
			if r.Method != http.MethodHead {
				_, _ = w.Write(data)
			}
		}
	}
	serveIndex := func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			w.Header().Set("Allow", "GET, HEAD")
			http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
			return
		}
		data, err := webFS.ReadFile("web/index.html")
		if err != nil {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Header().Set("Cache-Control", "no-store")
		w.WriteHeader(http.StatusOK)
		if r.Method != http.MethodHead {
			_, _ = w.Write(data)
		}
	}

	mux.HandleFunc("/app.js", serveAsset("web/app.js", "text/javascript; charset=utf-8"))
	mux.HandleFunc("/app.css", serveAsset("web/app.css", "text/css; charset=utf-8"))
	for _, page := range []string{"/login", "/register", "/notes"} {
		mux.HandleFunc(page, serveIndex)
	}
	// Root redirect; unknown paths must not fall through to the SPA shell.
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Cache-Control", "no-store")
		http.Redirect(w, r, "/login", http.StatusFound)
	})

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
	})
	mux.HandleFunc("/api/notes", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.Method {
		case http.MethodGet:
			_ = json.NewEncoder(w).Encode(s.List())
		case http.MethodPost:
			var req struct {
				Text string `json:"text"`
			}
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Text == "" {
				http.Error(w, `{"error":"text required"}`, http.StatusBadRequest)
				return
			}
			w.WriteHeader(http.StatusCreated)
			_ = json.NewEncoder(w).Encode(s.Add(req.Text))
		default:
			http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		}
	})
	// DELETE /api/notes/{id} — 204 on success, 400 for a non-integer id,
	// 404 when the note does not exist.
	mux.HandleFunc("/api/notes/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodDelete {
			http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
			return
		}
		raw := strings.TrimPrefix(r.URL.Path, "/api/notes/")
		id, err := strconv.Atoi(raw)
		if err != nil || raw == "" {
			http.Error(w, `{"error":"invalid id"}`, http.StatusBadRequest)
			return
		}
		if !s.Delete(id) {
			http.Error(w, `{"error":"not found"}`, http.StatusNotFound)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	})
	return mux
}

func main() {
	log.Fatal(http.ListenAndServe(":8080", handler(NewStore())))
}

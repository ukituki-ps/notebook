package main

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
)

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

func handler(s *Store) http.Handler {
	mux := http.NewServeMux()
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
			var req struct{ Text string `json:"text"` }
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
	return mux
}

func main() {
	log.Fatal(http.ListenAndServe(":8080", handler(NewStore())))
}

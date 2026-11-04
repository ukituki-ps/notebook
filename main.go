package main

import (
	"crypto/hmac"
	"embed"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode/utf8"
)

// Static UI assets. Explicit patterns keep web/e2e out of the binary.
//
//go:embed web/index.html web/app.js web/app.css
var webFS embed.FS

const (
	maxBodyBytes = 1 << 20
	saltLen      = 16
	keyLen       = 32
	sessionTTL   = 24 * time.Hour
	maxTextBytes = 4096
)

// pbkdf2Iterations is the PBKDF2 work factor. Tests may lower it temporarily.
var pbkdf2Iterations = 210000

// now is the default clock for new stores. Tests override Store.now to make
// token expiry deterministic.
var now = time.Now

// dummySalt keeps unknown-user logins as expensive as real password checks.
var dummySalt = []byte{
	0x9e, 0x37, 0x79, 0xb9, 0x7f, 0x4a, 0x7c, 0x15,
	0x22, 0x64, 0x0b, 0x2f, 0x8d, 0x61, 0x43, 0x9c,
}

var (
	errUsernameTaken = errors.New("username taken")
	errUnauthorized  = errors.New("unauthorized")
)

type User struct {
	ID           int    `json:"id"`
	Username     string `json:"username"`
	Salt         []byte `json:"-"`
	PasswordHash []byte `json:"-"`
}

type Session struct {
	Token     string    `json:"-"`
	UserID    int       `json:"-"`
	ExpiresAt time.Time `json:"-"`
}

type Note struct {
	ID     int    `json:"id"`
	UserID int    `json:"-"`
	Text   string `json:"text"`
}

type Store struct {
	mu    sync.Mutex
	regMu sync.Mutex
	now   func() time.Time

	nextUser int
	nextNote int

	usersByID   map[int]*User
	usersByName map[string]*User
	sessions    map[string]*Session
	notes       map[int]Note
	noteOrder   []int
}

func NewStore() *Store {
	return &Store{
		now:         now,
		nextUser:    1,
		nextNote:    1,
		usersByID:   make(map[int]*User),
		usersByName: make(map[string]*User),
		sessions:    make(map[string]*Session),
		notes:       make(map[int]Note),
	}
}

// currentTime reads the store clock under the mutex so tests can swap it
// between requests without a data race.
func (s *Store) currentTime() time.Time {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.now()
}

// CreateUser hashes the password outside Store.mu while holding regMu for the
// whole check-hash-insert sequence, which prevents duplicate registrations.
func (s *Store) CreateUser(username, password string) (User, error) {
	s.regMu.Lock()
	defer s.regMu.Unlock()

	s.mu.Lock()
	_, exists := s.usersByName[username]
	s.mu.Unlock()
	if exists {
		return User{}, errUsernameTaken
	}

	salt, hash, err := hashPassword(password)
	if err != nil {
		return User{}, err
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	user := User{
		ID:           s.nextUser,
		Username:     username,
		Salt:         salt,
		PasswordHash: hash,
	}
	s.nextUser++
	s.usersByID[user.ID] = &user
	s.usersByName[user.Username] = &user
	return user, nil
}

// Authenticate verifies credentials and creates a new opaque session token.
// Password work happens outside Store.mu.
func (s *Store) Authenticate(username, password string) (Session, error) {
	s.mu.Lock()
	user := s.usersByName[username]
	var salt, hash []byte
	var userID int
	if user != nil {
		salt = user.Salt
		hash = user.PasswordHash
		userID = user.ID
	}
	s.mu.Unlock()

	if user == nil {
		_ = pbkdf2Key([]byte(password), dummySalt, pbkdf2Iterations, keyLen)
		return Session{}, errUnauthorized
	}
	if !verifyPassword(password, salt, hash) {
		return Session{}, errUnauthorized
	}

	token, err := newToken()
	if err != nil {
		return Session{}, err
	}
	session := Session{
		Token:     token,
		UserID:    userID,
		ExpiresAt: s.currentTime().Add(sessionTTL),
	}

	s.mu.Lock()
	s.sessions[token] = &session
	s.mu.Unlock()
	return session, nil
}

// SessionByToken resolves a bearer token and lazily drops expired sessions.
func (s *Store) SessionByToken(token string) (Session, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	session, ok := s.sessions[token]
	if !ok {
		return Session{}, false
	}
	if !s.now().Before(session.ExpiresAt) {
		delete(s.sessions, token)
		return Session{}, false
	}
	return *session, true
}

// ListNotes returns the user's notes in insertion order. The result is never
// nil so an empty list emits [] rather than null.
func (s *Store) ListNotes(userID int) []Note {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]Note, 0)
	for _, id := range s.noteOrder {
		note := s.notes[id]
		if note.UserID == userID {
			out = append(out, note)
		}
	}
	return out
}

func (s *Store) AddNote(userID int, text string) Note {
	s.mu.Lock()
	defer s.mu.Unlock()
	note := Note{ID: s.nextNote, UserID: userID, Text: text}
	s.nextNote++
	s.notes[note.ID] = note
	s.noteOrder = append(s.noteOrder, note.ID)
	return note
}

// DeleteNote removes the note only when it belongs to userID. Missing and
// foreign notes are indistinguishable to the caller.
func (s *Store) DeleteNote(userID, noteID int) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	note, ok := s.notes[noteID]
	if !ok || note.UserID != userID {
		return false
	}
	delete(s.notes, noteID)
	for i, id := range s.noteOrder {
		if id == noteID {
			s.noteOrder = append(s.noteOrder[:i], s.noteOrder[i+1:]...)
			break
		}
	}
	return true
}

// pbkdf2Key implements PBKDF2-HMAC-SHA256 on the standard library only.
func pbkdf2Key(password, salt []byte, iterations, keyLen int) []byte {
	prf := hmac.New(sha256.New, password)
	hashLen := prf.Size()
	numBlocks := (keyLen + hashLen - 1) / hashLen
	dk := make([]byte, 0, numBlocks*hashLen)
	u := make([]byte, hashLen)
	var block [4]byte
	for i := 1; i <= numBlocks; i++ {
		prf.Reset()
		_, _ = prf.Write(salt)
		binary.BigEndian.PutUint32(block[:], uint32(i))
		_, _ = prf.Write(block[:])
		u = prf.Sum(u[:0])
		t := make([]byte, hashLen)
		copy(t, u)
		for n := 2; n <= iterations; n++ {
			prf.Reset()
			_, _ = prf.Write(u)
			u = prf.Sum(u[:0])
			for x := range t {
				t[x] ^= u[x]
			}
		}
		dk = append(dk, t...)
	}
	return dk[:keyLen]
}

func hashPassword(password string) (salt, hash []byte, err error) {
	salt = make([]byte, saltLen)
	if _, err := rand.Read(salt); err != nil {
		return nil, nil, err
	}
	return salt, pbkdf2Key([]byte(password), salt, pbkdf2Iterations, keyLen), nil
}

func verifyPassword(password string, salt, hash []byte) bool {
	candidate := pbkdf2Key([]byte(password), salt, pbkdf2Iterations, keyLen)
	return subtle.ConstantTimeCompare(candidate, hash) == 1
}

func newToken() (string, error) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(raw), nil
}

func validUsername(username string) bool {
	if len(username) < 3 || len(username) > 32 {
		return false
	}
	for i := 0; i < len(username); i++ {
		c := username[i]
		switch {
		case c >= 'a' && c <= 'z':
		case c >= 'A' && c <= 'Z':
		case c >= '0' && c <= '9':
		case c == '_' || c == '-':
		default:
			return false
		}
	}
	return true
}

func validPassword(password string) bool {
	n := utf8.RuneCountInString(password)
	return n >= 8 && n <= 128
}

func validText(text string) bool {
	if text == "" || len(text) > maxTextBytes {
		return false
	}
	return strings.TrimSpace(text) != ""
}

type credentials struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type noteRequest struct {
	Text string `json:"text"`
}

type registerResponse struct {
	ID       int    `json:"id"`
	Username string `json:"username"`
}

type tokenResponse struct {
	Token string `json:"token"`
}

type errorResponse struct {
	Error string `json:"error"`
}

// writeJSON renders every response body as JSON. A marshal failure is reported
// through the same envelope instead of leaking internal detail.
func writeJSON(w http.ResponseWriter, status int, payload any) {
	body, err := json.Marshal(payload)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte("{\"error\":\"internal error\"}\n"))
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = w.Write(append(body, '\n'))
}

func writeErr(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, errorResponse{Error: message})
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) error {
	r.Body = http.MaxBytesReader(w, r.Body, maxBodyBytes)
	return json.NewDecoder(r.Body).Decode(dst)
}

func bearerToken(r *http.Request) (string, bool) {
	header := r.Header.Get("Authorization")
	if header == "" {
		return "", false
	}
	parts := strings.Fields(header)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		return "", false
	}
	return parts[1], true
}

type api struct {
	store *Store
}

func handler(s *Store) http.Handler {
	a := &api{store: s}
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
	})
	mux.HandleFunc("/api/register", a.handleRegister)
	mux.HandleFunc("/api/login", a.handleLogin)
	mux.HandleFunc("/api/notes", a.handleNotes)
	mux.HandleFunc("/api/notes/", a.handleNoteItem)
	mux.HandleFunc("/api/", a.handleAPINotFound)
	mux.HandleFunc("/api", a.handleAPINotFound)

	// ---- static UI (embed only; API paths keep their auth/envelope) ----
	serveAsset := func(name, contentType string) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			if r.Method != http.MethodGet && r.Method != http.MethodHead {
				w.Header().Set("Allow", "GET, HEAD")
				writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
				return
			}
			data, err := webFS.ReadFile(name)
			if err != nil {
				writeErr(w, http.StatusNotFound, "not found")
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
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		data, err := webFS.ReadFile("web/index.html")
		if err != nil {
			writeErr(w, http.StatusNotFound, "not found")
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
			writeErr(w, http.StatusNotFound, "not found")
			return
		}
		w.Header().Set("Cache-Control", "no-store")
		http.Redirect(w, r, "/login", http.StatusFound)
	})
	return mux
}

func (a *api) requireAuth(w http.ResponseWriter, r *http.Request) (Session, bool) {
	if token, ok := bearerToken(r); ok {
		if session, found := a.store.SessionByToken(token); found {
			return session, true
		}
	}
	w.Header().Set("WWW-Authenticate", "Bearer")
	writeErr(w, http.StatusUnauthorized, "unauthorized")
	return Session{}, false
}

func (a *api) handleAPINotFound(w http.ResponseWriter, _ *http.Request) {
	writeErr(w, http.StatusNotFound, "not found")
}

func (a *api) handleRegister(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", "POST")
		writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	var req credentials
	if err := decodeJSON(w, r, &req); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid request body")
		return
	}
	username := strings.TrimSpace(req.Username)
	if username == "" || req.Password == "" {
		writeErr(w, http.StatusBadRequest, "username and password required")
		return
	}
	if !validUsername(username) {
		writeErr(w, http.StatusBadRequest, "invalid username")
		return
	}
	if !validPassword(req.Password) {
		writeErr(w, http.StatusBadRequest, "invalid password")
		return
	}
	user, err := a.store.CreateUser(username, req.Password)
	if err != nil {
		if errors.Is(err, errUsernameTaken) {
			writeErr(w, http.StatusConflict, "username taken")
			return
		}
		writeErr(w, http.StatusInternalServerError, "internal error")
		return
	}
	writeJSON(w, http.StatusCreated, registerResponse{ID: user.ID, Username: user.Username})
}

func (a *api) handleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", "POST")
		writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	var req credentials
	if err := decodeJSON(w, r, &req); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid request body")
		return
	}
	username := strings.TrimSpace(req.Username)
	if username == "" || req.Password == "" {
		writeErr(w, http.StatusBadRequest, "username and password required")
		return
	}
	session, err := a.store.Authenticate(username, req.Password)
	if err != nil {
		if errors.Is(err, errUnauthorized) {
			w.Header().Set("WWW-Authenticate", "Bearer")
			writeErr(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		writeErr(w, http.StatusInternalServerError, "internal error")
		return
	}
	writeJSON(w, http.StatusOK, tokenResponse{Token: session.Token})
}

func (a *api) handleNotes(w http.ResponseWriter, r *http.Request) {
	session, ok := a.requireAuth(w, r)
	if !ok {
		return
	}
	switch r.Method {
	case http.MethodGet:
		writeJSON(w, http.StatusOK, a.store.ListNotes(session.UserID))
	case http.MethodPost:
		var req noteRequest
		if err := decodeJSON(w, r, &req); err != nil {
			writeErr(w, http.StatusBadRequest, "invalid request body")
			return
		}
		if !validText(req.Text) {
			writeErr(w, http.StatusBadRequest, "text required")
			return
		}
		writeJSON(w, http.StatusCreated, a.store.AddNote(session.UserID, req.Text))
	default:
		w.Header().Set("Allow", "GET, POST")
		writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (a *api) handleNoteItem(w http.ResponseWriter, r *http.Request) {
	session, ok := a.requireAuth(w, r)
	if !ok {
		return
	}
	if r.Method != http.MethodDelete {
		w.Header().Set("Allow", "DELETE")
		writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	raw := strings.TrimPrefix(r.URL.Path, "/api/notes/")
	if raw == "" || strings.Contains(raw, "/") {
		writeErr(w, http.StatusBadRequest, "invalid id")
		return
	}
	id, err := strconv.Atoi(raw)
	if err != nil {
		writeErr(w, http.StatusBadRequest, "invalid id")
		return
	}
	if !a.store.DeleteNote(session.UserID, id) {
		writeErr(w, http.StatusNotFound, "not found")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func main() {
	log.Fatal(http.ListenAndServe(":8080", handler(NewStore())))
}

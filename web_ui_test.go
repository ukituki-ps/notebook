package main

import (
	"regexp"
	"strings"
	"testing"
)

// TestUISemantics is a static oracle for the embedded UI (INV-UI-TRUTH,
// INV-UI-LABEL, INV-UI-A11Y-NAME, INV-UI-EMPTY-STATE, AC-16/AC-17/AC-19).
// It does not exercise the network; runtime behaviour is covered by
// web/e2e/auth-notes.spec.js on the preview stand.
func TestUISemantics(t *testing.T) {
	assets := map[string]string{
		"web/index.html": "text/html",
		"web/app.js":     "javascript",
		"web/app.css":    "css",
	}
	content := map[string]string{}
	for name := range assets {
		data, err := webFS.ReadFile(name)
		if err != nil {
			t.Fatalf("embed %s: %v", name, err)
		}
		if len(data) == 0 {
			t.Fatalf("embed %s: empty", name)
		}
		content[name] = string(data)
	}
	html := content["web/index.html"]
	js := content["web/app.js"]
	css := content["web/app.css"]
	all := html + "\n" + js

	// Explicit embed patterns must not pull test/tooling assets into the binary.
	if _, err := webFS.ReadFile("web/e2e/auth-notes.spec.js"); err == nil {
		t.Fatal("embed includes web/e2e/auth-notes.spec.js; use explicit patterns")
	}

	// Full selector set from arch/structure/ui-pages/{login,register,notes}.yaml.
	// note-item/delete-note live in <template id="note-item-template">.
	requiredTestIDs := []string{
		// login.yaml
		"login-card", "login-form", "login-username", "login-password",
		"login-submit", "login-error", "register-link",
		// register.yaml
		"register-card", "register-form", "register-username", "register-password",
		"register-confirm", "register-submit", "register-error", "login-link",
		// notes.yaml
		"notes-header", "user-name", "logout", "note-form", "note-input",
		"add-note", "notes-list", "note-item", "delete-note", "notes-empty",
		"notes-loading", "notes-error",
		// f-v4-note-search
		"notes-search", "notes-search-clear", "notes-search-empty",
	}
	for _, id := range requiredTestIDs {
		if !strings.Contains(html, `data-testid="`+id+`"`) {
			t.Errorf("index.html missing data-testid=%q", id)
		}
	}

	// The earlier, non-contract ids must be gone.
	for _, id := range []string{
		"username", "password", "confirm-password", "notes-form", "note-text",
		"error", "notes-card",
	} {
		if strings.Contains(html, `data-testid="`+id+`"`) {
			t.Errorf("index.html still has legacy data-testid=%q", id)
		}
	}

	// note-item/delete-note are a real template in HTML; app.js clones it.
	templateRE := regexp.MustCompile(`(?s)<template id="note-item-template">(.*?)</template>`)
	match := templateRE.FindStringSubmatch(html)
	if match == nil {
		t.Fatal(`index.html missing <template id="note-item-template">`)
	}
	templateBody := match[1]
	for _, id := range []string{"note-item", "delete-note"} {
		if !strings.Contains(templateBody, `data-testid="`+id+`"`) {
			t.Errorf("note-item-template missing data-testid=%q", id)
		}
	}
	if strings.Contains(html, "data-note-id=") {
		t.Error("index.html contains a hardcoded note id")
	}

	// No phantom notes: no list rows outside the inert template.
	outsideTemplate := strings.Replace(html, match[0], "", 1)
	if regexp.MustCompile(`(?i)<li[\s>]`).MatchString(outsideTemplate) {
		t.Error("index.html contains a hardcoded <li> note row outside the template")
	}
	if !regexp.MustCompile(`(?s)<ul[^>]*data-testid="notes-list"[^>]*>\s*</ul>`).MatchString(html) {
		t.Error("notes-list must be an empty container in index.html")
	}

	// app.js must clone the template and never create rows from inline markup.
	if !strings.Contains(js, `getElementById("note-item-template")`) {
		t.Error(`app.js does not use <template id="note-item-template">`)
	}
	if !strings.Contains(js, "cloneNode(true)") {
		t.Error("app.js does not clone the note-item template")
	}
	if !strings.Contains(js, "aria-label") {
		t.Error("delete buttons need a per-note aria-label")
	}

	// Every control has a visible <label for=...> pointing at its id.
	for _, id := range []string{
		"login-username", "login-password",
		"register-username", "register-password", "register-confirm",
		"note-input", "notes-search",
	} {
		if !strings.Contains(html, `for="`+id+`"`) {
			t.Errorf("missing <label for=%q>", id)
		}
		if !strings.Contains(html, `id="`+id+`"`) {
			t.Errorf("missing control id=%q", id)
		}
	}

	// Three per-screen error regions, each an alert live region.
	for _, id := range []string{"login-error", "register-error", "notes-error"} {
		tag := elementTag(html, id)
		if tag == "" {
			t.Errorf("missing error region data-testid=%q", id)
			continue
		}
		if !strings.Contains(tag, `role="alert"`) {
			t.Errorf("error region %q missing role=alert", id)
		}
		if !strings.Contains(tag, `aria-live="polite"`) {
			t.Errorf("error region %q missing aria-live=polite", id)
		}
		if !strings.Contains(tag, "hidden") {
			t.Errorf("error region %q must start hidden", id)
		}
	}

	// Visible button/copy names required by AC-17.
	for _, label := range []string{"Login", "Register", "Add", "Delete"} {
		if !strings.Contains(all, label) {
			t.Errorf("missing visible label %q", label)
		}
	}

	// Empty/loading states exist; empty is hidden until a 200 with no notes.
	for _, id := range []string{"notes-empty", "notes-loading"} {
		if elementTag(html, id) == "" {
			t.Errorf("missing %s state", id)
		}
	}
	if tag := elementTag(html, "notes-empty"); !strings.Contains(tag, "hidden") {
		t.Error("notes-empty must be hidden by default")
	}

	// Search is labeled, accessible and placed above the notes list.
	searchTag := elementTag(html, "notes-search")
	if searchTag == "" {
		t.Fatal("missing notes-search input")
	}
	if !strings.Contains(searchTag, `type="search"`) {
		t.Error("notes-search must be type=search")
	}
	if !strings.Contains(searchTag, `aria-controls="notes-list"`) {
		t.Error("notes-search must reference notes-list via aria-controls")
	}
	if !strings.Contains(html, `for="notes-search"`) {
		t.Error(`missing <label for="notes-search">`)
	}
	searchPos := strings.Index(html, `data-testid="notes-search"`)
	listPos := strings.Index(html, `data-testid="notes-list"`)
	if searchPos < 0 || listPos < 0 || searchPos > listPos {
		t.Error("notes-search must appear above notes-list")
	}

	clearTag := elementTag(html, "notes-search-clear")
	if clearTag == "" {
		t.Fatal("missing notes-search-clear control")
	}
	if !strings.Contains(clearTag, `type="button"`) {
		t.Error("notes-search-clear must be type=button")
	}
	if !strings.Contains(clearTag, `aria-label=`) {
		t.Error("notes-search-clear needs an aria-label")
	}
	if !strings.Contains(clearTag, "hidden") {
		t.Error("notes-search-clear must start hidden with an empty query")
	}

	searchEmptyTag := elementTag(html, "notes-search-empty")
	if searchEmptyTag == "" {
		t.Fatal("missing notes-search-empty state")
	}
	if !strings.Contains(searchEmptyTag, "hidden") {
		t.Error("notes-search-empty must be hidden by default")
	}
	if !strings.Contains(searchEmptyTag, `role="status"`) {
		t.Error("notes-search-empty must be role=status")
	}
	if !strings.Contains(searchEmptyTag, `aria-live="polite"`) {
		t.Error("notes-search-empty must be aria-live=polite")
	}

	// app.js must drive the UI through the contract ids.
	for _, id := range []string{
		"login-error", "register-error", "notes-error",
		"login-form", "login-username", "login-password", "login-submit",
		"register-form", "register-username", "register-password",
		"register-confirm", "register-submit",
		"register-link", "login-link",
		"note-form", "note-input", "add-note", "notes-list",
		"notes-empty", "notes-loading", "user-name", "logout",
		"delete-note", "notes-search", "notes-search-clear",
		"notes-search-empty",
	} {
		if !strings.Contains(js, `"`+id+`"`) {
			t.Errorf("app.js does not reference data-testid=%q", id)
		}
	}

	if !strings.Contains(js, "fetch(") || !strings.Contains(js, `"/api/notes"`) {
		t.Error("app.js must load notes from /api/notes")
	}
	if !strings.Contains(js, "notes = Array.isArray(res.data)") {
		t.Error("notes list must be rendered from the API response data")
	}

	// Client-side filtering is case-insensitive over title/body and re-applied
	// by one render function for load/create/delete/reload.
	if !strings.Contains(js, "function renderNotes(") {
		t.Error("app.js must expose a single renderNotes() function")
	}
	if strings.Count(js, "renderNotes(") < 4 {
		t.Error("renderNotes() must be re-applied after load, create and delete")
	}
	if strings.Count(js, "appendChild(makeNote(") != 1 {
		t.Error("only the single render function may append note rows")
	}
	for _, need := range []string{"toLowerCase()", "notes.filter(", ".indexOf(", "searchQuery"} {
		if !strings.Contains(js, need) {
			t.Errorf("app.js missing client-side search logic (%q)", need)
		}
	}
	if !strings.Contains(js, "notes.length === 0") || !strings.Contains(js, "!noNotes") {
		t.Error("notes-search-empty must not replace the base notes-empty state")
	}
	if !strings.Contains(js, `location.replace("/login")`) {
		t.Error("app.js must redirect to /login on 401/logout")
	}
	if !strings.Contains(js, "aria-invalid") {
		t.Error("register 400 must mark the offending field with aria-invalid")
	}

	// CSS: narrow breakpoint, full-width controls, touch target and wrapping.
	for _, need := range []string{
		"max-width: 640px",
		"@media (max-width: 640px)",
		"min-height: 44px",
		"overflow-wrap: anywhere",
		":focus-visible",
	} {
		if !strings.Contains(css, need) {
			t.Errorf("app.css missing %q", need)
		}
	}
}

// elementTag returns the opening tag that carries data-testid="id".
func elementTag(html, id string) string {
	re := regexp.MustCompile(`(?s)<[^>]*data-testid="` + regexp.QuoteMeta(id) + `"[^>]*>`)
	return re.FindString(html)
}

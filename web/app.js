(function () {
  "use strict";

  var TOKEN_KEY = "notebook.token";
  var USER_KEY = "notebook.user";
  var PREFILL_KEY = "notebook.prefill";
  var SEARCH_KEY = "notebook.search";
  var SCREENS = ["login", "register", "notes"];

  function byTestId(id) {
    return document.querySelector('[data-testid="' + id + '"]');
  }

  var errorEls = {
    login: byTestId("login-error"),
    register: byTestId("register-error"),
    notes: byTestId("notes-error")
  };

  function showError(screen, text) {
    var el = errorEls[screen];
    if (!el) return;
    el.textContent = text || "";
    el.hidden = !text;
  }

  function clearErrors() {
    SCREENS.forEach(function (name) {
      showError(name, "");
    });
  }

  function readStorage(store, key) {
    try {
      return store.getItem(key);
    } catch (e) {
      return null;
    }
  }

  function writeStorage(store, key, value) {
    try {
      store.setItem(key, value);
    } catch (e) {
      /* storage may be unavailable; the flow still fails closed below */
    }
  }

  function removeStorage(store, key) {
    try {
      store.removeItem(key);
    } catch (e) {
      /* ignore */
    }
  }

  function setFormBusy(form, button, busy, busyText) {
    var fields = form.querySelectorAll("input, textarea, button");
    for (var i = 0; i < fields.length; i++) {
      fields[i].disabled = busy;
    }
    if (busy) {
      if (!button.dataset.idleText) button.dataset.idleText = button.textContent;
      if (busyText) button.textContent = busyText;
    } else {
      if (button.dataset.idleText) {
        button.textContent = button.dataset.idleText;
        delete button.dataset.idleText;
      }
    }
  }

  function markFieldInvalid(el, invalid) {
    if (!el) return;
    if (invalid) {
      el.classList.add("invalid");
      el.setAttribute("aria-invalid", "true");
    } else {
      el.classList.remove("invalid");
      el.removeAttribute("aria-invalid");
    }
  }

  // api performs a same-origin JSON request and always resolves to
  // {status, data} (data is null for empty/non-JSON bodies).
  function api(path, options) {
    options = options || {};
    var headers = { Accept: "application/json" };
    if (options.body !== undefined) headers["Content-Type"] = "application/json";
    if (options.token) headers.Authorization = "Bearer " + options.token;

    var init = {
      method: options.method || "GET",
      headers: headers,
      credentials: "same-origin"
    };
    if (options.body !== undefined) init.body = JSON.stringify(options.body);

    return fetch(path, init).then(function (res) {
      var type = res.headers.get("Content-Type") || "";
      var parsed;
      if (type.indexOf("application/json") === -1) {
        parsed = Promise.resolve(null);
      } else {
        parsed = res.json().catch(function () {
          return null;
        });
      }
      return parsed.then(function (data) {
        return { status: res.status, data: data };
      });
    });
  }

  var screenEls = {};
  SCREENS.forEach(function (name) {
    screenEls[name] = document.querySelector('[data-screen="' + name + '"]');
  });

  function screenFromLocation() {
    var hash = (location.hash || "").replace(/^#\/?/, "");
    if (SCREENS.indexOf(hash) !== -1) return hash;
    var path = location.pathname.replace(/\/+$/, "");
    if (path === "/register") return "register";
    if (path === "/notes") return "notes";
    return "login";
  }

  function activate(name) {
    SCREENS.forEach(function (n) {
      if (screenEls[n]) screenEls[n].hidden = n !== name;
    });
    clearErrors();
    if (name === "login") prepareLogin();
    if (name === "notes") initNotes();
  }

  // ---------------- login ----------------

  var loginForm = byTestId("login-form");
  var loginUsername = byTestId("login-username");
  var loginPassword = byTestId("login-password");
  var loginSubmit = byTestId("login-submit");

  function prepareLogin() {
    var prefill = readStorage(sessionStorage, PREFILL_KEY);
    if (!prefill) return;
    loginUsername.value = prefill;
    removeStorage(sessionStorage, PREFILL_KEY);
    loginPassword.focus();
  }

  loginForm.addEventListener("submit", function (event) {
    event.preventDefault();
    showError("login", "");

    var username = loginUsername.value.trim();
    var password = loginPassword.value;
    if (!username || !password) {
      showError("login", "Username и password обязательны");
      if (!username) loginUsername.focus();
      else loginPassword.focus();
      return;
    }

    var done = false;
    setFormBusy(loginForm, loginSubmit, true, "Logging in...");
    api("/api/login", {
      method: "POST",
      body: { username: username, password: password }
    })
      .then(function (res) {
        if (res.status === 200 && res.data && res.data.token) {
          done = true;
          writeStorage(localStorage, TOKEN_KEY, res.data.token);
          writeStorage(localStorage, USER_KEY, username);
          location.replace("/notes");
          return;
        }
        if (res.status === 400) {
          showError("login", "Username и password обязательны");
          return;
        }
        if (res.status === 401) {
          showError("login", "Неверный username или пароль");
          loginPassword.value = "";
          loginPassword.focus();
          return;
        }
        showError("login", "Не удалось войти. Попробуйте ещё раз.");
      })
      .catch(function () {
        showError("login", "Ошибка сети. Проверьте соединение.");
      })
      .then(function () {
        if (!done) setFormBusy(loginForm, loginSubmit, false, "");
      });
  });

  // ---------------- register ----------------

  var registerForm = byTestId("register-form");
  var registerUsername = byTestId("register-username");
  var registerPassword = byTestId("register-password");
  var registerConfirm = byTestId("register-confirm");
  var registerSubmit = byTestId("register-submit");

  function clearRegisterInvalid() {
    markFieldInvalid(registerUsername, false);
    markFieldInvalid(registerPassword, false);
    markFieldInvalid(registerConfirm, false);
  }

  function registerErrorText(code) {
    switch (code) {
      case "username and password required":
        return "Username и password обязательны";
      case "invalid username":
        return "Username: 3-32 символа, a-z A-Z 0-9 _ -";
      case "invalid password":
        return "Password: от 8 до 128 символов";
      case "invalid request body":
        return "Некорректный запрос";
      default:
        return "Не удалось зарегистрироваться. Попробуйте ещё раз.";
    }
  }

  registerForm.addEventListener("submit", function (event) {
    event.preventDefault();
    showError("register", "");
    clearRegisterInvalid();

    var username = registerUsername.value.trim();
    var password = registerPassword.value;
    var confirm = registerConfirm.value;

    if (!confirm || confirm !== password) {
      showError("register", "Passwords do not match");
      markFieldInvalid(registerConfirm, true);
      registerConfirm.focus();
      return;
    }
    if (!username || !password) {
      showError("register", "Username и password обязательны");
      if (!username) {
        markFieldInvalid(registerUsername, true);
        registerUsername.focus();
      } else {
        markFieldInvalid(registerPassword, true);
        registerPassword.focus();
      }
      return;
    }

    var done = false;
    setFormBusy(registerForm, registerSubmit, true, "Registering...");
    api("/api/register", {
      method: "POST",
      body: { username: username, password: password }
    })
      .then(function (res) {
        if (res.status === 201) {
          done = true;
          writeStorage(sessionStorage, PREFILL_KEY, username);
          location.replace("/login");
          return;
        }
        if (res.status === 400) {
          var code = res.data && res.data.error;
          var marked = false;
          if (code === "invalid username" || code === "username and password required") {
            markFieldInvalid(registerUsername, true);
            marked = true;
          }
          if (code === "invalid password" || code === "username and password required") {
            markFieldInvalid(registerPassword, true);
            marked = true;
          }
          if (!marked) markFieldInvalid(registerUsername, true);
          showError("register", registerErrorText(code));
          return;
        }
        if (res.status === 409) {
          showError("register", "Username уже занят");
          markFieldInvalid(registerUsername, true);
          registerUsername.focus();
          return;
        }
        showError("register", "Не удалось зарегистрироваться. Попробуйте ещё раз.");
      })
      .catch(function () {
        showError("register", "Ошибка сети. Проверьте соединение.");
      })
      .then(function () {
        if (!done) setFormBusy(registerForm, registerSubmit, false, "");
      });
  });

  // ---------------- notes ----------------

  var notesForm = byTestId("note-form");
  var noteInput = byTestId("note-input");
  var addButton = byTestId("add-note");
  var notesList = byTestId("notes-list");
  var notesEmpty = byTestId("notes-empty");
  var notesLoading = byTestId("notes-loading");
  var notesSearch = byTestId("notes-search");
  var notesSearchClear = byTestId("notes-search-clear");
  var notesSearchEmpty = byTestId("notes-search-empty");
  var userNameEl = byTestId("user-name");
  var logoutButton = byTestId("logout");
  var noteTemplate = document.getElementById("note-item-template");

  var notesInitialized = false;
  var notes = [];
  var searchQuery = "";

  function setNotesEnabled(enabled) {
    notesForm.dataset.enabled = enabled ? "1" : "0";
    noteInput.disabled = !enabled;
    if (notesSearch) notesSearch.disabled = !enabled;
    if (notesSearchClear) notesSearchClear.disabled = !enabled;
    if (!enabled) addButton.disabled = true;
    else updateAddState();
  }

  function updateAddState() {
    if (notesForm.dataset.enabled !== "1" || addButton.dataset.busy === "1") {
      addButton.disabled = true;
      return;
    }
    addButton.disabled = noteInput.value.trim() === "";
  }

  function makeNote(note) {
    var item = noteTemplate.content.firstElementChild.cloneNode(true);
    item.setAttribute("data-note-id", String(note.id));

    var text = item.querySelector(".note-text");
    if (text) text.textContent = "#" + note.id + " " + note.text;

    var remove = item.querySelector('[data-testid="delete-note"]');
    if (remove) {
      remove.setAttribute("aria-label", "Удалить заметку #" + note.id);
      remove.addEventListener("click", function () {
        deleteNote(note.id, item, remove);
      });
    }
    return item;
  }

  // Search matches the note title/body case-insensitively. The API only
  // exposes text today, but title is included so a future field keeps working.
  function noteSearchText(note) {
    var parts = [];
    if (note && note.title != null) parts.push(String(note.title));
    if (note && note.text != null) parts.push(String(note.text));
    return parts.join(" ").toLowerCase();
  }

  function filterNotes() {
    var query = searchQuery.trim().toLowerCase();
    if (!query) return notes.slice();
    return notes.filter(function (note) {
      return noteSearchText(note).indexOf(query) !== -1;
    });
  }

  // Single render/filter function: load, create, delete and reload all funnel
  // here so the active query is always re-applied.
  function renderNotes() {
    var visible = filterNotes();
    var hasQuery = searchQuery.trim() !== "";
    var noNotes = notes.length === 0;

    notesList.textContent = "";
    visible.forEach(function (note) {
      notesList.appendChild(makeNote(note));
    });

    notesList.hidden = visible.length === 0;
    notesEmpty.hidden = !noNotes;
    // notes-search-empty is only for an active query that filters a non-empty
    // collection down to nothing; the base empty state stays notes-empty.
    if (notesSearchEmpty) {
      notesSearchEmpty.hidden = !(hasQuery && !noNotes && visible.length === 0);
    }
    if (notesSearchClear) notesSearchClear.hidden = searchQuery.trim() === "";
  }

  function handleUnauthorized() {
    removeStorage(localStorage, TOKEN_KEY);
    removeStorage(localStorage, USER_KEY);
    removeStorage(sessionStorage, SEARCH_KEY);
    setNotesEnabled(false);
    showError("notes", "Сессия истекла. Перенаправление на вход...");
    window.setTimeout(function () {
      location.replace("/login");
    }, 200);
  }

  function loadNotes() {
    var token = readStorage(localStorage, TOKEN_KEY);
    if (!token) {
      handleUnauthorized();
      return;
    }
    notesLoading.hidden = false;
    notesEmpty.hidden = true;
    notesList.hidden = true;
    if (notesSearchEmpty) notesSearchEmpty.hidden = true;
    setNotesEnabled(false);

    api("/api/notes", { token: token })
      .then(function (res) {
        notesLoading.hidden = true;
        if (res.status === 401) {
          handleUnauthorized();
          return;
        }
        if (res.status !== 200) {
          showError("notes", "Не удалось загрузить заметки.");
          return;
        }
        notes = Array.isArray(res.data) ? res.data : [];
        renderNotes();
        setNotesEnabled(true);
      })
      .catch(function () {
        notesLoading.hidden = true;
        showError("notes", "Ошибка сети. Проверьте соединение.");
      });
  }

  function initNotes() {
    if (notesInitialized) return;
    notesInitialized = true;

    var token = readStorage(localStorage, TOKEN_KEY);
    if (!token) {
      // No token means a different user may log in in this tab. Never leave
      // the previous user's query in sessionStorage (RT-NEW-1).
      removeStorage(sessionStorage, SEARCH_KEY);
      location.replace("/login");
      return;
    }
    var user = readStorage(localStorage, USER_KEY);
    if (user && userNameEl) userNameEl.textContent = user;

    // Restore an active query across a browser reload, then let loadNotes()
    // re-apply it to the freshly fetched list.
    searchQuery = readStorage(sessionStorage, SEARCH_KEY) || "";
    if (notesSearch) notesSearch.value = searchQuery;

    loadNotes();
  }

  function deleteNote(id, item, button) {
    showError("notes", "");
    if (item.dataset.pending === "1") return;

    item.dataset.pending = "1";
    item.classList.add("pending");
    button.disabled = true;

    api("/api/notes/" + encodeURIComponent(String(id)), {
      method: "DELETE",
      token: readStorage(localStorage, TOKEN_KEY)
    })
      .then(function (res) {
        if (res.status === 204) {
          notes = notes.filter(function (note) {
            return String(note.id) !== String(id);
          });
          renderNotes();
          return;
        }
        if (res.status === 401) {
          handleUnauthorized();
          return;
        }
        item.dataset.pending = "0";
        item.classList.remove("pending");
        button.disabled = false;

        if (res.status === 404) {
          showError("notes", "Заметка не найдена");
          loadNotes();
          return;
        }
        if (res.status === 400) {
          showError("notes", "Некорректный запрос");
          return;
        }
        showError("notes", "Не удалось удалить заметку.");
      })
      .catch(function () {
        item.dataset.pending = "0";
        item.classList.remove("pending");
        button.disabled = false;
        showError("notes", "Ошибка сети. Проверьте соединение.");
      });
  }

  notesForm.addEventListener("submit", function (event) {
    event.preventDefault();
    showError("notes", "");
    if (addButton.dataset.busy === "1" || notesForm.dataset.enabled !== "1") return;

    var text = noteInput.value;
    if (text.trim() === "") {
      showError("notes", "Текст заметки не может быть пустым");
      noteInput.focus();
      return;
    }

    var idleText = addButton.textContent;
    addButton.dataset.busy = "1";
    addButton.disabled = true;
    noteInput.disabled = true;
    addButton.textContent = "Adding...";

    api("/api/notes", {
      method: "POST",
      token: readStorage(localStorage, TOKEN_KEY),
      body: { text: text }
    })
      .then(function (res) {
        if (res.status === 201) {
          notes.push(res.data);
          renderNotes();
          noteInput.value = "";
          noteInput.focus();
          return;
        }
        if (res.status === 401) {
          handleUnauthorized();
          return;
        }
        if (res.status === 400) {
          showError("notes", "Текст заметки не может быть пустым");
          return;
        }
        showError("notes", "Не удалось добавить заметку.");
      })
      .catch(function () {
        showError("notes", "Ошибка сети. Проверьте соединение.");
      })
      .then(function () {
        addButton.textContent = idleText;
        addButton.dataset.busy = "0";
        if (notesForm.dataset.enabled !== "0") {
          noteInput.disabled = false;
          updateAddState();
        }
      });
  });

  noteInput.addEventListener("input", updateAddState);

  if (notesSearch) {
    notesSearch.addEventListener("input", function () {
      searchQuery = notesSearch.value;
      writeStorage(sessionStorage, SEARCH_KEY, searchQuery);
      renderNotes();
    });
  }

  if (notesSearchClear) {
    notesSearchClear.addEventListener("click", function () {
      searchQuery = "";
      if (notesSearch) notesSearch.value = "";
      removeStorage(sessionStorage, SEARCH_KEY);
      renderNotes();
      if (notesSearch) notesSearch.focus();
    });
  }

  // Enter submits the note; Shift+Enter inserts a newline.
  noteInput.addEventListener("keydown", function (event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      if (typeof notesForm.requestSubmit === "function") {
        notesForm.requestSubmit();
      } else {
        notesForm.dispatchEvent(new Event("submit", { cancelable: true }));
      }
    }
  });

  logoutButton.addEventListener("click", function () {
    removeStorage(localStorage, TOKEN_KEY);
    removeStorage(localStorage, USER_KEY);
    removeStorage(sessionStorage, SEARCH_KEY);
    location.replace("/login");
  });

  // ---------------- boot ----------------

  function wireLink(testid, target) {
    var link = byTestId(testid);
    if (!link) return;
    link.addEventListener("click", function (event) {
      event.preventDefault();
      location.replace(target);
    });
  }
  wireLink("register-link", "/register");
  wireLink("login-link", "/login");

  window.addEventListener("hashchange", function () {
    activate(screenFromLocation());
  });

  activate(screenFromLocation());
})();

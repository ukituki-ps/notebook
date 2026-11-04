(function () {
  "use strict";

  var TOKEN_KEY = "notebook.token";
  var USER_KEY = "notebook.user";
  var PREFILL_KEY = "notebook.prefill";
  var SCREENS = ["login", "register", "notes"];

  var errorEl = document.querySelector('[data-testid="error"]');

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

  function showError(text) {
    if (!errorEl) return;
    errorEl.textContent = text || "";
    errorEl.hidden = !text;
  }

  function clearError() {
    showError("");
  }

  function field(form, testid) {
    return form.querySelector('[data-testid="' + testid + '"]');
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
    clearError();
    if (name === "login") prepareLogin();
    if (name === "notes") initNotes();
  }

  // ---------------- login ----------------

  var loginForm = document.getElementById("login-form");
  var loginUsername = document.getElementById("login-username");
  var loginPassword = document.getElementById("login-password");
  var loginSubmit = document.getElementById("login-submit");

  function prepareLogin() {
    var prefill = readStorage(sessionStorage, PREFILL_KEY);
    if (!prefill) return;
    loginUsername.value = prefill;
    removeStorage(sessionStorage, PREFILL_KEY);
    loginPassword.focus();
  }

  loginForm.addEventListener("submit", function (event) {
    event.preventDefault();
    clearError();

    var username = loginUsername.value.trim();
    var password = loginPassword.value;
    if (!username || !password) {
      showError("Username и password обязательны");
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
          showError("Username и password обязательны");
          return;
        }
        if (res.status === 401) {
          showError("Неверный username или пароль");
          loginPassword.value = "";
          loginPassword.focus();
          return;
        }
        showError("Не удалось войти. Попробуйте ещё раз.");
      })
      .catch(function () {
        showError("Ошибка сети. Проверьте соединение.");
      })
      .then(function () {
        if (!done) setFormBusy(loginForm, loginSubmit, false, "");
      });
  });

  // ---------------- register ----------------

  var registerForm = document.getElementById("register-form");
  var registerUsername = document.getElementById("register-username");
  var registerPassword = document.getElementById("register-password");
  var registerConfirm = document.getElementById("register-confirm");
  var registerSubmit = document.getElementById("register-submit");

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
    clearError();

    var username = registerUsername.value.trim();
    var password = registerPassword.value;
    var confirm = registerConfirm.value;

    if (!confirm || confirm !== password) {
      showError("Passwords do not match");
      registerConfirm.focus();
      return;
    }
    if (!username || !password) {
      showError("Username и password обязательны");
      if (!username) registerUsername.focus();
      else registerPassword.focus();
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
          showError("Аккаунт создан. Войдите.");
          window.setTimeout(function () {
            location.replace("/login");
          }, 800);
          return;
        }
        if (res.status === 400) {
          var code = res.data && res.data.error;
          showError(registerErrorText(code));
          return;
        }
        if (res.status === 409) {
          showError("Username уже занят");
          registerUsername.focus();
          return;
        }
        showError("Не удалось зарегистрироваться. Попробуйте ещё раз.");
      })
      .catch(function () {
        showError("Ошибка сети. Проверьте соединение.");
      })
      .then(function () {
        if (!done) setFormBusy(registerForm, registerSubmit, false, "");
      });
  });

  // ---------------- notes ----------------

  var notesForm = document.getElementById("notes-form");
  var noteText = document.getElementById("note-text");
  var addButton = document.getElementById("add-note");
  var notesList = document.getElementById("notes-list");
  var notesEmpty = document.getElementById("notes-empty");
  var notesLoading = document.getElementById("notes-loading");
  var userNameEl = document.querySelector('[data-testid="user-name"]');
  var logoutButton = document.getElementById("logout");

  var notesInitialized = false;

  function setNotesEnabled(enabled) {
    notesForm.dataset.enabled = enabled ? "1" : "0";
    noteText.disabled = !enabled;
    if (!enabled) addButton.disabled = true;
    else updateAddState();
  }

  function updateAddState() {
    if (notesForm.dataset.enabled !== "1" || addButton.dataset.busy === "1") {
      addButton.disabled = true;
      return;
    }
    addButton.disabled = noteText.value.trim() === "";
  }

  function makeNote(note) {
    var item = document.createElement("li");
    item.className = "note-item";
    item.setAttribute("data-testid", "note-item");
    item.setAttribute("data-note-id", String(note.id));
    item.setAttribute("role", "listitem");

    var text = document.createElement("span");
    text.className = "note-text";
    text.textContent = "#" + note.id + " " + note.text;

    var remove = document.createElement("button");
    remove.type = "button";
    remove.className = "delete-note";
    remove.setAttribute("data-testid", "delete-note");
    remove.setAttribute("aria-label", "Удалить заметку #" + note.id);
    remove.textContent = "Delete";
    remove.addEventListener("click", function () {
      deleteNote(note.id, item, remove);
    });

    item.appendChild(text);
    item.appendChild(remove);
    return item;
  }

  function renderNotes(notes) {
    notesList.textContent = "";
    if (!notes || notes.length === 0) {
      notesEmpty.hidden = false;
      notesList.hidden = true;
      return;
    }
    notesEmpty.hidden = true;
    notesList.hidden = false;
    notes.forEach(function (note) {
      notesList.appendChild(makeNote(note));
    });
  }

  function handleUnauthorized() {
    removeStorage(localStorage, TOKEN_KEY);
    removeStorage(localStorage, USER_KEY);
    setNotesEnabled(false);
    showError("Сессия истекла. Перенаправление на вход...");
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
    setNotesEnabled(false);

    api("/api/notes", { token: token })
      .then(function (res) {
        notesLoading.hidden = true;
        if (res.status === 401) {
          handleUnauthorized();
          return;
        }
        if (res.status !== 200) {
          showError("Не удалось загрузить заметки.");
          return;
        }
        renderNotes(Array.isArray(res.data) ? res.data : []);
        setNotesEnabled(true);
      })
      .catch(function () {
        notesLoading.hidden = true;
        showError("Ошибка сети. Проверьте соединение.");
      });
  }

  function initNotes() {
    if (notesInitialized) return;
    notesInitialized = true;

    var token = readStorage(localStorage, TOKEN_KEY);
    if (!token) {
      location.replace("/login");
      return;
    }
    var user = readStorage(localStorage, USER_KEY);
    if (user && userNameEl) userNameEl.textContent = user;
    loadNotes();
  }

  function deleteNote(id, item, button) {
    clearError();
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
          item.parentNode.removeChild(item);
          if (notesList.children.length === 0) {
            notesList.hidden = true;
            notesEmpty.hidden = false;
          }
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
          showError("Заметка не найдена");
          loadNotes();
          return;
        }
        if (res.status === 400) {
          showError("Некорректный запрос");
          return;
        }
        showError("Не удалось удалить заметку.");
      })
      .catch(function () {
        item.dataset.pending = "0";
        item.classList.remove("pending");
        button.disabled = false;
        showError("Ошибка сети. Проверьте соединение.");
      });
  }

  notesForm.addEventListener("submit", function (event) {
    event.preventDefault();
    clearError();
    if (addButton.dataset.busy === "1" || notesForm.dataset.enabled !== "1") return;

    var text = noteText.value;
    if (text.trim() === "") {
      showError("Текст заметки не может быть пустым");
      noteText.focus();
      return;
    }

    var idleText = addButton.textContent;
    addButton.dataset.busy = "1";
    addButton.disabled = true;
    noteText.disabled = true;
    addButton.textContent = "Adding...";

    api("/api/notes", {
      method: "POST",
      token: readStorage(localStorage, TOKEN_KEY),
      body: { text: text }
    })
      .then(function (res) {
        if (res.status === 201) {
          notesList.appendChild(makeNote(res.data));
          notesList.hidden = false;
          notesEmpty.hidden = true;
          noteText.value = "";
          noteText.focus();
          return;
        }
        if (res.status === 401) {
          handleUnauthorized();
          return;
        }
        if (res.status === 400) {
          showError("Текст заметки не может быть пустым");
          return;
        }
        showError("Не удалось добавить заметку.");
      })
      .catch(function () {
        showError("Ошибка сети. Проверьте соединение.");
      })
      .then(function () {
        addButton.textContent = idleText;
        addButton.dataset.busy = "0";
        if (notesForm.dataset.enabled !== "0") {
          noteText.disabled = false;
          updateAddState();
        }
      });
  });

  noteText.addEventListener("input", updateAddState);

  // Enter submits the note; Shift+Enter inserts a newline.
  noteText.addEventListener("keydown", function (event) {
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
    location.replace("/login");
  });

  // ---------------- boot ----------------

  function wireLink(selector, target) {
    var link = document.querySelector(selector);
    if (!link) return;
    link.addEventListener("click", function (event) {
      event.preventDefault();
      location.replace(target);
    });
  }
  wireLink('[data-testid="register-link"]', "/register");
  wireLink('[data-testid="login-link"]', "/login");

  window.addEventListener("hashchange", function () {
    activate(screenFromLocation());
  });

  activate(screenFromLocation());
})();

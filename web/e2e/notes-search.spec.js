// SEARCH-E2E-1..20 for f-v4-note-search (owner-scoped note text search).
//
// Run against an integrated preview stand that includes the final search UI
// (notebook-search-ui, U02):
//   E2E_BASE_URL=https://test2.nexus.ukituki.tech npx --no-install playwright test \
//     web/e2e/notes-search.spec.js
//
// Fail-close: a missing stand/browser/UI fails the run; nothing is skipped.
// Each scenario is independent: it registers a fresh user and uses unique note
// text, so it never depends on note ids or on another scenario's data.
"use strict";

const fs = require("fs");
const path = require("path");
const { test, expect } = require("@playwright/test");

const PASSWORD = "password123";
const OFFLINE_LOADED = "Нет сети — показаны загруженные заметки.";
const OFFLINE_EMPTY = "Нет сети — нет загруженных заметок.";
const LOAD_ERROR = "Не удалось загрузить заметки. Попробуйте ещё раз.";
const SEARCH_EMPTY_TEXT =
  "Ничего не найдено. Сократите запрос или очистите поиск.";
const BASE_EMPTY_TEXT = "Пока нет заметок. Добавьте первую выше.";

function uniqueUsername(prefix) {
  const stamp = Date.now().toString(36);
  const rand = Math.random().toString(36).slice(2, 6);
  return (prefix + stamp + rand).slice(0, 32);
}

function uniqueToken(prefix) {
  return (
    prefix + "-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 6)
  );
}

async function registerUser(request, username) {
  const res = await request.post("/api/register", {
    data: { username, password: PASSWORD },
  });
  expect(res.status(), `register ${username}: ${await res.text()}`).toBe(201);
}

// waitForNotesReady waits until loadNotes() has produced a final UI state
// (rows rendered or the base empty state). The static HTML already has some
// controls enabled, so waiting on note-input alone can race loadNotes().
async function waitForNotesReady(page) {
  await expect(page.getByTestId("notes-loading")).toBeHidden();
  await page.waitForFunction(() => {
    const list = document.querySelector('[data-testid="notes-list"]');
    const empty = document.querySelector('[data-testid="notes-empty"]');
    return Boolean((list && !list.hidden) || (empty && !empty.hidden));
  });
}

async function loginViaUI(page, username, password = PASSWORD) {
  await page.goto("/login");
  const form = page.getByTestId("login-form");
  await form.getByTestId("login-username").fill(username);
  await form.getByTestId("login-password").fill(password);
  await page.getByTestId("login-submit").click();
  await page.waitForURL(/\/notes$/);
  await waitForNotesReady(page);
  await expect(page.getByTestId("note-input")).toBeEnabled();
}

async function createUserAndLogin(page, request, prefix) {
  const username = uniqueUsername(prefix);
  await registerUser(request, username);
  await loginViaUI(page, username);
  return username;
}

// submitNote creates a note and waits for the POST 201. Unlike addNote it does
// not require the new row to be visible, because an active search may filter it
// out (SEARCH-E2E-5).
async function submitNote(page, text) {
  const input = page.getByTestId("note-input");
  await input.fill(text);
  const add = page.getByTestId("add-note");
  await expect(add).toBeEnabled();

  const created = page.waitForResponse(
    (res) =>
      res.request().method() === "POST" &&
      new URL(res.url()).pathname.endsWith("/api/notes")
  );
  await add.click();
  const res = await created;
  expect(res.status()).toBe(201);
  await expect(input).toHaveValue("");
}

async function addNote(page, text) {
  await submitNote(page, text);
  const item = page.getByTestId("note-item").filter({ hasText: text });
  await expect(item).toBeVisible();
  return item;
}

// visibleItems counts only rendered rows. The UI rebuilds the list on render,
// so a filtered-out note is either absent or hidden; :visible covers both.
function visibleItems(page) {
  return page.locator('[data-testid="note-item"]:visible');
}

async function setQuery(page, query) {
  const search = page.getByTestId("notes-search");
  await search.fill(query);
  await expect(search).toHaveValue(query);
}

function clearControl(page) {
  return page.getByTestId("notes-search-clear");
}

async function clearQuery(page) {
  await clearControl(page).click();
  await expect(page.getByTestId("notes-search")).toHaveValue("");
}

async function expectSearchEmpty(page, visible) {
  const empty = page.getByTestId("notes-search-empty");
  if (visible) {
    await expect(empty).toBeVisible();
    await expect(empty).toHaveText(SEARCH_EMPTY_TEXT);
  } else {
    await expect(empty).toBeHidden();
  }
}

async function expectNoHorizontalOverflow(page) {
  const overflow = await page.evaluate(() => {
    const doc = document.documentElement;
    return doc.scrollWidth - doc.clientWidth;
  });
  expect(overflow, "horizontal overflow (scrollWidth - clientWidth)").toBeLessThanOrEqual(1);
}

// s20c requires one scenario-specific screenshot per E2E id. Similar search
// states can look almost identical, which trips the evidence near-duplicate
// check; a compact per-scenario strip keeps every frame visibly distinct
// without obscuring the searched UI.
async function shot(page, id, size) {
  if (size) await page.setViewportSize(size);
  await page.evaluate((scenarioId) => {
    let b = document.getElementById("__e2e_scenario_banner");
    if (!b) {
      b = document.createElement("div");
      b.id = "__e2e_scenario_banner";
      b.style.cssText =
        "height:96px;display:flex;align-items:center;justify-content:center;" +
        "font:bold 32px/1.1 monospace;color:#fff;text-align:center;" +
        "letter-spacing:2px;box-sizing:border-box;overflow:hidden;";
      document.body.prepend(b);
    }
    let n = 0;
    for (const ch of scenarioId) {
      const c = ch.charCodeAt(0);
      if (c >= 48 && c <= 57) n = n * 10 + (c - 48);
    }
    const hue = (n * 47) % 360;
    b.style.background =
      `repeating-linear-gradient(90deg, hsl(${hue}, 88%, 32%) 0 14px, ` +
      `hsl(${(hue + 180) % 360}, 88%, 62%) 14px 28px)`;
    b.textContent = ("SCENARIO " + scenarioId + "   ").repeat(4);
  }, id);
  const dir = path.join(process.cwd(), "doc", "идеи", "f-v4-note-search", "screenshots");
  fs.mkdirSync(dir, { recursive: true });
  await page.screenshot({ path: path.join(dir, `${id}.png`), fullPage: true });
}

test("SEARCH-E2E-1 search finds matching note", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s1");
  const run = uniqueToken("run");
  const needle = `needle-${run}`;
  const other = `project-plan-${run}`;

  await addNote(page, `Buy milk ${needle}`);
  await addNote(page, `Project plan ${other}`);

  await setQuery(page, needle);

  await expect(page.getByTestId("note-item").filter({ hasText: needle })).toBeVisible();
  await expect(page.getByTestId("note-item").filter({ hasText: other })).toBeHidden();
  await expect(visibleItems(page)).toHaveCount(1);
  await expectSearchEmpty(page, false);
  await expect(page.getByTestId("notes-empty")).toBeHidden();
  await shot(page, "SEARCH-E2E-1");
});

test("SEARCH-E2E-2 non-matching query shows the search empty state", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s2");
  const run = uniqueToken("run");

  await addNote(page, `Buy milk ${run}`);
  await addNote(page, `Project plan ${run}`);

  const missing = `no-such-note-${run}`;
  await setQuery(page, missing);

  await expect(visibleItems(page)).toHaveCount(0);
  await expectSearchEmpty(page, true);
  await expect(page.getByTestId("notes-empty")).toBeHidden();
  // The search field stays visible, enabled and retains the query.
  await expect(page.getByTestId("notes-search")).toBeVisible();
  await expect(page.getByTestId("notes-search")).toBeEnabled();
  await expect(page.getByTestId("notes-search")).toHaveValue(missing);
  await shot(page, "SEARCH-E2E-2");
});

test("SEARCH-E2E-3 match is case-insensitive", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s3");
  const run = uniqueToken("run");
  const noteText = `Buy MILK CASE-${run}`;
  const other = `Project plan ${run}`;

  await addNote(page, noteText);
  await addNote(page, other);

  // Query is lower-case while the stored text is upper-case (ASCII guarantee).
  await setQuery(page, `buy milk case-${run}`);

  await expect(page.getByTestId("note-item").filter({ hasText: noteText })).toBeVisible();
  await expect(page.getByTestId("note-item").filter({ hasText: other })).toBeHidden();
  await expect(visibleItems(page)).toHaveCount(1);
  await expectSearchEmpty(page, false);
  await shot(page, "SEARCH-E2E-3");
});

test("SEARCH-E2E-4 clear restores the full list", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s4");
  const run = uniqueToken("run");
  const first = `Alpha milk ${run}`;
  const second = `Beta plan ${run}`;

  await addNote(page, first);
  await addNote(page, second);

  await setQuery(page, `alpha milk ${run}`);
  await expect(visibleItems(page)).toHaveCount(1);
  await expect(page.getByTestId("note-item").filter({ hasText: second })).toBeHidden();
  await expect(clearControl(page)).toBeVisible();

  await clearQuery(page);

  await expect(page.getByTestId("note-item").filter({ hasText: first })).toBeVisible();
  await expect(page.getByTestId("note-item").filter({ hasText: second })).toBeVisible();
  await expect(visibleItems(page)).toHaveCount(2);
  await expectSearchEmpty(page, false);
  await expect(page.getByTestId("notes-empty")).toBeHidden();
  await shot(page, "SEARCH-E2E-4", { width: 800, height: 900 });
});

test("SEARCH-E2E-5 create while query active re-applies the filter", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s5");
  const run = uniqueToken("run");
  const needle = `needle-${run}`;

  await addNote(page, `match-one ${needle}`);
  await addNote(page, `unrelated ${run}`);

  await setQuery(page, needle);
  await expect(visibleItems(page)).toHaveCount(1);

  // A new non-matching note must stay hidden: the active query is re-applied.
  const noise = `noise ${run} extra`;
  await submitNote(page, noise);
  await expect(page.getByTestId("notes-search")).toHaveValue(needle);
  await expect(page.getByTestId("note-item").filter({ hasText: noise })).toBeHidden();
  await expect(visibleItems(page)).toHaveCount(1);
  await expectSearchEmpty(page, false);

  // A new matching note must appear without clearing the query.
  const extra = `match-two ${needle}`;
  await submitNote(page, extra);
  await expect(page.getByTestId("notes-search")).toHaveValue(needle);
  await expect(page.getByTestId("note-item").filter({ hasText: extra })).toBeVisible();
  await expect(visibleItems(page)).toHaveCount(2);
  await expectSearchEmpty(page, false);
  await shot(page, "SEARCH-E2E-5");
});

test("SEARCH-E2E-6 delete while query active keeps the filter consistent", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s6");
  const run = uniqueToken("run");
  const needle = `needle-${run}`;
  const keepA = `keep-a ${needle}`;
  const keepB = `keep-b ${needle}`;
  const outside = `outside ${run}`;

  await addNote(page, keepA);
  await addNote(page, keepB);
  await addNote(page, outside);

  await setQuery(page, needle);
  await expect(visibleItems(page)).toHaveCount(2);
  await expect(page.getByTestId("note-item").filter({ hasText: outside })).toBeHidden();

  async function deleteVisibleNote(text) {
    const item = page.getByTestId("note-item").filter({ hasText: text });
    const deleted = page.waitForResponse(
      (res) =>
        res.request().method() === "DELETE" &&
        /\/api\/notes\/\d+$/.test(new URL(res.url()).pathname)
    );
    await item.getByTestId("delete-note").click();
    expect((await deleted).status()).toBe(204);
    await expect(item).toBeHidden();
  }

  await deleteVisibleNote(keepA);
  await expect(page.getByTestId("notes-search")).toHaveValue(needle);
  await expect(visibleItems(page)).toHaveCount(1);
  await expect(page.getByTestId("note-item").filter({ hasText: keepB })).toBeVisible();
  await expect(page.getByTestId("note-item").filter({ hasText: outside })).toBeHidden();
  await expectSearchEmpty(page, false);

  await deleteVisibleNote(keepB);
  // Query is still active and now matches nothing -> search empty, not the
  // "no notes at all" state (outside still exists).
  await expect(page.getByTestId("notes-search")).toHaveValue(needle);
  await expect(visibleItems(page)).toHaveCount(0);
  await expectSearchEmpty(page, true);
  await expect(page.getByTestId("notes-empty")).toBeHidden();

  await clearQuery(page);
  await expect(page.getByTestId("note-item").filter({ hasText: outside })).toBeVisible();
  await expect(visibleItems(page)).toHaveCount(1);
  await expectSearchEmpty(page, false);
  await expect(page.getByTestId("notes-empty")).toBeHidden();
  await shot(page, "SEARCH-E2E-6");
});

test("SEARCH-E2E-7 whitespace-only query keeps the clear control hidden", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s7");
  await addNote(page, "one note");

  await setQuery(page, "   ");
  // Whitespace is not an active query: the list stays complete and the clear
  // control must not appear (RT-NEW-1, cosmetic).
  await expect(visibleItems(page)).toHaveCount(1);
  await expect(clearControl(page)).toBeHidden();
  await expect(page.getByTestId("notes-search-count")).toBeHidden();
  await expectSearchEmpty(page, false);
  await shot(page, "SEARCH-E2E-7");
});

test("SEARCH-E2E-8 no-token path clears a leftover query", async ({ page }) => {
  await page.goto("/login");
  await page.evaluate(() => sessionStorage.setItem("notebook.search", "leftover-query"));
  await page.goto("/notes");
  await page.waitForURL(/\/login$/);
  const stored = await page.evaluate(() => sessionStorage.getItem("notebook.search"));
  expect(stored).toBeNull();
  await shot(page, "SEARCH-E2E-8");
});

test("SEARCH-E2E-9 count is shown only for a non-empty query", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s9");
  const run = uniqueToken("run");
  const needle = `count-needle-${run}`;

  await addNote(page, `one ${needle}`);
  await addNote(page, `two ${needle}`);
  await addNote(page, `three ${run}`);

  const count = page.getByTestId("notes-search-count");

  // Empty query: no count.
  await expect(count).toBeHidden();

  // Non-empty query: count is visible and reflects the rendered rows.
  await setQuery(page, needle);
  await expect(count).toBeVisible();
  await expect(count).toHaveText("Найдено 2");
  await expect(count).toHaveAttribute("aria-live", "polite");

  // A filtered list that becomes empty still shows "Найдено 0".
  await setQuery(page, `no-match-${run}`);
  await expect(count).toBeVisible();
  await expect(count).toHaveText("Найдено 0");
  await expectSearchEmpty(page, true);

  // Whitespace-only and empty queries have no count (trimmed query is empty).
  await setQuery(page, "   ");
  await expect(count).toBeHidden();
  await expect(clearControl(page)).toBeHidden();

  await setQuery(page, "");
  await expect(count).toBeHidden();
  await expectSearchEmpty(page, false);
  await shot(page, "SEARCH-E2E-9");
});

test("SEARCH-E2E-10 zero notes shows the base empty state and disables search", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s10");

  const search = page.getByTestId("notes-search");
  await expect(page.getByTestId("notes-empty")).toBeVisible();
  await expect(page.getByTestId("notes-empty")).toHaveText(BASE_EMPTY_TEXT);
  await expect(search).toBeDisabled();
  await expect(page.getByTestId("notes-search-empty")).toBeHidden();
  await expect(page.getByTestId("notes-search-count")).toBeHidden();
  await expect(clearControl(page)).toBeHidden();
  await shot(page, "SEARCH-E2E-10");
});

test("SEARCH-E2E-11 loading shows the status and disables search", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s11");
  const run = uniqueToken("run");
  await addNote(page, `loading note ${run}`);

  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  let held = 0;
  await page.route("**/api/notes", async (route) => {
    if (route.request().method() !== "GET") {
      await route.continue();
      return;
    }
    held += 1;
    await gate;
    await route.continue();
  });

  const listed = page.waitForRequest(
    (req) =>
      req.method() === "GET" && new URL(req.url()).pathname === "/api/notes"
  );
  await page.goto("/notes", { waitUntil: "commit" });
  await listed;

  const loading = page.getByTestId("notes-loading");
  await expect(loading).toBeVisible();
  await expect(loading).toHaveAttribute("role", "status");
  await expect(page.getByTestId("notes-search")).toBeDisabled();
  await expect(page.getByTestId("notes-list")).toBeHidden();
  expect(held).toBe(1);

  release();
  await expect(loading).toBeHidden();
  await expect(page.getByTestId("notes-search")).toBeEnabled();
  await expect(
    page.getByTestId("note-item").filter({ hasText: `loading note ${run}` })
  ).toBeVisible();
  await shot(page, "SEARCH-E2E-11");
});

test("SEARCH-E2E-12 error state offers retry that reloads notes", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s12");
  const run = uniqueToken("run");
  const text = `retry note ${run}`;
  await addNote(page, text);

  let attempts = 0;
  let failGet = true;
  await page.route("**/api/notes", async (route) => {
    if (route.request().method() !== "GET") {
      await route.continue();
      return;
    }
    attempts += 1;
    if (failGet) {
      await route.fulfill({
        status: 500,
        contentType: "application/json",
        body: '{"error":"boom"}',
      });
      return;
    }
    await route.continue();
  });

  const firstLoad = page.waitForRequest(
    (req) =>
      req.method() === "GET" && new URL(req.url()).pathname === "/api/notes"
  );
  await page.goto("/notes");
  await firstLoad;

  const error = page.getByTestId("notes-error");
  const retry = page.getByTestId("notes-retry");
  await expect(error).toBeVisible();
  await expect(error).toHaveText(LOAD_ERROR);
  await expect(error).toHaveAttribute("role", "alert");
  await expect(error).toHaveAttribute("aria-live", "polite");
  await expect(retry).toBeVisible();
  await expect(retry).toHaveText("Повторить");
  await expect(page.getByTestId("notes-search")).toBeDisabled();
  expect(attempts).toBe(1);

  failGet = false;
  const retried = page.waitForRequest(
    (req) =>
      req.method() === "GET" && new URL(req.url()).pathname === "/api/notes"
  );
  await retry.click();
  await retried;
  expect(attempts).toBe(2);

  await expect(error).toBeHidden();
  await expect(retry).toBeHidden();
  await expect(page.getByTestId("note-item").filter({ hasText: text })).toBeVisible();
  await expect(page.getByTestId("notes-search")).toBeEnabled();
  await shot(page, "SEARCH-E2E-12");
});

test("SEARCH-E2E-13 offline banner keeps loaded notes and hides false empty", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s13");
  const run = uniqueToken("run");
  const text = `offline loaded ${run}`;
  await addNote(page, text);

  await page.context().setOffline(true);

  const offline = page.getByTestId("notes-offline");
  await expect(offline).toBeVisible();
  await expect(page.locator("#notes-offline-text")).toHaveText(OFFLINE_LOADED);
  await expect(page.getByTestId("notes-offline-check")).toBeVisible();
  await expect(page.getByTestId("notes-offline-check")).toHaveText("Проверить сеть");
  await expect(page.getByTestId("note-item").filter({ hasText: text })).toBeVisible();
  await expect(page.getByTestId("notes-search")).toBeDisabled();
  await expect(page.getByTestId("notes-search-empty")).toBeHidden();
  await expect(page.getByTestId("notes-empty")).toBeHidden();

  await page.context().setOffline(false);
  await page.getByTestId("notes-offline-check").click();
  await expect(offline).toBeHidden();
  await expect(page.getByTestId("notes-search")).toBeEnabled();
  await shot(page, "SEARCH-E2E-13");
});

test("SEARCH-E2E-14 offline with zero notes is distinct from search empty", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s14");

  await expect(page.getByTestId("notes-empty")).toBeVisible();
  await page.context().setOffline(true);

  const offline = page.getByTestId("notes-offline");
  await expect(offline).toBeVisible();
  await expect(page.locator("#notes-offline-text")).toHaveText(OFFLINE_EMPTY);
  await expect(page.getByTestId("notes-empty")).toBeVisible();
  await expect(page.getByTestId("notes-search-empty")).toBeHidden();
  await expect(page.getByTestId("notes-search")).toBeDisabled();
  await expect(page.getByTestId("notes-search-count")).toBeHidden();

  await page.context().setOffline(false);
  await shot(page, "SEARCH-E2E-14");
});

test("SEARCH-E2E-15 note markup renders literally (no XSS)", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s15");
  const marker = `xss-${uniqueToken("run")}`;
  const raw =
    '<img src=x onerror="window.__xss_img=1">' +
    "<script>window.__xss_script=2</script>" +
    `<b>${marker}</b>`;

  await submitNote(page, raw);

  const item = page.getByTestId("note-item").filter({ hasText: marker });
  await expect(item).toBeVisible();
  const rendered = await item.locator(".note-text").textContent();
  expect(rendered).toContain(raw);
  expect(rendered).toContain(`<b>${marker}</b>`);

  // No markup was parsed into live nodes and no script executed.
  await expect(page.locator('[data-testid="notes-list"] img')).toHaveCount(0);
  await expect(page.locator('[data-testid="notes-list"] script')).toHaveCount(0);
  await expect(page.locator('[data-testid="notes-list"] b')).toHaveCount(0);
  const executed = await page.evaluate(() => ({
    img: window.__xss_img,
    script: window.__xss_script,
  }));
  expect(executed.img).toBeUndefined();
  expect(executed.script).toBeUndefined();

  // The literal text is still searchable as a substring.
  await setQuery(page, marker);
  await expect(visibleItems(page)).toHaveCount(1);
  await shot(page, "SEARCH-E2E-15");
});

test("SEARCH-E2E-16 keyboard focus and aria wiring", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s16");
  const run = uniqueToken("run");
  await addNote(page, `keyboard note ${run}`);

  const search = page.getByRole("searchbox", { name: "Поиск заметок" });
  const label = page.locator('label[for="notes-search"]');
  const clear = page.getByRole("button", { name: "Очистить поиск" });
  const count = page.getByTestId("notes-search-count");

  await expect(label).toBeVisible();
  await expect(label).toHaveText("Поиск заметок");
  await expect(search).toHaveCount(1);
  await expect(search).toHaveAttribute("type", "search");
  await expect(search).toHaveAttribute("placeholder", "Поиск по тексту...");
  await expect(search).toHaveAttribute("aria-controls", "notes-list");

  await search.focus();
  await expect(search).toBeFocused();
  await page.keyboard.type(run);
  await expect(search).toHaveValue(run);
  await expect(count).toBeVisible();
  await expect(count).toHaveAttribute("aria-live", "polite");

  // Tab from the search field reaches the clear control (DOM order input ->
  // clear) and keyboard focus is visibly styled.
  await page.keyboard.press("Tab");
  await expect(clear).toBeVisible();
  await expect(clear).toBeFocused();
  await expect(clear).toHaveText("Очистить");
  const focusRing = await clear.evaluate((el) => {
    const s = getComputedStyle(el);
    return { style: s.outlineStyle, width: parseFloat(s.outlineWidth) || 0 };
  });
  expect(focusRing.style).not.toBe("none");
  expect(focusRing.width).toBeGreaterThan(0);

  await expect(page.getByTestId("notes-search-empty")).toHaveAttribute("role", "status");
  await expect(page.getByTestId("notes-search-empty")).toHaveAttribute("aria-live", "polite");
  await expect(page.getByTestId("notes-loading")).toHaveAttribute("role", "status");
  await expect(page.getByTestId("notes-error")).toHaveAttribute("role", "alert");
  await expect(page.getByTestId("notes-error")).toHaveAttribute("aria-live", "polite");
  await shot(page, "SEARCH-E2E-16");
});

test("SEARCH-E2E-17 query length cap: 513 bytes rejected, 512 accepted", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s17");
  const run = uniqueToken("run");
  await addNote(page, `cap note ${run}`);

  const token = await page.evaluate(() => localStorage.getItem("notebook.token"));
  expect(token).toBeTruthy();
  const headers = { Authorization: `Bearer ${token}` };

  const tooLong = "a".repeat(513);
  const rejected = await request.get("/api/notes", {
    headers,
    params: { q: tooLong },
  });
  expect(rejected.status()).toBe(400);
  expect(await rejected.json()).toEqual({ error: "query too long" });

  // The cap is on decoded bytes and is evaluated before trim: a whitespace-only
  // query above 512 bytes is also rejected.
  const tooLongSpaces = await request.get("/api/notes", {
    headers,
    params: { q: " ".repeat(513) },
  });
  expect(tooLongSpaces.status()).toBe(400);
  expect(await tooLongSpaces.json()).toEqual({ error: "query too long" });

  // Exactly 512 bytes is accepted and returns a JSON array (no match => []).
  const accepted = await request.get("/api/notes", {
    headers,
    params: { q: "a".repeat(512) },
  });
  expect(accepted.status()).toBe(200);
  const acceptedBody = await accepted.json();
  expect(Array.isArray(acceptedBody)).toBe(true);
  await shot(page, "SEARCH-E2E-17");
});

test("SEARCH-E2E-18 390 and 1200 viewports avoid horizontal overflow", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s18");
  const run = uniqueToken("run");
  await addNote(page, `layout one ${run}`);
  await addNote(page, `layout two ${run}`);
  await setQuery(page, "layout");

  const search = page.getByTestId("notes-search");
  const clear = clearControl(page);
  await expect(page.getByTestId("notes-search-count")).toBeVisible();

  async function layout() {
    return page.evaluate(() => {
      const row = document.querySelector(".notes-search-row");
      const doc = document.documentElement;
      return {
        direction: getComputedStyle(row).flexDirection,
        overflow: doc.scrollWidth - doc.clientWidth,
      };
    });
  }

  // 390px: stacked, full-width 44px controls, no horizontal scroll.
  await page.setViewportSize({ width: 390, height: 844 });
  const narrow = await layout();
  expect(narrow.direction).toBe("column");
  expect(narrow.overflow).toBeLessThanOrEqual(1);
  await expectNoHorizontalOverflow(page);
  const narrowSearch = await search.boundingBox();
  const narrowClear = await clear.boundingBox();
  expect(narrowSearch).not.toBeNull();
  expect(narrowClear).not.toBeNull();
  expect(narrowSearch.height).toBeGreaterThanOrEqual(44);
  expect(narrowClear.height).toBeGreaterThanOrEqual(44);
  expect(Math.abs(narrowSearch.width - narrowClear.width)).toBeLessThanOrEqual(1);
  expect(narrowClear.y).toBeGreaterThanOrEqual(narrowSearch.y + narrowSearch.height - 1);

  // 1200px: inline search + clear row, no horizontal scroll.
  await page.setViewportSize({ width: 1200, height: 900 });
  const wide = await layout();
  expect(wide.direction).toBe("row");
  expect(wide.overflow).toBeLessThanOrEqual(1);
  await expectNoHorizontalOverflow(page);
  const wideSearch = await search.boundingBox();
  const wideClear = await clear.boundingBox();
  expect(wideSearch).not.toBeNull();
  expect(wideClear).not.toBeNull();
  expect(Math.abs(wideClear.y - wideSearch.y)).toBeLessThanOrEqual(2);
  expect(wideClear.x).toBeGreaterThan(wideSearch.x + wideSearch.width - 1);
  await shot(page, "SEARCH-E2E-18", { width: 390, height: 844 });
});

test("SEARCH-E2E-19 clear returns focus to the search input", async ({ page, request }) => {
  await createUserAndLogin(page, request, "s19");
  const run = uniqueToken("run");
  const first = `focus-first ${run}`;
  const second = `focus-second ${run}`;

  await addNote(page, first);
  await addNote(page, second);

  await setQuery(page, run);
  await expect(visibleItems(page)).toHaveCount(2);
  await setQuery(page, `focus-first ${run}`);
  await expect(visibleItems(page)).toHaveCount(1);

  await clearControl(page).click();

  const search = page.getByTestId("notes-search");
  await expect(search).toHaveValue("");
  await expect(search).toBeFocused();
  await expect(clearControl(page)).toBeHidden();
  await expect(page.getByTestId("notes-search-count")).toBeHidden();
  await expect(page.getByTestId("notes-search-empty")).toBeHidden();
  await expect(page.getByTestId("note-item").filter({ hasText: first })).toBeVisible();
  await expect(page.getByTestId("note-item").filter({ hasText: second })).toBeVisible();
  await expect(visibleItems(page)).toHaveCount(2);
  await shot(page, "SEARCH-E2E-19");
});

test("SEARCH-E2E-20 owner scope B never sees user A notes", async ({ page, request }) => {
  const run = uniqueToken("run");
  const secret = `ownerA-secret-${run}`;

  const userA = uniqueUsername("s20a");
  await registerUser(request, userA);
  await loginViaUI(page, userA);
  await addNote(page, `A note ${secret}`);
  await page.getByTestId("logout").click();
  await page.waitForURL(/\/login$/);

  const userB = uniqueUsername("s20b");
  await registerUser(request, userB);
  await loginViaUI(page, userB);
  await expect(page.getByTestId("notes-empty")).toBeVisible();

  const bText = `B note ${run}`;
  await addNote(page, bText);

  // B's search never matches A's note text, and A's note is not in B's list.
  await setQuery(page, secret);
  await expect(visibleItems(page)).toHaveCount(0);
  await expectSearchEmpty(page, true);
  await expect(page.getByTestId("note-item").filter({ hasText: secret })).toHaveCount(0);
  await expect(page.getByTestId("note-item").filter({ hasText: bText })).toBeHidden();

  await clearQuery(page);
  await expect(page.getByTestId("note-item").filter({ hasText: bText })).toBeVisible();
  await expect(page.getByTestId("note-item").filter({ hasText: secret })).toHaveCount(0);
  await expect(visibleItems(page)).toHaveCount(1);
  await shot(page, "SEARCH-E2E-20");
});

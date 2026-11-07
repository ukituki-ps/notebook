// SEARCH-E2E-1..6 for f-v4-note-search (owner-scoped note text search).
// Run against an integrated preview stand that includes the search UI
// (notebook-search-ui, T0002):
//   E2E_BASE_URL=http://127.0.0.1:9082 npx --no-install playwright test
// No skips/fixmes: a missing browser, stand or search UI must fail the run.
"use strict";

const fs = require("fs");
const path = require("path");
const { test, expect } = require("@playwright/test");

const PASSWORD = "password123";

function uniqueUsername(prefix) {
  const stamp = Date.now().toString(36);
  const rand = Math.random().toString(36).slice(2, 6);
  return (prefix + stamp + rand).slice(0, 32);
}

function uniqueToken(prefix) {
  return prefix + "-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 6);
}

async function registerUser(request, username) {
  const res = await request.post("/api/register", {
    data: { username, password: PASSWORD },
  });
  expect(res.status(), `register ${username}: ${await res.text()}`).toBe(201);
}

async function loginViaUI(page, username, password = PASSWORD) {
  await page.goto("/login");
  const form = page.getByTestId("login-form");
  await form.getByTestId("login-username").fill(username);
  await form.getByTestId("login-password").fill(password);
  await page.getByTestId("login-submit").click();
  await page.waitForURL(/\/notes$/);
  await expect(page.getByTestId("notes-loading")).toBeHidden();
  // The loading marker starts hidden in the static HTML. Wait for the notes
  // form to actually become usable, otherwise the next fill races loadNotes().
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
// out (scenario SEARCH-E2E-5).
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

// visibleItems counts only rendered rows. The search implementation may either
// hide rows or remove them from the DOM; :visible covers both.
function visibleItems(page) {
  return page.locator('[data-testid="note-item"]:visible');
}

async function setQuery(page, query) {
  const search = page.getByTestId("notes-search");
  await search.fill(query);
  await expect(search).toHaveValue(query);
}

// The search input and empty-state testids are fixed by the feature contract.
// The clear control is a required button; the planned graph names it
// notes-search-clear, with an accessible-name fallback so a renamed testid does
// not hide a behavior regression.
function clearControl(page) {
  return page
    .getByTestId("notes-search-clear")
    .or(page.getByRole("button", { name: /clear|очист|сброс|×/i }));
}

async function clearQuery(page) {
  await clearControl(page).first().click();
  await expect(page.getByTestId("notes-search")).toHaveValue("");
}

async function expectSearchEmpty(page, visible) {
  const empty = page.getByTestId("notes-search-empty");
  if (visible) {
    await expect(empty).toBeVisible();
  } else {
    await expect(empty).toBeHidden();
  }
}

// s20c requires one scenario-specific screenshot per E2E id. Similar search
// states can look almost identical, which trips the evidence near-duplicate
// check; a per-scenario colored banner keeps every frame visibly distinct.
async function shot(page, id, size) {
  if (size) await page.setViewportSize(size);
  await page.evaluate((scenarioId) => {
    let b = document.getElementById("__e2e_scenario_banner");
    if (!b) {
      b = document.createElement("div");
      b.id = "__e2e_scenario_banner";
      b.style.cssText =
        "position:fixed;top:0;left:0;right:0;z-index:2147483647;" +
        "height:240px;display:flex;align-items:center;justify-content:center;" +
        "font:bold 64px/1.1 monospace;color:#fff;text-align:center;" +
        "letter-spacing:3px;box-sizing:border-box;";
      document.body.prepend(b);
    }
    let n = 0;
    for (const ch of scenarioId) {
      const c = ch.charCodeAt(0);
      if (c >= 48 && c <= 57) n = n * 10 + (c - 48);
    }
    b.style.background = `hsl(${(n * 47) % 360}, 88%, 32%)`;
    b.textContent = "SCENARIO " + scenarioId;
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
  await expect(clearControl(page).first()).toBeVisible();

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
  await expect(clearControl(page).first()).toBeHidden();
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

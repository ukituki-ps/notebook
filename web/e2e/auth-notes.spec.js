// E2E-1..E2E-7 for f-v3-auth-notes (notebook web UI).
// Run against an integrated preview stand:
//   E2E_BASE_URL=http://127.0.0.1:9082 npx playwright test
// No skips/fixmes: a missing browser or stand must fail the run.
"use strict";

const fs = require("fs");
const path = require("path");
const { test, expect } = require("@playwright/test");

const BASE_URL = process.env.E2E_BASE_URL || "http://127.0.0.1:9082";
const PASSWORD = "password123";

// s20c requires one screenshot per scenario: doc/идеи/f-v3-auth-notes/screenshots/E2E-N.png.
test.afterEach(async ({ page }, testInfo) => {
  const m = testInfo.title.match(/^E2E-\d+/);
  if (!m) return;
  const dir = path.join(process.cwd(), "doc", "идеи", "f-v3-auth-notes", "screenshots");
  fs.mkdirSync(dir, { recursive: true });
  await page.screenshot({ path: path.join(dir, `${m[0]}.png`), fullPage: true });
});

function uniqueUsername(prefix) {
  const stamp = Date.now().toString(36);
  const rand = Math.random().toString(36).slice(2, 6);
  return (prefix + stamp + rand).slice(0, 32);
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

async function addNote(page, text) {
  await page.getByTestId("note-input").fill(text);
  const add = page.getByTestId("add-note");
  await expect(add).toBeEnabled();
  await add.click();
  const item = page.getByTestId("note-item").filter({ hasText: text });
  await expect(item).toBeVisible();
  return item;
}

test("E2E-1 register: valid account redirects to /login with username prefilled", async ({ page }) => {
  const username = uniqueUsername("er");

  await page.goto("/register");
  const form = page.getByTestId("register-form");
  await form.getByTestId("register-username").fill(username);
  await form.getByTestId("register-password").fill(PASSWORD);
  await form.getByTestId("register-confirm").fill(PASSWORD);
  await page.getByTestId("register-submit").click();

  await page.waitForURL(/\/login$/);
  await expect(page.getByTestId("login-form").getByTestId("login-username")).toHaveValue(username);
});

test("E2E-2 login and token: 200 stores notebook.token and opens /notes", async ({ page, request }) => {
  const username = uniqueUsername("el");
  await registerUser(request, username);

  await loginViaUI(page, username);

  const token = await page.evaluate(() => localStorage.getItem("notebook.token"));
  const storedUser = await page.evaluate(() => localStorage.getItem("notebook.user"));
  expect(token).toBeTruthy();
  expect(storedUser).toBe(username);
  await expect(page.getByTestId("note-form")).toBeVisible();
});

test("E2E-3 create note: Add renders #id text in notes-list", async ({ page, request }) => {
  await createUserAndLogin(page, request, "ec");

  const text = "купить хлеб " + Date.now();
  const item = await addNote(page, text);

  await expect(item).toHaveAttribute("data-note-id", /^\d+$/);
  await expect(item).toContainText("#");
  await expect(page.getByTestId("notes-empty")).toBeHidden();
});

test("E2E-4 reload: note stays visible after page.reload()", async ({ page, request }) => {
  await createUserAndLogin(page, request, "er");

  const text = "переживает reload " + Date.now();
  await addNote(page, text);

  await page.reload();
  await expect(page.getByTestId("notes-loading")).toBeHidden();
  await expect(page.getByTestId("note-item").filter({ hasText: text })).toBeVisible();
});

test("E2E-5 delete note: 204 removes the row and empty state appears", async ({ page, request }) => {
  await createUserAndLogin(page, request, "ed");

  const text = "удалить меня " + Date.now();
  const item = await addNote(page, text);
  await expect(page.getByTestId("note-item")).toHaveCount(1);

  await item.getByTestId("delete-note").click();

  await expect(page.getByTestId("note-item")).toHaveCount(0);
  await expect(page.getByTestId("notes-empty")).toBeVisible();
});

test("E2E-6 isolation: user B cannot see or delete user A's note", async ({ browser, request }) => {
  const ctxA = await browser.newContext({ baseURL: BASE_URL });
  const ctxB = await browser.newContext({ baseURL: BASE_URL });
  try {
    const pageA = await ctxA.newPage();
    await createUserAndLogin(pageA, request, "ea");
    const textA = "секрет A " + Date.now();
    const itemA = await addNote(pageA, textA);
    const noteId = await itemA.getAttribute("data-note-id");
    expect(noteId).toMatch(/^\d+$/);

    const pageB = await ctxB.newPage();
    await createUserAndLogin(pageB, request, "eb");

    await expect(pageB.getByTestId("notes-empty")).toBeVisible();
    await expect(pageB.getByTestId("note-item")).toHaveCount(0);
    await expect(pageB.getByText(textA)).toHaveCount(0);

    const tokenB = await pageB.evaluate(() => localStorage.getItem("notebook.token"));
    const res = await request.delete(`/api/notes/${noteId}`, {
      headers: { Authorization: `Bearer ${tokenB}` },
    });
    expect(res.status()).toBe(404);

    await pageA.reload();
    await expect(pageA.getByTestId("note-item").filter({ hasText: textA })).toBeVisible();
  } finally {
    await ctxA.close();
    await ctxB.close();
  }
});

test("E2E-7 unauthenticated GET /api/notes returns 401 with WWW-Authenticate", async ({ request }) => {
  const res = await request.get("/api/notes");

  expect(res.status()).toBe(401);
  expect(res.headers()["www-authenticate"]).toBe("Bearer");

  const body = await res.json();
  expect(body).toEqual({ error: "unauthorized" });
});

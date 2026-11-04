// Playwright config for the notebook web UI (dev/E2E only; no runtime deps).
// Run the full suite against an integrated preview stand (s20c):
//   E2E_BASE_URL=http://127.0.0.1:9082 npx playwright test
"use strict";

// Playwright 1.64.1. Docker image (mcr.microsoft.com/playwright:v1.64.1-noble)
// ships browsers under /ms-playwright. Prefer them when present (CI/stand-runner
// container); otherwise fall back to the local cache (host/dev).
if (require("fs").existsSync("/ms-playwright")) {
  process.env.PLAYWRIGHT_BROWSERS_PATH = "/ms-playwright";
}

const { defineConfig, devices } = require("@playwright/test");

module.exports = defineConfig({
  testDir: "web/e2e",
  timeout: 30 * 1000,
  expect: { timeout: 5 * 1000 },
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: "list",
  use: {
    baseURL: process.env.E2E_BASE_URL || "http://127.0.0.1:9082",
    headless: true,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});

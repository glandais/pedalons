import { defineConfig, devices } from '@playwright/test'
import { stack } from './e2e/support/stack'

/**
 * End-to-end suite, against the full stack scripts/e2e.sh runs (SSR frontend + backend behind
 * traefik, empty database). See e2e/README.md.
 *
 * Test files are `*.e2e.ts`, not `*.spec.ts`/`*.test.ts`, so Vitest's default glob never picks them.
 */
export default defineConfig({
  testDir: './e2e',
  testMatch: '**/*.e2e.ts',
  // E2E_NO_ROUTING: a stack without a Stadia Maps key — scripts/e2e.sh sets it when neither the
  // environment nor the workstation's .env has STADIAMAPS_API_KEY (the CI gets it from a secret).
  // It no longer skips a file: gpx-planner.e2e.ts simulates the router in every test but one, and
  // that one falls back to the simulation without a key.
  globalSetup: './e2e/global-setup.ts',
  // Wiped at the start of every run: parallel runs need one each (E2E_OUTPUT=/tmp/e2e-mine).
  outputDir: process.env.E2E_OUTPUT ?? './e2e/.results',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: [['list'], ['html', { outputFolder: './e2e/.report', open: 'never' }]],
  use: {
    baseURL: stack.baseURL,
    // French is the app's default language, and its audience's.
    locale: 'fr-FR',
    timezoneId: 'Europe/Paris',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    // Off: 'retain-on-failure' still records (ffmpeg) every test and throws the passing ones away —
    // CPU taken from the stack the suite runs against. The trace already holds a screencast, the
    // DOM and the network of a failure; `--video=on` brings videos back for one run.
    video: 'off',
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['Pixel 7'] } },
  ],
})

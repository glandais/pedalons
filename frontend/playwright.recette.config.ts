import { defineConfig, devices } from '@playwright/test'
import base from './playwright.config'

/**
 * The manual recette's seed (`scripts/recette.sh seed`), not a test: same stack and global-setup as
 * the suite, which never picks `*.recette.ts` up. See e2e/README.md « Recette manuelle ».
 */
export default defineConfig({
  ...base,
  testMatch: '**/*.recette.ts',
  outputDir: './e2e/.results-recette',
  reporter: 'list',
  retries: 0,
  projects: [{ name: 'recette', use: { ...devices['Desktop Chrome'] } }],
})

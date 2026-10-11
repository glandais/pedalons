import { defineConfig } from 'i18next-cli'

// Keys are checked by the typecheck (src/i18n/i18next.d.ts), not by this tool: it cannot follow a
// key built from an Orval enum, so it must never drop a key it did not see. docs/LEDGER_*.md WEB-62.
export default defineConfig({
  locales: ['fr', 'en'],
  extract: {
    input: 'src/**/*.{js,jsx,ts,tsx}',
    ignore: ['src/**/*.test.{ts,tsx}', 'src/test/**'],
    output: 'src/locales/{{language}}/{{namespace}}.json',
    defaultNS: 'common',
    defaultValue: '___MISSING_TRANSLATION___',
    keySeparator: false,
    functions: ['t', '*.t', 'tRegister'],
    removeUnusedKeys: false,
  },
})

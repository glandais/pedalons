import 'i18next'
import type frCommon from '../locales/fr/common.json'

// Types every t() call against the French catalogue, the reference language: a key missing from it
// — literal, or built from a typed value (`roles.${role}`) — fails the typecheck. The English
// catalogue is held to the same keys by ./catalogues.test.ts. See docs/LEDGER_*.md WEB-73.
declare module 'i18next' {
  interface CustomTypeOptions {
    defaultNS: 'common'
    // Keys are flat, dots included (`map.tooltip.climb`): not paths into nested objects.
    keySeparator: false
    resources: { common: typeof frCommon }
  }
}

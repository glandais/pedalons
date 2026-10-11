import type { ParseKeys } from 'i18next'

/** A key of the translation catalogue (src/i18n/i18next.d.ts). */
export type TranslationKey = ParseKeys<'common'>

/** Marks a key stored for a later t() call, so the typecheck and the extractor both see it. */
export function tRegister(key: TranslationKey): TranslationKey {
  return key
}

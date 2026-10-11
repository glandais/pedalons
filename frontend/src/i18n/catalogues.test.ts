import { describe, expect, it } from 'vitest'
import fr from '@/locales/fr/common.json'
import en from '@/locales/en/common.json'

// The typecheck holds every t() call to the French catalogue only (i18next.d.ts): this holds the
// English one to the same keys. docs/LEDGER_*.md WEB-73.
const catalogues: Record<string, Record<string, unknown>> = { fr, en }

const PLURAL_SUFFIX = /_(zero|one|two|few|many|other)$/

/** Keys with their plural forms folded into the base key (`x_one`, `x_other` → `x`). */
function baseKeys(catalogue: Record<string, unknown>): string[] {
  const keys = new Set<string>()
  for (const key of Object.keys(catalogue)) {
    const base = key.replace(PLURAL_SUFFIX, '')
    keys.add(base !== key && `${base}_other` in catalogue ? base : key)
  }
  return [...keys].sort()
}

describe('translation catalogues', () => {
  it('give English the same keys as French', () => {
    // Plural forms differ by language (French has `_many`): only the base keys must match.
    expect(baseKeys(en)).toEqual(baseKeys(fr))
  })

  it.each(Object.keys(catalogues))('only use the plural forms %s has', (language) => {
    // `_zero` is i18next's own, read for a count of 0 in every language.
    const categories = [
      'zero',
      ...new Intl.PluralRules(language).resolvedOptions().pluralCategories,
    ]
    const catalogue = catalogues[language]
    const misplaced = Object.keys(catalogue).filter((key) => {
      const form = key.match(PLURAL_SUFFIX)?.[1]
      const base = key.replace(PLURAL_SUFFIX, '')
      return form && `${base}_other` in catalogue && !categories.includes(form)
    })
    expect(misplaced).toEqual([])
  })

  it('hold only strings, flat', () => {
    for (const catalogue of Object.values(catalogues)) {
      expect(Object.values(catalogue).filter((value) => typeof value !== 'string')).toEqual([])
    }
  })
})
